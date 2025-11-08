#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# overlay-dedupe.sh  —  find & deduplicate overlay files
# For Ubuntu 22.04 LTS
#
# Usage:
#   ./overlay-dedupe.sh --install
#   ./overlay-dedupe.sh --scan
#   ./overlay-dedupe.sh --diff [base_version]
#   ./overlay-dedupe.sh --dedupe [--no-dry-run]
#
# Default mode for --dedupe is dry-run (no file changes).
# ==========================================================

REQUIRED_TOOLS=(sha256sum awk sort uniq grep realpath fdupes diff)

install_tools() {
  echo "[INFO] Installing required packages..."
  sudo apt-get update -y
  sudo apt-get install -y coreutils util-linux diffutils fdupes
  echo "[INFO] Installation complete."
}

scan_duplicates() {
  echo "[INFO] Scanning for identical files..."
  tmpfile=$(mktemp)
  find . -type f ! -lname '*' -exec sha256sum {} + | sort > "$tmpfile"
  echo "[INFO] Writing checksum list to checksums.txt"
  cp "$tmpfile" checksums.txt

  echo "[INFO] Identical file groups:"
  awk '{print $1}' "$tmpfile" | uniq -d | while read -r hash; do
    echo "=== Duplicate group ($hash) ==="
    grep "$hash" "$tmpfile"
  done
}

dedupe_symlinks() {
  local dry_run=true
  if [[ "${1:-}" == "--no-dry-run" ]]; then
    dry_run=false
    echo "[WARNING] Running in live mode — files will be replaced by symlinks."
  else
    echo "[INFO] Running in dry-run mode (default) — no files will be changed."
  fi

  echo "[INFO] Finding exact duplicates..."
  tmpfile=$(mktemp)
  find . -type f ! -lname '*' -exec sha256sum {} + | sort > "$tmpfile"

  awk '{print $1}' "$tmpfile" | uniq -d | while read -r hash; do
    target=$(grep "$hash" "$tmpfile" | head -n1 | awk '{print $2}')
    grep "$hash" "$tmpfile" | tail -n +2 | awk '{print $2}' | while read -r dup; do
      if [ "$dup" != "$target" ]; then
        rel_target=$(realpath --relative-to="$(dirname "$dup")" "$target")
        echo "Would link: $dup -> $rel_target"
        if [ "$dry_run" = false ]; then
          rm -f "$dup"
          ln -s "$rel_target" "$dup"
        fi
      fi
    done
  done

  if [ "$dry_run" = true ]; then
    echo "[INFO] Dry-run complete. No files modified."
  else
    echo "[INFO] Deduplication complete. Symlinks created."
  fi
}

compare_diffs() {
  base=${1:-4.5}
  if [ ! -d "$base" ]; then
    echo "[ERROR] Base directory '$base' not found."
    exit 1
  fi
  echo "[INFO] Comparing $base to other versions..."
  for ver in 4.*; do
    [ "$ver" = "$base" ] && continue
    echo "--- Comparing $base vs $ver ---"
    diff -qr "$base" "$ver" || true
  done
  echo "[INFO] Diff comparison complete."
}

# ------------------ Main ------------------
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 [--install | --scan | --dedupe [--no-dry-run] | --diff <base_version>]"
  exit 1
fi

case "$1" in
  --install)
    install_tools
    ;;
  --scan)
    scan_duplicates
    ;;
  --dedupe)
    shift || true
    dedupe_symlinks "$@"
    ;;
  --diff)
    shift
    compare_diffs "$@"
    ;;
  *)
    echo "Unknown command: $1"
    exit 1
    ;;
esac

