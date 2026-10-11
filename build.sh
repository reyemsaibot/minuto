#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP="$PWD/build/Minuto.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

SOURCE_FILES=(
  Sources/Models.swift
  Sources/MinutoDomain.swift
  Sources/MinutoPersistence.swift
  Sources/MinutoStore.swift
  Sources/Store/MinutoStore+Entries.swift
  Sources/Store/MinutoStore+MasterData.swift
  Sources/Store/MinutoStore+DataTransfer.swift
  Sources/Store/MinutoStore+Overview.swift
  Sources/MinutoApp.swift
  Sources/Support/Presentation.swift
  Sources/Views/AppShell.swift
  Sources/Views/HelpView.swift
  Sources/Views/Time/TimeEntryForm.swift
  Sources/Views/Time/EntryListView.swift
  Sources/Views/Time/TimeEntryEditor.swift
  Sources/Views/MasterDataViews.swift
  Sources/Views/OverviewViews.swift
)

swiftc -parse-as-library \
  -module-cache-path build/swift-cache \
  "${SOURCE_FILES[@]}" \
  -o "$APP/Contents/MacOS/Minuto" \
  -framework SwiftUI \
  -framework AppKit

cp Info.plist "$APP/Contents/Info.plist"
cp Minuto.icns "$APP/Contents/Resources/Minuto.icns"
codesign --force --sign - "$APP"

echo "App erstellt: $APP"
