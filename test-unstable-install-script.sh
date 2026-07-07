#! /usr/bin/env bash
set -xeuo pipefail

testdir=test-unstable-dpm-install
mkdir ${testdir}
export DPM_HOME="$(pwd)/${testdir}"

curl "https://${DOMAIN}/unstable/install/install.sh" | DPM_EDITION=open-source bash

"${DPM_HOME}/bin/dpm" versions | grep "${DPM_ASSEMBLY_RUN_NUMBER}"
