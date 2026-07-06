#! /usr/bin/env bash
set -xeuo pipefail

cache_dir="$(pwd)/oci-cache"

export DPM_LOG_LEVEL=debug
export READ_REGISTRY=${READ_REGISTRY:-"europe-docker.pkg.dev/da-images/public-all"}
export REGISTRY=${REGISTRY:-"europe-docker.pkg.dev/da-images-dev/playground"}
export DPM_ASSEMBLY_RUN_NUMBER=${DPM_ASSEMBLY_RUN_NUMBER:-"0"}
export DOMAIN=${DOMAIN:-"get.digitalasset-staging.com"}
export PROJECT=${PROJECT:-"da-images-dev"}
export BUCKET=${BUCKET:-"da-images-dev-public-unstable"}
export MANIFEST=${MANIFEST:-"latest/unstable/3.5.yaml"}
extra_tags=()

sanitize_extra_tag() {
  echo "${1//\//-}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --extra-tags)
      tag="$(sanitize_extra_tag "$2")"
      extra_tags+=("--extra-tags=$(printf '%q' "${tag}")")
      shift 2
      ;;
    --extra-tags=*)
      value="${1#--extra-tags=}"
      tag="$(sanitize_extra_tag "${value}")"
      extra_tags+=("--extra-tags=$(printf '%q' "${tag}")")
      shift
      ;;
    *)
      shift
      ;;
  esac
done


release_line="${MANIFEST}"
label="$(echo "${release_line}" | grep -oE '[0-9]+\.[0-9]+(-[a-z]+)?')"
edition="$(yq e .edition ${release_line})"
version="$(yq e .version ${release_line}).$(date -u +%Y%m%d).${DPM_ASSEMBLY_RUN_NUMBER}.$(git rev-parse --short HEAD)"
version="${VERSION:-}"

# copy DPM binary from ghcr to GAR
./lib/copy_dpm "${READ_GHCR_REGISTRY_DPM}" "${REGISTRY}" "${release_line}"

# use VERSION passed in, otherwise default to version from the manifest yaml
if [[ -z "$version" ]]; then
  version="$(yq e .version ${release_line}).$(date -u +%Y%m%d).${DPM_ASSEMBLY_RUN_NUMBER}.$(git rev-parse --short HEAD)"
fi

function list_versions() (
  set -euo pipefail
  DPM_EDITION="$1" DPM_REGISTRY="${READ_REGISTRY}" dpm versions
)

if list_versions "${edition}" | grep -E "^${version}\$"
then
  echo "version ${version} is already published. Skipping..."
  exit 0
fi

dpm --version

tmpdir="$(mktemp -d)"
publish_config="${tmpdir}/publish.yaml"

echo "resolving latest component versions..."
resolved="$(dpm  repo resolve-tags \
  --from-publish-config "${release_line}" \
  --registry="${READ_REGISTRY}" 2>/dev/null)"

echo "${resolved}" | yq eval ".version = \"${version}\"" > "${publish_config}"
cat "${publish_config}"
# TODO commit this back into the git repo

# promote any public components back to unstable
time dpm repo promote-components \
  -f "${publish_config}" \
  --source-registry="${READ_REGISTRY}" \
  --destination-registry="${REGISTRY}" \
  --oci-cache="${cache_dir}"


time dpm repo publish-sdk-manifest \
  -f "${publish_config}" \
  --registry="${REGISTRY}" \
  --oci-cache="${cache_dir}" \
  --extra-tags="latest-${label}" \
  "${extra_tags[@]}"

bundles_dir="$(pwd)/bundles"

time dpm repo create-tarball \
  -o "${bundles_dir}" \
  -f "${publish_config}" \
  --registry="${REGISTRY}" \
  --oci-cache="${cache_dir}"

rm -rf "${bundles_dir}/sdk-manifest.yaml" # not needed
for dir in "${bundles_dir}"/*/
do
  dirname="$(basename "$dir")"
  platform="${dirname}"

  if [[ "$platform" == *windows* ]]
  then
    makensis \
      -DSOURCE_DIR="${bundles_dir}/windows-amd64" \
      -DOUT="${bundles_dir}/dpm-${version}-${platform}.exe" \
      script.nsi
    
    (
      cd $"${bundles_dir}"
      zip -r "${bundles_dir}/dpm-${version}-${platform}.zip" "$dirname"
    )
  else 
    tar -czf "${bundles_dir}/dpm-${version}-${platform}.tar.gz" -C "${bundles_dir}" "$dirname"
  fi

done


# assuming there's only a single platform for windows!
windows_archive_filename="dpm-${version}-windows-amd64.zip"
if [ ! -f "${bundles_dir}/${windows_archive_filename}" ]
then
  echo "Aborting because the file ""${bundles_dir}/${windows_archive_filename}"" doesn't exist"
  exit 1
fi

windows_installer_filename="dpm-${version}-windows-amd64.exe"
if [ ! -f "${bundles_dir}/${windows_installer_filename}" ]
then
  echo "Aborting because the file ""${bundles_dir}/${windows_installer_filename}"" doesn't exist"
  exit 1
fi


function upload_bundles() {
  for f in "${bundles_dir}"/*.{tar.gz,exe,zip}
  do
    gsutil cp "${f}" "gs://${BUCKET}/unstable/install/dpm-sdk/"
    gcloud artifacts generic upload \
      --project=${PROJECT} \
      --location=europe \
      --repository=public-generic \
      --package=dpm-sdk \
      --version="${version}" \
      --source="${f}"
  done
}

wait_for_latest() {
  echo "waiting for latest-${label} file to be available..."
  while true
  do
    sleep 10

    if curl "https://${DOMAIN}/unstable/install/latest-${label}" | grep -q "${version}"
    then
      break
    fi
  done
}


generate_windows_latest_installer() {
  _generate_windows_latest_html "https://${DOMAIN}/unstable/install/dpm-sdk/${windows_installer_filename}"
}

generate_windows_latest_archive() {
  _generate_windows_latest_html "https://${DOMAIN}/unstable/install/dpm-sdk/${windows_archive_filename}"
}

_generate_windows_latest_html() {
  url="$1"

  cat <<EOF
<!doctype html>
<html lang="en">
<head>
  <meta http-equiv="refresh" content="0; url=${url}" />
</head>
<body>
Page will automatically redirect, and download for Windows will start shortly...
</body>
</html>
EOF
}


time upload_bundles

# install script and latest file
./render-install-script unstable "${DOMAIN}" "${PROJECT}" > "${tmpdir}/install.sh"
generate_windows_latest_installer > "${tmpdir}/latest-windows.html"
generate_windows_latest_archive > "${tmpdir}/latest-windows-archive.html"
echo "${version}" > "${tmpdir}/latest"
echo "${version}" > "${tmpdir}/latest-${label}"
# /unstable/install/ prefix in bucket is required by infra for proper routing and perms mapping
gsutil cp "${tmpdir}"/install.sh "gs://${BUCKET}/unstable/install/"
gsutil cp "${tmpdir}"/latest-windows.html "gs://${BUCKET}/unstable/install/"
gsutil cp "${tmpdir}"/latest-windows-archive.html "gs://${BUCKET}/unstable/install/"
gsutil cp "${tmpdir}"/latest "gs://${BUCKET}/unstable/install/"
gsutil cp "${tmpdir}"/latest-${label} "gs://${BUCKET}/unstable/install/"

wait_for_latest "$(curl https://${DOMAIN}/unstable/install/latest-${label})"

echo "version=${version}" >> "$GITHUB_OUTPUT"
