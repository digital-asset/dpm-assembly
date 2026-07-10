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

testdir=test-unstable-dpm-install
mkdir ${testdir}
export DPM_HOME="$(pwd)/${testdir}"

curl "https://${DOMAIN}/unstable/install/install.sh" | DPM_EDITION=open-source bash

"${DPM_HOME}/bin/dpm" versions | grep "${DPM_ASSEMBLY_RUN_NUMBER}"
