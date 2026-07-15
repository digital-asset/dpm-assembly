# Copyright 2026 Copyright (c) 2026 Digital Asset (Switzerland) GmbH and/or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

FROM ensignprojects/ubuntu-curl:latest AS builder

WORKDIR /root

ARG VERSION
ENV VERSION="${VERSION}"

# Download and run the shell script
RUN curl -sSL https://get.digitalasset.com/unstable/install/install.sh | sh -s ${VERSION} \
 && rm -rf /root/.dpm/cache/oci-layout/*
FROM europe-docker.pkg.dev/da-images/public/docker/da-base-image:jdk
 
ARG VERSION
ENV VERSION="${VERSION}"

WORKDIR /home/nonroot
COPY --from=builder /root/.dpm /home/nonroot/.dpm
ENV PATH="/home/nonroot/.dpm/bin:${PATH}"
ENTRYPOINT ["dpm"]

