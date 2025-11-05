#!/bin/bash


mkdir -p overlay/4.2
cd overlay/4.2
mkdir -p ./platform/android/java/lib/src/org/godotengine/godot/

cp ../../godot-4.2/platform/android/file_access_android.h ./platform/android/file_access_android.h
cp ../../godot-4.2/platform/android/detect.py ./platform/android/detect.py
cp ../../godot-4.2/platform/android/file_access_android.cpp ./platform/android/file_access_android.cpp
cp ../../godot-4.2/platform/android/SCsub ./platform/android/SCsub
cp ../../godot-4.2/platform/android/java/lib/build.gradle ./platform/android/java/lib/build.gradle
cp ../../godot-4.2/platform/android/java/lib/src/org/godotengine/godot/GodotFragment.java ./platform/android/java/lib/src/org/godotengine/godot/GodotFragment.java
cp ../../godot-4.2/platform/android/java/lib/src/org/godotengine/godot/GodotLib.java ./platform/android/java/lib/src/org/godotengine/godot/GodotLib.java
cp ../../godot-4.2/platform/android/java/lib/src/org/godotengine/godot/GodotDownloaderService.java ./platform/android/java/lib/src/org/godotengine/godot/GodotDownloaderService.java
cp ../../godot-4.2/platform/android/java/lib/src/org/godotengine/godot/GodotDownloaderAlarmReceiver.java ./platform/android/java/lib/src/org/godotengine/godot/GodotDownloaderAlarmReceiver.java
cp ../../godot-4.2/platform/android/java/lib/AndroidManifest.xml ./platform/android/java/lib/AndroidManifest.xml


