#!/bin/bash
set -e

echo "🔨 Building Javira in Release configuration..."
swift build -c release --product Javira

APP_NAME="Javira"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Packaging ${APP_NAME}.app..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

BIN_DIR=$(swift build --show-bin-path -c release)

# Copy binary
cp "${BIN_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist
cp "Javira/Info.plist" "${CONTENTS_DIR}/Info.plist"

# Strip extended attributes before signing
xattr -cr "${APP_DIR}"

# Codesign with ad-hoc signature for local execution
echo "🔏 Code-signing ${APP_NAME}.app..."
codesign --force --deep --sign - --entitlements "Javira/Javira.entitlements" "${APP_DIR}"

echo "✅ Successfully built and signed ${APP_NAME}.app!"
echo "You can launch it by running: open ${APP_NAME}.app"
