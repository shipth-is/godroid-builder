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
- Cleanup this repo - replace the GPT code in build-aar.sh and fetch-gh-release-asset.sh
- Other Godot versions
- Debug build of AAR
