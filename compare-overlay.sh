#!/bin/bash
set -euo pipefail

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Usage ./compare-overlay.sh <version>
if [ $# -ne 1 ]; then
  echo "Usage: $0 <godotVersion>"
  exit 1
fi
godotVersion="$1"

# get the code
${scriptDir}/build-aar.sh "$godotVersion" --downloadOnly
godotRoot="${scriptDir}/godot-${godotVersion}"

filesToCompare=$(find "${scriptDir}/overlay/${godotVersion}" -type f)
for overlayFile in $filesToCompare; do
  relativePath="${overlayFile#${scriptDir}/overlay/${godotVersion}/}"
  godotFile="${godotRoot}/${relativePath}"
  echo "----------------------------------------"
  echo "Comparing overlay file: ${relativePath} with base file: ${godotFile}"
  if [ ! -s "${overlayFile}" ]; then
    echo "Truncated file: ${overlayFile}"
  else
    # if there are no differences then we warn with a yellow message
    if ! diff -u "${godotFile}" "${overlayFile}" >/dev/null; then
      diff -u "${godotFile}" "${overlayFile}" || true
    else
      echo -e "\e[33mNo differences found for file: ${relativePath}\e[0m"
    fi
    
  fi
  echo "----------------------------------------"
done
