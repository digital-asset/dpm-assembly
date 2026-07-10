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

cache_dir="$(pwd)/oci-cache"
release_line_minor=$(cat ./weekly-testing/VERSION)
release_line="latest/unstable/$release_line_minor-weekly.yaml"

tmpdir="$(mktemp -d)"
trap "rm -rf $tmpdir" EXIT

resolve_tag() {
  dpm repo resolve-tags --registry=europe-docker.pkg.dev/da-images/public-unstable $1
}

title() (
    echo
    echo "** $1 **" | sed 's/./\*/g'
    echo "** $1 **"
    echo "** $1 **" | sed 's/./\*/g'
    echo
)

title "Calculating versions"

canton_version=$(resolve_tag canton-open-source:$release_line_minor)
cd $tmpdir
oras pull europe-docker.pkg.dev/da-images/public-unstable/components/canton-open-source:$canton_version.generic
cd -
daml_version=$(cat $tmpdir/linked-daml-version)

rm -rf $tmpdir

dpm_version=$(resolve_tag dpm:main)
# Shell isn't publishing 3.6 yet
shell_version=$(resolve_tag daml-shell:3.5)
scribe_version=$(resolve_tag scribe:3.6)

DPM_VERSION=$dpm_version yq e -i '.assistant.version = env(DPM_VERSION)' $release_line

# copy DPM binary from ghcr to GAR
./lib/copy_dpm "${READ_GHCR_REGISTRY_DPM}" "${REGISTRY}" "${release_line}"

daml_components=(codegen daml-new daml-script damlc upgrade-check)
for i in "${!daml_components[@]}"; do
  COMPONENT_NAME=${daml_components[$i]} DAML_VERSION=$daml_version yq e -i '.components[env(COMPONENT_NAME)].version = env(DAML_VERSION)' $release_line
done

CANTON_VERSION=$canton_version yq e -i '.components.canton-open-source.version = env(CANTON_VERSION)' $release_line
SHELL_VERSION=$shell_version yq e -i '.components.daml-shell.version = env(SHELL_VERSION)' $release_line
SCRIBE_VERSION=$scribe_version yq e -i '.components["scribe"].version = env(SCRIBE_VERSION)' $release_line

# Rotation logic
# We keep github handle and slack handle for each person in rotation
# These are both pinged in the PR description
# We then use the slack githubbot integration to forward these PRs to a slack channel, which will resolve the 
# slack username mention into a real ping in slack
rotation_tmp=$(mktemp)
first_line=$(grep -v '^#' weekly-testing/rotation | head -1)
grep -v "$first_line" weekly-testing/rotation > $rotation_tmp
echo "$first_line" >> $rotation_tmp
mv $rotation_tmp weekly-testing/rotation

title "Setup branch"

snapshot_version="${release_line_minor}.0-snapshot.$(date -u +%Y%m%d)"

branch="weekly-snapshot-$snapshot_version"

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git checkout -b $branch

title "Building rotation commit"

git add weekly-testing/rotation
git commit -m "Rotate weekly testing duty"

title "Pushing rotation commit"

git push origin $branch

title "Building rotation commit"

git add latest/unstable/$release_line_minor-weekly.yaml
git commit -m "weekly snapshot $snapshot_version"

title "Building PR description"

gh_username=$(echo $first_line | cut -f2 -d' ')
slack_id=$(echo $first_line | cut -f1 -d' ')

message=$(cat << EOM
cc @$gh_username @samuel-williams-da
slack: <@$slack_id>

Containing following versions:

- canton: \`$canton_version\`
- daml components: \`$daml_version\`
- dpm: \`$dpm_version\`
- daml-shell: \`$shell_version\`
- scribe: \`$scribe_version\`

**PLEASE READ CAREFULLY!** This process is different in DPM, do not merge this PR until you've read this description.

**Do not merge this PR if testing fails**

A snapshot has already been created/published for you to test, but will not be marked as "tested" until you merge this PR.
There should be a comment by the github bot below with the full version string and instructions to download.

If there is an issue with the versions selected, simply update them in a commit to this PR, and the bot will post the same instructions again for the new version once it has published.

Please note on this PR whether the testing has succeeded or failed, and merge/close the PR accordingly.
This PR also includes the updates to the rotation, if testing fails, kindly handle the next weeks testing explicitly checking for whatever was broken this time.

Find release testing instructions [here](https://github.com/digital-asset/daml/blob/main/sdk/release/RELEASE.md#testing)
EOM
)

title "Creating label for snapshot"

gh label create "tag-weekly-$snapshot_version" --description "Release marker for $snapshot_version" --color FFFFFF

title "Opening PR"

pr_url=$(gh pr create \
  --title "Weekly snapshot $snapshot_version" \
  --body "$message" \
  --base main \
  --head $branch \
  --assignee $gh_username \
  --assignee samuel-williams-da \
  --label Standard-Change \
  --label Weekly-Testing \
  --label "tag-weekly-$snapshot_version")

echo $pr_url

# Push the snapshot commit after the PR is created, so labels are available to GHA.
title "Pushing snapshot commit"

git push origin $branch
