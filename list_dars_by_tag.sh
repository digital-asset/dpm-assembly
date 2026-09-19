#!/usr/bin/env bash

set -euo pipefail

BASE_REPO=${BASE_REPO:-"europe-docker.pkg.dev/da-images/playground/dars"}
TAG=${TAG:-"devnet"}


echo "Listing repositories under ${BASE_REPO}..."

# Fetch all sub-repositories
REPOS=$(oras repo ls "${BASE_REPO}" 2>/dev/null || true)

if [ -z "${REPOS}" ]; then
  echo "No repositories found or failed to list repositories."
  exit 0
fi

echo -e "\nChecking for tag '${TAG}' and fetching image version:\n"
printf "%-35s %-20s\n" "REPOSITORY" "IMAGE VERSION"
printf "%-35s %-20s\n" "----------" "-------------"

for repo in ${REPOS}; do
  FULL_REPO="${BASE_REPO}/${repo}"

  # Fetch manifest for the specified tag and extract version annotation
  VERSION=$(oras manifest fetch "${FULL_REPO}:${TAG}" 2>/dev/null \
    | jq -r '.annotations["org.opencontainers.image.version"] // empty' || true)

  if [ -n "${VERSION}" ]; then
    printf "%-35s %-20s\n" "${repo}" "${VERSION}"
  fi
done