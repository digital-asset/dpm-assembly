#!/usr/bin/env bash
set -euox pipefail
: "${VERSION:?VERSION environment variable is required}"
: "${ENVIRONMENT:?ENVIRONMENT environment variable is required}"

URL="https://github.com/digital-asset/decentralized-canton-sync/releases/download/v${VERSION}/${VERSION}_splice-node.tar.gz"
ARCHIVE="${VERSION}_splice-node.tar.gz"
DARS_DIR="./splice-node/dars"

mkdir -p "$DARS_DIR"

if [[ -f "$ARCHIVE" ]]; then
  echo "Archive already exists: $ARCHIVE"
else
  echo "Downloading $URL..."
  curl -fL "$URL" -o "$ARCHIVE"
fi

echo "Extracting .dar files..."
tar -xzf "$ARCHIVE" \
  --wildcards \
  '*.dar' '*LICENSE' \
  --no-anchored \
  -C "$DARS_DIR"

process_dar() {
  local dar="$1"
  local filename version artifact tag artifact_path

  filename="$(basename "$dar" .dar)"
  version="${filename##*-}"
  artifact="${filename%-"$version"}"
  tag="${ENVIRONMENT}"

  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Skipping $dar: version '$version' is not valid semver"
    return 0
  fi

  echo "Uploading $artifact version $version"
  artifact_path="europe-docker.pkg.dev/da-images/playground/dars/${artifact}:${version}"

  dpm publish dar "oci://${artifact_path}" -f "$dar" \
    --license ./splice-node/LICENSE
#    --extra-tags "${tag}"

  echo "Tagging $artifact version $version tag $tag"
  oras tag "$artifact_path" "$tag"
}

export -f process_dar
export ENVIRONMENT

find "$DARS_DIR" -type f -name '*.dar' -print0 |
  # run in parallel as there are many files to process
  xargs -0 -n 1 -P 16 bash -c 'process_dar "$1"' _

tag_greatest() {
  # Find the highest version for each artifact and tag it latest
  find "$DARS_DIR" -type f -name '*.dar' -print0 |
    while IFS= read -r -d '' dar; do
      file=${dar##*/}
      if [[ $file =~ ^(.+)-([0-9]+\.[0-9]+\.[0-9]+)\.dar$ ]]; then
        printf '%s\t%s\t%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "$dar"
      fi
    done |
    sort -t$'\t' -k1,1 -k2,2V |
    awk -F'\t' '
      $1 != prev {
        if (prev != "") print last
        prev = $1
      }
      { last = $0 }
      END {
        if (prev != "") print last
      }
    ' |
    while IFS=$'\t' read -r name version dar; do
      artifact_path="europe-docker.pkg.dev/da-images/playground/dars/${name}:${version}"
      oras tag "$artifact_path" "$tag"
    done
}

tag_greatest

echo "Done."

rm -rf "$DARS_DIR"