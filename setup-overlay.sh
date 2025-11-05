#!/bin/bash

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Usage ./compare-overlay.sh <version>
if [ $# -ne 1 ]; then
  echo "Usage: $0 <godotVersion>"
  exit 1
fi
godotVersion="$1"

${scriptDir}/build-aar.sh "$godotVersion" --downloadOnly

mkdir -p "$scriptDir/overlay/$godotVersion"
cd "$scriptDir/overlay/$godotVersion"
mkdir -p ./platform/android/java/lib/src/org/godotengine/godot/

relativePath="../../godot-$godotVersion/"

cp "$relativePath/platform/android/file_access_android.h" ./platform/android/file_access_android.h
cp "$relativePath/platform/android/detect.py" ./platform/android/detect.py
cp "$relativePath/platform/android/file_access_android.cpp" ./platform/android/file_access_android.cpp
cp "$relativePath/platform/android/SCsub" ./platform/android/SCsub
cp "$relativePath/platform/android/java/lib/build.gradle" ./platform/android/java/lib/build.gradle
cp "$relativePath/platform/android/java/lib/src/org/godotengine/godot/GodotDownloaderService.java" ./platform/android/java/lib/src/org/godotengine/godot/GodotDownloaderService.java
cp "$relativePath/platform/android/java/lib/src/org/godotengine/godot/GodotDownloaderAlarmReceiver.java" ./platform/android/java/lib/src/org/godotengine/godot/GodotDownloaderAlarmReceiver.java
cp "$relativePath/platform/android/java/lib/AndroidManifest.xml" ./platform/android/java/lib/AndroidManifest.xml

cp "$relativePath/platform/android/java/lib/src/org/godotengine/godot/GodotLib.java" ./platform/android/java/lib/src/org/godotengine/godot/GodotLib.java

# one of these will be missing
cp "$relativePath/platform/android/java/lib/src/org/godotengine/godot/Godot.java" ./platform/android/java/lib/src/org/godotengine/godot/Godot.java
cp "$relativePath/platform/android/java/lib/src/org/godotengine/godot/GodotFragment.java" ./platform/android/java/lib/src/org/godotengine/godot/GodotFragment.java


