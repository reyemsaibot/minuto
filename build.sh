#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP="$PWD/build/Minuto.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -parse-as-library \
  -module-cache-path build/swift-cache \
  Minuto.swift \
  -o "$APP/Contents/MacOS/Minuto" \
  -framework SwiftUI \
  -framework AppKit

cp Info.plist "$APP/Contents/Info.plist"
cp Minuto.icns "$APP/Contents/Resources/Minuto.icns"
codesign --force --sign - "$APP"

echo "App erstellt: $APP"
