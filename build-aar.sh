#!/bin/bash
set -euo pipefail

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

downloadOnly=false

# --- Parse flags first ---
args=()
for arg in "$@"; do
  case "$arg" in
    --downloadOnly)
      downloadOnly=true
      ;;
    *)
      args+=("$arg")
      ;;
  esac
done

set -- "${args[@]}"

# --- Parse positional arguments ---
# Usage: ./build-aar.sh <version> [release] [--downloadOnly]
if [ $# -eq 2 ]; then
  godotVersion="$1"
  godotRelease="$2"
  refName="${godotVersion}-${godotRelease}"   # e.g. 4.5-stable or 4.4-rc1
elif [ $# -eq 1 ]; then
  godotVersion="$1"
  godotRelease=""
  refName="$godotVersion"                     # e.g. 3.x or master
else
  echo "Usage: $0 <godotVersion> [godotRelease] [--downloadOnly]"
  exit 1
fi

pkgSuffix="v${godotVersion//./_}"      # v4_4_1 or v3_x
jniSuffix="${pkgSuffix//_/_1}"         # v4_14_11   (JNI: "_" -> "_1")

rm -rf "$scriptDir/godot-$godotVersion"

echo "Cloning Godot from ref '$refName'..."

cd "$scriptDir"
git clone https://github.com/godotengine/godot.git --depth 1 -b "$refName" "godot-$godotVersion"

if [ "$downloadOnly" = true ]; then
  echo "Clone completed successfully. Exiting (--downloadOnly set)."
  exit 0
fi

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

if [ -n "${godotRelease:-}" ]; then
  overlayDir="$scriptDir/overlay/${godotVersion}-${godotRelease}"
else
  overlayDir="$scriptDir/overlay/${godotVersion}"
fi
[ -d "$overlayDir" ] || { echo "Overlay directory not found"; exit 1; }

echo "==> Applying overlay directory $overlayDir ..."
rsync -a --info=stats,name1 "$overlayDir/" "$godotRoot/"

# Remove all aidl files
echo "==> Removing all .aidl files..."
find "$godotRoot/platform/android/java/" -type f -name "*.aidl" -exec rm -f {} +

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
export VERSION_SUFFIX="${pkgSuffix}"

if [[ "$godotVersion" == 3.* ]]; then
  scons platform=android target=release android_arch=armv7
  scons platform=android target=release android_arch=arm64v8
else
  scons platform=android target=template_release arch=arm32
  scons platform=android target=template_release arch=arm64 generate_android_binaries=yes
fi

echo "==> Gradle: generateGodotTemplates..."
cd "$godotRoot/platform/android/java/"
./gradlew --no-daemon generateGodotTemplates

if [[ "$godotVersion" == 3.* ]]; then
  echo "==> Renaming AAR for Godot 3.x..."
  mv "$godotRoot/bin/godot-lib.release.aar" "$godotRoot/bin/godot-lib.template_release.aar"
fi

echo "==> Done. Built files in:"
cd "$godotRoot/bin"
pwd
ls -l

echo "==> AAR ready for Maven publishing:"
echo "    File: $godotRoot/bin/godot-lib.template_release.aar"
echo "    To publish: ./gradlew publish -PgodotVersion=${godotVersion}"
