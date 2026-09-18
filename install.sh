#!/bin/sh
set -eu

show_usage() {
  cat <<'EOF'
Usage: ./install.sh [OPTION]

Bootstrap a minimal Linux development environment.

Target Environments:
  - Debian 12
  - Ubuntu 22.04 / 24.04
  - Alpine 3.20

Required Packages:
  git, curl, jq, python3, ca-certificates

Options:
  --check     Check for required tools and exit 0 if all are present
  --dry-run   Simulate installation and print package operations without modifying system
  --help, -h  Display this help message and exit

CI Safety:
  When run with no arguments and CI=true is set in the environment,
  install.sh automatically defaults to --dry-run mode.
EOF
}

detect_pkg_mgr() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "apt-get"
  elif command -v apk >/dev/null 2>&1; then
    echo "apk"
  else
    echo ""
  fi
}

check_item_installed() {
  item="$1"
  pkg_mgr="$2"

  case "$item" in
    git|curl|jq|python3)
      command -v "$item" >/dev/null 2>&1
      ;;
    ca-certificates)
      if [ "$pkg_mgr" = "apt-get" ] && command -v dpkg-query >/dev/null 2>&1; then
        dpkg-query -W -f='${Status}' ca-certificates 2>/dev/null | grep -q "ok installed"
      elif [ "$pkg_mgr" = "apk" ] && command -v apk >/dev/null 2>&1; then
        apk info -e ca-certificates >/dev/null 2>&1
      else
        [ -f /etc/ssl/certs/ca-certificates.crt ] || \
        [ -f /etc/ssl/cert.pem ] || \
        command -v update-ca-certificates >/dev/null 2>&1 || \
        [ -x /usr/sbin/update-ca-certificates ]
      fi
      ;;
    *)
      return 1
      ;;
  esac
}

find_missing_items() {
  pkg_mgr="$1"
  missing=""
  for item in git curl jq python3 ca-certificates; do
    if ! check_item_installed "$item" "$pkg_mgr"; then
      if [ -z "$missing" ]; then
        missing="$item"
      else
        missing="$missing $item"
      fi
    fi
  done
  echo "$missing"
}

# Parse command line options
MODE="install"

if [ $# -gt 0 ]; then
  case "$1" in
    --check)
      MODE="check"
      ;;
    --dry-run)
      MODE="dry-run"
      ;;
    --help|-h)
      show_usage
      exit 0
      ;;
    *)
      echo "Error: Unknown argument '$1'" >&2
      show_usage >&2
      exit 1
      ;;
  esac
  if [ $# -gt 1 ]; then
    echo "Error: Unexpected additional arguments." >&2
    show_usage >&2
    exit 1
  fi
else
  if [ "${CI:-}" = "true" ]; then
    echo "CI environment detected; running in dry-run mode."
    MODE="dry-run"
  fi
fi

PKG_MGR="$(detect_pkg_mgr)"

# Check mode: purely inspect required tools
if [ "$MODE" = "check" ]; then
  echo "Checking required development tools..."
  missing_count=0
  for item in git curl jq python3 ca-certificates; do
    if check_item_installed "$item" "$PKG_MGR"; then
      echo "  [OK] $item"
    else
      echo "  [MISSING] $item"
      missing_count=$((missing_count + 1))
    fi
  done

  if [ "$missing_count" -eq 0 ]; then
    echo "All required tools are installed."
    exit 0
  else
    echo "Missing $missing_count required tool(s)." >&2
    exit 1
  fi
fi

# Dry-run and Install modes require a supported package manager
if [ -z "$PKG_MGR" ]; then
  echo "Error: Unsupported environment. Neither 'apt-get' nor 'apk' was found." >&2
  exit 1
fi

MISSING_PKGS="$(find_missing_items "$PKG_MGR")"

if [ "$MODE" = "dry-run" ]; then
  echo "Package manager detected: $PKG_MGR"
  if [ -z "$MISSING_PKGS" ]; then
    echo "All required packages are already installed. No operations would be performed."
    exit 0
  fi

  echo "Missing packages: $MISSING_PKGS"
  echo "Dry-run: The following operations would be performed:"
  if [ "$PKG_MGR" = "apt-get" ]; then
    echo "  export DEBIAN_FRONTEND=noninteractive"
    echo "  apt-get update"
    echo "  apt-get install -y --no-install-recommends $MISSING_PKGS"
  elif [ "$PKG_MGR" = "apk" ]; then
    echo "  apk add --no-cache $MISSING_PKGS"
  fi
  exit 0
fi

# Normal install mode
if [ -z "$MISSING_PKGS" ]; then
  echo "All required packages are already installed."
  exit 0
fi

# Check root privilege before installation
if [ "$(id -u 2>/dev/null || true)" != "0" ]; then
  echo "Error: Root privileges are required to install missing packages: $MISSING_PKGS" >&2
  echo "Please rerun with sudo or as root (e.g., sudo $0)." >&2
  exit 1
fi

echo "Installing missing packages: $MISSING_PKGS"
if [ "$PKG_MGR" = "apt-get" ]; then
  echo "Updating package index..."
  DEBIAN_FRONTEND=noninteractive apt-get update
  echo "Installing packages..."
  # shellcheck disable=SC2086
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $MISSING_PKGS
elif [ "$PKG_MGR" = "apk" ]; then
  echo "Installing packages..."
  # shellcheck disable=SC2086
  apk add --no-cache $MISSING_PKGS
fi

# Verify installation
REMAINING_MISSING="$(find_missing_items "$PKG_MGR")"
if [ -n "$REMAINING_MISSING" ]; then
  echo "Error: Failed to install all required packages. Still missing: $REMAINING_MISSING" >&2
  exit 1
fi

echo "Successfully bootstrapped development environment."
exit 0
