#!/usr/bin/env bash
set -euo pipefail
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
}

export -f process_dar
export ENVIRONMENT

find "$DARS_DIR" -type f -name '*.dar' -print0 |
  # run in parallel as there are many files to process
  xargs -0 -n 1 -P 16 bash -c 'process_dar "$1"' _

find_greatest_semver() {
    [ $# -eq 0 ] && return 1
    printf '%s\n' "$@" | sort -V | tail -n 1
}

declare -A versions
declare -A dar_paths

while IFS= read -r -d '' dar; do
    file=${dar##*/}

    # Only match semantic versions: foo-1.2.3.dar
    if [[ "$file" =~ ^(.+)-([0-9]+\.[0-9]+\.[0-9]+)\.dar$ ]]; then
        name="${BASH_REMATCH[1]}"
        version="${BASH_REMATCH[2]}"

        # Gather versions for this artifact
        versions["$name"]+="${version} "

        # Remember the DAR path for this artifact/version
        dar_paths["$name|$version"]="$dar"
    fi
done < <(find "$DARS_DIR" -type f -name '*.dar' -print0)

# Find greatest version for each artifact and tag it latest
for name in "${!versions[@]}"; do
    read -ra version_list <<< "${versions[$name]}"

    greatest=$(find_greatest_semver "${version_list[@]}")
    dar="${dar_paths["$name|$greatest"]}"

    echo "latest: $name -> $greatest ($dar)"
    artifact_path="europe-docker.pkg.dev/da-images/playground/dars/${name}:${greatest}"
    echo "Tagging $artifact_path version $greatest tag $ENVIRONMENT"
    oras manifest delete --force "${artifact_path}:devnet"
    oras manifest delete --force "${artifact_path}:testnet"
    oras manifest delete --force "${artifact_path}:mainnet"
    
    oras tag "$artifact_path" "$ENVIRONMENT"
done

echo "Done."

rm -rf "$DARS_DIR"