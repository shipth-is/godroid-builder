#!/usr/bin/env bash
set -euo pipefail

# fetch-gh-release-asset.sh
#
# A Bash clone of dsaltares/fetch-gh-release-asset@1.1.2
#
# Features:
# - version: "latest" | "tags/<tag>" | <numeric release_id>
# - file filtering by exact name (default) or regex (-x)
# - optional GitHub token for private repos / higher rate limits
# - optional custom base API URL (for GHE)
# - 5x retry with backoff on asset download
#
# Usage:
#   ./fetch-gh-release-asset.sh -r owner/repo -v "tags/<tag>|latest|<id>" -f <file-or-regex> [-t <target>] [-g <token>] [-b <base_api_url>] [-x]
#
# Example (your case):
#   ./fetch-gh-release-asset.sh \
#     -r godotengine/godot-swappy \
#     -v tags/from-source-2025-01-31 \
#     -f godot-swappy.7z \
#     -t swappy/godot-swappy.7z

usage() {
  cat <<EOF
Usage: $0 -r owner/repo -v version -f file [-t target] [-g token] [-b base_api_url] [-x]

  -r  Repository in "owner/repo" form (required)
  -v  Version: "latest" | "tags/<tag>" | <numeric release_id> (required)
  -f  File match (exact name by default; use -x for regex) (required)
  -t  Target path (default: same as -f; with -x (regex), acts as prefix)
  -g  GitHub token (optional but recommended for private repos/rate limits)
  -b  Base API URL (default: https://api.github.com)
  -x  Treat -f as a regex (may match multiple assets)
  -h  Show help

Outputs (also writes to \$GITHUB_OUTPUT if present):
  version=<release tag_name>
  name=<release name>
  body=<release body>
EOF
}

REPO=""
VERSION=""
FILE_MATCH=""
TARGET=""
TOKEN="${GITHUB_TOKEN:-}"
BASE_URL="https://api.github.com"
USE_REGEX=0

while getopts ":r:v:f:t:g:b:xh" opt; do
  case "$opt" in
    r) REPO="$OPTARG" ;;
    v) VERSION="$OPTARG" ;;
    f) FILE_MATCH="$OPTARG" ;;
    t) TARGET="$OPTARG" ;;
    g) TOKEN="$OPTARG" ;;
    b) BASE_URL="$OPTARG" ;;
    x) USE_REGEX=1 ;;
    h) usage; exit 0 ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage; exit 1 ;;
    :)  echo "Option -$OPTARG requires an argument." >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$REPO" || -z "$VERSION" || -z "$FILE_MATCH" ]]; then
  echo "Error: -r, -v, and -f are required." >&2
  usage
  exit 1
fi

OWNER="${REPO%%/*}"
REPO_NAME="${REPO##*/}"

if [[ "$OWNER" == "$REPO_NAME" || -z "$OWNER" || -z "$REPO_NAME" ]]; then
  echo "Error: -r must be in 'owner/repo' form." >&2
  exit 1
fi

if [[ -z "${TARGET:-}" ]]; then
  TARGET="$FILE_MATCH"
fi

auth_header=()
if [[ -n "$TOKEN" ]]; then
  auth_header=(-H "Authorization: token $TOKEN")
fi

api() {
  # $1 = path (e.g., /repos/OWNER/REPO/releases/latest)
  # prints JSON to STDOUT, exits nonzero on HTTP error
  local path="$1"
  curl -fsSL "${auth_header[@]}" \
    -H "Accept: application/vnd.github+json" \
    "$BASE_URL$path"
}

# 1) Resolve the release JSON
release_json=""
if [[ "$VERSION" == "latest" ]]; then
  release_json="$(api "/repos/$OWNER/$REPO_NAME/releases/latest")"
elif [[ "$VERSION" == tags/* ]]; then
  tag="${VERSION#tags/}"
  release_json="$(api "/repos/$OWNER/$REPO_NAME/releases/tags/$tag")"
else
  # numeric id
  if ! [[ "$VERSION" =~ ^[0-9]+$ ]]; then
    echo "Error: version must be 'latest', 'tags/<tag>' or a numeric release id." >&2
    exit 1
  fi
  release_json="$(api "/repos/$OWNER/$REPO_NAME/releases/$VERSION")"
fi

# 2) Extract outputs (tag_name, name, body)
rel_tag="$(jq -r '.tag_name // empty' <<<"$release_json")"
rel_name="$(jq -r '.name // empty' <<<"$release_json")"
rel_body="$(jq -r '.body // empty' <<<"$release_json")"

if [[ -z "$rel_tag" ]]; then
  echo "Error: Could not resolve release (empty tag_name). Check repo/version/token." >&2
  exit 1
fi

# Write to GITHUB_OUTPUT if set (to mimic the action)
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "version=$rel_tag"
    echo "name=$rel_name"
    # Preserve body newlines safely
    printf "body<<EOF\n%s\nEOF\n" "$rel_body"
  } >> "$GITHUB_OUTPUT"
fi

# 3) Filter assets
if [[ $USE_REGEX -eq 0 ]]; then
  # exact name match
  assets_json="$(jq -c --arg name "$FILE_MATCH" '.assets[] | select(.name == $name)' <<<"$release_json")"
else
  # regex
  assets_json="$(jq -c --arg re "$FILE_MATCH" '.assets[] | select(.name | test($re))' <<<"$release_json")"
fi

if [[ -z "$assets_json" ]]; then
  echo "Error: No matching assets found for file match '${FILE_MATCH}'." >&2
  exit 1
fi

# 4) Download each matching asset
mkdir -p "$(dirname "$TARGET")" || true

download_asset() {
  local asset_id="$1"
  local out_path="$2"
  local url="$BASE_URL/repos/$OWNER/$REPO_NAME/releases/assets/$asset_id"

  # We request the asset with Accept: application/octet-stream to get a 302 redirect to storage.
  # Use -L to follow redirects and stream to file.
  curl -fSL \
    "${auth_header[@]}" \
    -H "Accept: application/octet-stream" \
    -o "$out_path" \
    "$url"
}

# Retry helper (5 attempts, 1s,2s,3s,4s,5s)
retry_download() {
  local asset_id="$1"
  local out_path="$2"

  local attempt=1
  local max=5
  local delay=1
  while : ; do
    if download_asset "$asset_id" "$out_path"; then
      return 0
    fi
    if (( attempt >= max )); then
      echo "Download failed after $attempt attempts: $out_path" >&2
      return 1
    fi
    echo "Download failed (attempt $attempt). Retrying in ${delay}s..." >&2
    sleep "$delay"
    attempt=$((attempt+1))
    delay=$((delay+1))
  done
}

# Iterate assets and download
matched_any=0
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  asset_id="$(jq -r '.id' <<<"$line")"
  asset_name="$(jq -r '.name' <<<"$line")"

  if [[ $USE_REGEX -eq 1 ]]; then
    # Append asset name to TARGET prefix (like the action does)
    out_path="${TARGET}${asset_name}"
    mkdir -p "$(dirname "$out_path")"
  else
    out_path="$TARGET"
    mkdir -p "$(dirname "$out_path")"
  fi

  echo "Downloading asset id=$asset_id name=$asset_name -> $out_path"
  retry_download "$asset_id" "$out_path"
  matched_any=1
done < <(printf "%s\n" "$assets_json")

if [[ $matched_any -eq 0 ]]; then
  echo "Error: Assets matched but none downloaded (unexpected)." >&2
  exit 1
fi

# Echo outputs for convenience (stdout)
printf "version=%s\nname=%s\n" "$rel_tag" "$rel_name"
# Body may be large; omit on stdout to keep logs tidy. Uncomment if desired:
# printf "body=%s\n" "$rel_body"
