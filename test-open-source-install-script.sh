#! /usr/bin/env bash
# Copyright 2026 Copyright (c) 2026 Digital Asset (Switzerland) GmbH and/or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

set -xeuo pipefail

testdir=test-open-source-dpm-install
mkdir ${testdir}
export DPM_HOME="$(pwd)/${testdir}"

curl "https://${DOMAIN}/install/install.sh" | DPM_EDITION=open-source bash

release_line="latest/open-source/3.5.yaml"
"${DPM_HOME}/bin/dpm" versions | grep "$(yq .version ${release_line})"
