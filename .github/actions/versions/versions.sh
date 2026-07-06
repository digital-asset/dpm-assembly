#! /usr/bin/env bash
set -euo pipefail

version_file="$(<VERSION)"

function increment_patch_version() {( set -euo pipefail
    # parse the version string into major, minor, and patch components
    IFS='.' read -r major minor patch <<< "$version_file"

    # Extract numeric part of patch (before any - or non-numeric suffix)
    patch_numeric="${patch%%-*}"

    if [[ "$patch" =~ [^0-9] ]]; then
      # Has a pre-release suffix (e.g. 1-rc2, 0-pre): increment numeric patch, append -snapshot
      dev_patch="$(( patch_numeric + 1 ))"
    else
      # Pure numeric patch: increment it
      dev_patch=$((patch + 1))
    fi

    echo "${major}.${minor}.${dev_patch}"
)}

# Bump the patch version
patch_bump=$(increment_patch_version)

# Get the commit date
commit_date="$(git log -n1 --format=%cd --date=format:%Y%m%d)"

printf -v unstable '%s-snapshot.%s.%s.0.v%s' "${patch_bump}" "${commit_date}" "${GITHUB_RUN_NUMBER}" "${GITHUB_SHA:0:8}"

# Export outputs
cat <<EOF | tee -a "${GITHUB_OUTPUT}"
unstable=${unstable}
stable=${version_file}
EOF
