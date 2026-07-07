#! /usr/bin/env bash
# Gets the DPM associated with an assembly version, by resolving it first
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

tmpdir="$(mktemp -d)"
oras pull -o "${tmpdir}" "${1}/sdk-manifests/open-source:${2}"
manifest=$(find "${tmpdir}" -name '*.yaml')
dpm_version=$(cat "${manifest}" | grep -A1 assistant | tail -1 | cut -d ' ' -f 6)
rm -rf "$tmpdir"

out="${HOME}/bin"

oras pull --platform "${OS_TYPE}/${CPU_ARCH}" \
  -o "${out}" \
  "${1}/components/dpm:${dpm_version}"

chmod -v +x "${out}/dpm"

export PATH="${out}:${PATH}"
echo "PATH=${out}:${PATH}" >> "${GITHUB_ENV}"
