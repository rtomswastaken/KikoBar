#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> Building Kikobar (Release)..."
cd "${PROJECT_ROOT}"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/Kikobar"
APP_DIR="${PROJECT_ROOT}/build/Kikobar.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Assembling ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BIN_PATH}" "${MACOS_DIR}/Kikobar"
chmod +x "${MACOS_DIR}/Kikobar"

if [ -f "${PROJECT_ROOT}/Resources/Info.plist" ]; then
    cp "${PROJECT_ROOT}/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
fi

if [ -f "${PROJECT_ROOT}/Resources/AppIcon.icns" ]; then
    echo "==> Installing AppIcon..."
    cp "${PROJECT_ROOT}/Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

if [ -d "${PROJECT_ROOT}/Resources/Fonts" ]; then
    echo "==> Copying custom fonts..."
    mkdir -p "${RESOURCES_DIR}/Fonts"
    cp -R "${PROJECT_ROOT}/Resources/Fonts/"* "${RESOURCES_DIR}/Fonts/"
fi

echo -n "APPL????" > "${CONTENTS_DIR}/PkgInfo"

if command -v codesign &>/dev/null; then
    echo "==> Ad-hoc signing bundle..."
    codesign --force --deep --sign - "${APP_DIR}"
fi

# Package distribution archive in Releases/
RELEASES_DIR="${PROJECT_ROOT}/Releases"
mkdir -p "${RELEASES_DIR}"
echo "==> Packaging Alpha release archive..."
(cd "${PROJECT_ROOT}/build" && zip -r -q -y "${RELEASES_DIR}/Kikobar-v0.1.0-alpha.zip" "Kikobar.app")
echo "==> Distribution archive created at: ${RELEASES_DIR}/Kikobar-v0.1.0-alpha.zip"

echo "==> Successfully packaged Kikobar.app at: ${APP_DIR}"
