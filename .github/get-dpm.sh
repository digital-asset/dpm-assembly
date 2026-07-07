#! /usr/bin/env bash
set -xeuo pipefail

if [[ "$(uname -s)" == *"MINGW"* ]]; then
  OS_TYPE='windows'
else
  OS_TYPE="$(uname -s | tr A-Z a-z)"
fi
if [[ $(uname -m) == 'x86_64' ]]; then
  CPU_ARCH='amd64'
else
  CPU_ARCH="$(uname -m)"
fi

out="${HOME}/bin"

oras pull --platform "${OS_TYPE}/${CPU_ARCH}" \
  -o "${out}" \
  "${1}/components/dpm:${2}"

chmod -v +x "${out}/dpm"

export PATH="${out}:${PATH}"
echo "PATH=${out}:${PATH}" >> "${GITHUB_ENV}"
