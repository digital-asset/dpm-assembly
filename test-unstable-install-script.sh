#! /usr/bin/env bash
# Copyright 2026 Copyright (c) 2026 Digital Asset (Switzerland) GmbH and/or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

set -xeuo pipefail

testdir=test-unstable-dpm-install
mkdir ${testdir}
export DPM_HOME="$(pwd)/${testdir}"

curl "https://${DOMAIN}/unstable/install/install.sh" | DPM_EDITION=open-source bash

"${DPM_HOME}/bin/dpm" versions | grep "${DPM_ASSEMBLY_RUN_NUMBER}"
