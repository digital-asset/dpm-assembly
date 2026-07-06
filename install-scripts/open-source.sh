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
