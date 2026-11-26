#!/usr/bin/env bash

set -euo pipefail

REGISTRY="europe-docker.pkg.dev/da-images/public"
COMPONENTS=("daml-shell" "canton-open-source" "codegen" "daml-new" "daml-script" "damlc" "scribe" "upgrade-check")
SDK_REPO="${REGISTRY}/sdk-manifests/open-source"

usage() {
    echo "Usage: $0 <major.minor.patch>"
    exit 1
}

# Validate input
[[ $# -eq 1 ]] || usage

INPUT_VERSION="$1"

if [[ ! "$INPUT_VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "Error: version must be major.minor.patch"
    exit 1
fi

MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"

for cmd in oras crane yq sort grep; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "Error: required command '$cmd' not found"
        exit 1
    }
done

# Return the highest available patch for a component
get_component_version() {
    local component="$1"
    local repo="${REGISTRY}/components/${component}"

    local tags
    tags=$(oras repo tags "$repo" 2>/dev/null) || {
        echo "Error: unable to retrieve tags for $component" >&2
        return 1
    }

    local latest
    latest=$(
        printf '%s\n' "$tags" |
            grep -E "^${MAJOR}\.${MINOR}\.[0-9]+$" |
            sort -V |
            tail -n 1
    ) || true

    if [[ -z "$latest" ]]; then
        echo "N/A"
    else
        echo "$latest"
    fi
}

echo "Component versions (requested: ${INPUT_VERSION})"
echo "-----------------------------------------------"

for component in "${COMPONENTS[@]}"; do
    version=$(get_component_version "$component")
    printf "%-20s %s\n" "$component" "$version"
done

# Find the SDK bundle containing a specific Canton version
find_sdk_bundle() {
    local canton_version="$1"

    echo
    echo "Searching SDK bundles for Canton ${canton_version}..."
    echo "-----------------------------------------------"

    local tags
    tags=$(oras repo tags "$SDK_REPO" 2>/dev/null) || {
        echo "Error: unable to retrieve SDK manifest tags" >&2
        return 1
    }

    # Only inspect stable SDK bundle versions matching the requested
    # major.minor version.
    local sdk_tags
    sdk_tags=$(
        printf '%s\n' "$tags" |
            grep -E "^${MAJOR}\.${MINOR}\.[0-9]+$" |
            sort -Vr
    ) || true

    local found=""

    while IFS= read -r tag; do
        [[ -z "$tag" ]] && continue

        local bundle_canton
        bundle_canton=$(
            crane export "${SDK_REPO}:${tag}" - 2>/dev/null |
                yq -r '.spec.components."canton-open-source".version // ""' 2>/dev/null
        ) || continue

        if [[ "$bundle_canton" == "$canton_version" ]]; then
            found="$tag"
            break
        fi
    done <<< "$sdk_tags"

    if [[ -n "$found" ]]; then
        echo "Canton version: ${canton_version}"
        echo "SDK bundle:     ${found}"
    else
        echo "No SDK bundle found for Canton ${canton_version}"
    fi
}

find_sdk_bundle "$1"

