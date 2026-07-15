# Copyright 2026 Copyright (c) 2026 Digital Asset (Switzerland) GmbH and/or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

if [ "${1:-}" = "-h" ] || [ "${1-}" = "--help" ]
then
  help
  exit 0
fi


readonly INSTALL_MINSIZE=1000000
if [ -z "${TEMPDIR:-}" ]
then
  readonly TMPDIR="$(mktemp -d)"
else
  readonly TMPDIR="${TEMPDIR}"
  if [ ! -d "${TEMPDIR}" ]
  then
    mkdir "${TEMPDIR}"
  fi
fi

# Don't remove user specified temporary directory on cleanup.
rmTmpDir() {
  if [ -z "${TEMPDIR:-}" ]; then
    rm -rf "${TMPDIR}"
  else
    echo "You may now remove the Dpm installation files from ${TEMPDIR}"
  fi
}

cleanup() {
  echo "$(tput setaf 3)FAILED TO INSTALL!$(tput sgr 0)"
  rmTmpDir
}
trap cleanup EXIT


#
# Check that the temporary directory has enough space for the installation
#
if [ -x "$(command -v df)" -a -x "$(command -v awk)" ]
then
  if [ "$(df "${TMPDIR}" | tail -1 | awk '{print $4}')" -lt "${INSTALL_MINSIZE}" ]
  then
    echo "Not enough disk space available to extract Dpm SDK in ${TMPDIR}."
    echo ""
    echo "You can specify an alternative extraction directory by"
    echo "setting the TEMPDIR environment variable."
    exit 1
  fi
fi

#
# Determine SDK version
#
if [ -z "${1:-}" ]
then
  echo "Determining latest SDK version..."
  readonly VERSION="$(curl -sS "${LATEST_VERSION_URL}")"
  if [ -z "${VERSION}" ] ; then
    echo "Failed to determine latest SDK version."
    exit 1
  fi
  echo "Latest SDK version is ${VERSION}"
else 
  VERSION="${1}"
fi

#
# Determine platform.
#
readonly OSNAME="$(uname -s)"
if [ "${OSNAME}" = "Linux" ] ; then
  OS="linux"
elif [ "${OSNAME}" = "Darwin" ] ; then
  OS="darwin"
else
  echo "Operating system not supported:"
  echo "  OSNAME = ${OSNAME}"
  exit 1
fi

ARCH=
UNAME="$(uname -m)"
case "${UNAME}" in
  x86_64)
    ARCH="amd64"
    ;;
  aarch64|arm64)
    ARCH="arm64"
    ;;
  *)
    echo "Unsupported architecture: ${UNAME} for ${VERSION} on ${OS}."
    exit 1
    ;;
esac


#
# Download SDK tarball
#
# Can't assume jq

readonly TARBALL="dpm-${VERSION}-${OS}-${ARCH}.tar.gz"
TARBALL_URL="https://artifactregistry.googleapis.com/download/v1/projects/${GOOGLE_PROJECT}/locations/europe/repositories/${TARBALL_REPO}/files/dpm-sdk:${VERSION}:${TARBALL}:download?alt=media"

echo "$(tput setaf 3)Downloading SDK ${TARBALL_URL}. This may take a while.$(tput sgr 0)"
fetch_tarball() {
  curl -SLf "${TARBALL_URL}" --output "${TMPDIR}/${TARBALL}" --progress-bar "$@"
}
case "${TARBALL_FETCH_ARGS}" in
  -n) fetch_tarball -n ;;
  -H) fetch_tarball -H "${TARBALL_FETCH_AUTH}" ;;
  *) fetch_tarball ;;
esac
if [ ! -f "${TMPDIR}/${TARBALL}" ] ; then
  echo "Failed to download SDK tarball ${TARBALL_URL}."
  exit 1
fi


#
# Extract and install SDK tarball.
#
echo "Extracting SDK release tarball."
extracted="${TMPDIR}/extracted"
mkdir -p "${extracted}"

tar xzf "${TMPDIR}/${TARBALL}" -C "${extracted}" --strip-components 1
"${extracted}/bin/dpm" bootstrap "${extracted}"

setup_post_install_auth

#
# Done.
#
trap - EXIT
echo "$(tput setaf 3)Successfully installed Dpm.$(tput sgr 0)"
rmTmpDir
