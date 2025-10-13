#!/bin/bash
set -euo pipefail

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Take the godotVersion and godotRelease from the command line, show usage if not provided
if [ $# -eq 2 ]; then
  godotVersion="$1"
  godotRelease="$2" # e.g. "stable" or "rc1"
else
  echo "Usage: $0 <godotVersion> <godotRelease>"
  exit 1
fi

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

overlayDir="$scriptDir/overlay/$godotVersion-$godotRelease"
[ -d "$overlayDir" ] || { echo "Overlay directory not found"; exit 1; }

echo "==> Applying overlay directory $overlayDir ..."
rsync -a --info=stats,name1 "$overlayDir/" "$godotRoot/"

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

# Build a list of text/code files to touch (skip build outputs and VCS stuff)
echo "==> Indexing files to rewrite..."
mapfile -d '' files < <(
  find . -type f \
    \( -name "*.kt" -o -name "*.java" -o -name "*.xml" -o -name "*.gradle" -o -name "*.pro" \
       -o -name "*.txt" -o -name "*.md" -o -name "*.properties" -o -name "*.cpp" -o -name "*.c" -o -name "*.h" \
       -o -name "AndroidManifest.xml" \) \
    -not -path "*/build/*" -not -path "*/.git/*" -not -path "*/.gradle/*" -not -path "*/bin/*" -not -path "*/out/*" \
    -print0
)

# 1) Dot-form Java package rename (idempotent; don’t re-rewrite)
echo "==> Rewriting dot-form package names..."
printf '%s\0' "${files[@]}" | xargs -0 perl -0777 -pi -e '
  s/\borg\.godotengine\.godot\b(?!'"${pkgSuffix//_/\\_}"')/org.godotengine.godot'"$pkgSuffix"'/g
'

# 2) Slash-form path rename (idempotent)
echo "==> Rewriting slash-form package paths..."
printf '%s\0' "${files[@]}" | xargs -0 perl -0777 -pi -e '
  s@org/godotengine/godot(?!'"${pkgSuffix//_/\\_}"')@org/godotengine/godot'"$pkgSuffix"'@g
'

# 3) JNI symbol prefix rename with correct mangling (_ -> _1)
#    Restrict to native sources/headers under platform/android
echo "==> Rewriting JNI symbols with correct mangling..."
mapfile -d '' native_files < <(
  find platform/android -type f \( -name "*.c" -o -name "*.cpp" -o -name "*.h" \) -print0
)
if ((${#native_files[@]})); then
  printf '%s\0' "${native_files[@]}" | xargs -0 perl -0777 -pi -e '
    s/Java_org_godotengine_godot_(?!'"$jniSuffix"'_)/Java_org_godotengine_godot'"$jniSuffix"'_/g
  '
fi

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

echo "==> AAR ready for Maven publishing:"
echo "    File: $godotRoot/bin/godot-lib.template_release.aar"
echo "    To publish: ./gradlew publish"
