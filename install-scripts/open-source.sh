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

LATEST_VERSION_URL="https://${DPM_DOMAIN}/install/latest"
TARBALL_REPO="public-generic"
TARBALL_FETCH_ARGS=""

help() (
  cat <<EOF
USAGE:
  install.sh            Download and install the latest SDK release.
  install.sh VERSION    Download and install given version of SDK.
EOF
)

setup_post_install_auth() {
  # NOP
  true
}
