# Godroid Builder

## Patched and namespaced builds of the Android Godot library

This repo creates namespaced versions of godot-lib.template_release.aar with custom patches included.

## Running

```bash
./build-aar.sh
```

## Notes

- Working for 4.4.1 stable

## TODO

- Asset path - is the value safe for different android setups?
- Asset path - make configurable
- Other Godot versions
- Debug build of AAR


```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  p7zip-full rsync curl jq build-essential pkg-config libx11-dev libxcursor-dev \
  libxinerama-dev libgl1-mesa-dev libglu-dev libasound2-dev libpulse-dev libdbus-1-dev \
  libudev-dev libxi-dev libxrandr-dev yasm xvfb wget unzip libspeechd-dev speech-dispatcher \
  python3 python3-pip
pip3 install --user --break-system-packages scons
```