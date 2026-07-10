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

