#! /usr/bin/env bash
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
