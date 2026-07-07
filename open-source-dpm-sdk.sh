#! /usr/bin/env bash
set -xeuo pipefail

export READ_REGISTRY=${READ_REGISTRY:-"europe-docker.pkg.dev/da-images/public-all"}
export REGISTRY=${REGISTRY:-"europe-docker.pkg.dev/da-images-dev/playground"}
export DPM_ASSEMBLY_RUN_NUMBER=${DPM_ASSEMBLY_RUN_NUMBER:-"0"}
export DOMAIN=${DOMAIN:-"get.digitalasset-staging.com"}
export PROJECT=${PROJECT:-"da-images-dev"}
export BUCKET=${BUCKET:-"da-images-dev-public-unstable"}

cache_dir="$(pwd)/oci-cache"

function check_version() {
  yaml_version="$(yq e .version ${release_line})"
  if [[ "$yaml_version" == *-snapshot* ]]; then
    echo "${yaml_version}.$(date -u +%Y%m%d).${DPM_ASSEMBLY_RUN_NUMBER}.$(git rev-parse --short HEAD)"
  else
    echo "${yaml_version}"
  fi
}

function list_versions() (
  set -euo pipefail
  DPM_EDITION="$1" dpm versions
)

release_line="latest/open-source/3.5.yaml"
edition="$(yq e .edition ${release_line})"
version="${VERSION:-}"

# copy DPM binary from ghcr to GAR
./lib/copy_dpm "${READ_GHCR_REGISTRY_DPM}" "${REGISTRY}" "${release_line}"

# Use version passed in as envvar, otherwise pull from the manifest yaml file
if [[ -z "$version" ]]; then
  version="$(check_version)"
fi

if list_versions "${edition}" | grep -E "^${version}\$"
then
  echo "version ${version} is already published. Skipping..."
  exit 0
fi

tmpdir="$(mktemp -d)"
publish_config="${tmpdir}/publish.yaml"
# swap out dynamic snapshot version
cat "${release_line}" | yq eval ".version = \"${version}\"" > "${publish_config}"

cat "${publish_config}"

time dpm repo promote-components \
  -f "${publish_config}" \
  --source-registry="${READ_REGISTRY}" \
  --destination-registry="${REGISTRY}" \
  --oci-cache="${cache_dir}"


time dpm repo publish-sdk-manifest \
  -f "${publish_config}" \
  --registry="${REGISTRY}" \
  --oci-cache="${cache_dir}"

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
    gsutil cp "${f}" "gs://${BUCKET}/install/dpm-sdk/"
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
  echo "waiting for latest file to be available..."
  while true
  do
    sleep 10

    if curl "https://${DOMAIN}/install/latest" | grep -q "${version}"
    then
      break
    fi
  done
}


generate_windows_latest_installer() {
  _generate_windows_latest_html "https://${DOMAIN}/install/dpm-sdk/${windows_installer_filename}"
}

generate_windows_latest_archive() {
  _generate_windows_latest_html "https://${DOMAIN}/install/dpm-sdk/${windows_archive_filename}"
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

# install script and latest files
./render-install-script open-source "${DOMAIN}" "${PROJECT}" > "${tmpdir}/install.sh"
generate_windows_latest_installer > "${tmpdir}/latest-windows.html"
generate_windows_latest_archive > "${tmpdir}/latest-windows-archive.html"
echo "${version}" > "${tmpdir}/latest" 

# /install/ prefix in bucket is required by infra for proper routing and perms mapping
gsutil cp "${tmpdir}"/install.sh "gs://${BUCKET}/install/"
gsutil cp "${tmpdir}"/latest-windows.html "gs://${BUCKET}/install/"
gsutil cp "${tmpdir}"/latest-windows-archive.html "gs://${BUCKET}/install/"
gsutil cp "${tmpdir}"/latest "gs://${BUCKET}/install/"

# copy 404.html to bucket
gsutil cp ./404.html "gs://${BUCKET}/"

wait_for_latest "$(curl https://"${DOMAIN}"/install/latest)"
