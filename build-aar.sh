#!/bin/bash
set -euo pipefail

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

godotVersion="4.4.1"
godotRelease="stable"
pkgSuffix="v${godotVersion//./_}"      # v4_4_1
jniSuffix="${pkgSuffix//_/_1}"         # v4_14_11   (JNI: "_" -> "_1")

rm -rf "$scriptDir/godot-$godotVersion"

echo "Cloning Godot $godotVersion-$godotRelease..."

cd "$scriptDir"
git clone https://github.com/godotengine/godot.git --depth 1 -b "$godotVersion-$godotRelease" "godot-$godotVersion"

godotRoot="$scriptDir/godot-$godotVersion"

echo "Downloading swappy-frame-pacing..."
releaseJson="$(curl -fsSL "https://api.github.com/repos/godotengine/godot-swappy/releases/tags/from-source-2025-01-31")"
assetId="$(jq -r '.assets[] | select(.name=="godot-swappy.7z").id' <<<"$releaseJson")"
[ -n "$assetId" ] || { echo "Asset not found"; exit 1; }

curl -fSL -H "Accept: application/octet-stream" \
  -o godot-swappy.7z \
  "https://api.github.com/repos/godotengine/godot-swappy/releases/assets/$assetId"

7za x -y godot-swappy.7z -o"$godotRoot/thirdparty/swappy-frame-pacing"
rm godot-swappy.7z

echo "==> Applying overlay..."
rsync -a --info=stats,name1 "$scriptDir/overlay/" "$godotRoot/"


echo "Renaming Java package to include suffix: $pkgSuffix"

javaLib="$godotRoot/platform/android/java/lib/src/org/godotengine"
oldPkgDir="$javaLib/godot"
newPkgDir="$javaLib/godot${pkgSuffix}"

echo "==> Moving Java package folder:"
echo "    $oldPkgDir  ->  $newPkgDir"
if [[ -d "$oldPkgDir" ]]; then
  mv "$oldPkgDir" "$newPkgDir"
fi

cd "$godotRoot"



# --- dot-form Java package rename ---
echo "==> Renaming Java package in source files..."
comby -in-place \
  'org.godotengine.godot' \
  "org.godotengine.godot$pkgSuffix" \
  . \
  -extensions kt,java,xml,gradle,pro,txt,md,properties,cpp,c,h

# --- slash-form package path rename ---
echo "==> Renaming package path in source files..."
comby -in-place \
  'org/godotengine/godot' \
  "org/godotengine/godot$pkgSuffix" \
  . \
  -extensions kt,java,xml,gradle,pro,txt,md,properties,cpp,c,h

# --- JNI symbol prefix rename (only native code) ---
echo "==> Renaming JNI symbols in native code..."
comby -in-place \
  'Java_org_godotengine_godot_' \
  "Java_org_godotengine_godot${jniSuffix}_" \
  platform/android \
  -extensions c,cpp,h


# Clean & build
echo "==> scons clean + build (android, template_release, arm64)..."
scons -c
scons platform=android target=template_release arch=arm64

echo "==> Gradle: generateGodotTemplates..."
cd "$godotRoot/platform/android/java/"
./gradlew --no-daemon generateGodotTemplates

echo "==> Done. Built files in:"
cd "$godotRoot/bin"
pwd
ls -l
