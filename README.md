# Different approach

## Setup

- build the game as APK (via AAB is cool) on the backend
- extract the whole "assets" folder from the APK
- zip this up and serve

## App overview

- App has patched AssetsDirectoryAccess from godot game engine
- Patched AssetsDirectoryAccess reads from app storage instead of apk assets

- download the zip and put in the app storage e.g /data/data/com.example.myapp/files
- unzip to a dir based on the id of the game /data/data/com.example.myapp/files/assets-abc123
- symlink an assets folder in the app storage /data/data/com.example.myapp/files/assets
- launch as normal via GodotActivity (correct versioned one)

## Todo - godot

- checkout godot engine code @ 4.4.1
- patch AssetsDirectoryAccess
- apply namespace magic
- build to an AAR file?
  - https://github.com/godotengine/godot/blob/master/.github/workflows/android_builds.yml#L84
  - gradle build generateGodotTemplates
  - will make the AAR file

## Todo - app

- create skeleton
- import the AAR file
- download zip from hardcoded url
- unzip, symlink etc
- launch

```bash
git clone https://github.com/godotengine/godot.git -b 4.4.1-stable godot-4.4.1
cd godot-4.4.1
```

```bash
grep -riI --exclude-dir='.*' "org.godotengine.godot"
```

## Name-spacing

// Namespace should become:
// "org.godotengine.godotv4_4_1"

mv godot-4.4.1/platform/android/java/lib/src/org/godotengine/godot \
  godot-4.4.1/platform/android/java/lib/src/org/godotengine/godotv4_4_1

grep -ril --exclude-dir='.*' "org\.godotengine\.godot" \
| xargs sed -i 's/org\.godotengine\.godot/org.godotengine.godotv4_4_1/g'

grep -ril --exclude-dir='.*' "org/godotengine/godot" \
| xargs sed -i 's|org/godotengine/godot|org/godotengine/godotv4_4_1|g'

grep -ril --exclude-dir='.*' "Java_org_godotengine_godot_" \
| xargs sed -i 's|Java_org_godotengine_godot_|Java_org_godotengine_godotv4_1_4_1_|g'
