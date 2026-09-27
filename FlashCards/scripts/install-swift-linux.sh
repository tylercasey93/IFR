#!/usr/bin/env bash
set -euo pipefail
SWIFT_VERSION="${SWIFT_VERSION:-6.0.3}"
INSTALL_DIR="${INSTALL_DIR:-/opt/swift}"
if [ -x "$INSTALL_DIR/usr/bin/swift" ]; then
  echo "Swift already installed at $INSTALL_DIR"
  exit 0
fi
UBUNTU_TAG="$(. /etc/os-release && echo "ubuntu${VERSION_ID}")"
ARCHIVE="swift-${SWIFT_VERSION}-RELEASE-${UBUNTU_TAG}.tar.gz"
URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/${UBUNTU_TAG//./}/swift-${SWIFT_VERSION}-RELEASE/${ARCHIVE}"
mkdir -p "$INSTALL_DIR"
curl -sS -L -o "/tmp/${ARCHIVE}" "$URL"
tar -xzf "/tmp/${ARCHIVE}" -C "$INSTALL_DIR" --strip-components=1
rm "/tmp/${ARCHIVE}"
echo "Installed Swift ${SWIFT_VERSION} to $INSTALL_DIR; add $INSTALL_DIR/usr/bin to PATH"
