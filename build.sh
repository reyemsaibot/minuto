#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
npm ci
npm run build
APP="$PWD/build/Minuto.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/web"
swiftc -module-cache-path build/swift-cache main.swift -o "$APP/Contents/MacOS/Minuto" -framework Cocoa -framework WebKit
cp Info.plist "$APP/Contents/Info.plist"
cp Minuto.icns "$APP/Contents/Resources/Minuto.icns"
cp web/app.js web/style.css index.html "$APP/Contents/Resources/web/"
printf '[]\n' > "$APP/Contents/Resources/initial-entries.json"
"$APP/Contents/MacOS/Minuto" --self-test
codesign --force --sign - "$APP"
echo "App erstellt: $APP"
