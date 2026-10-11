#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
mkdir -p build/test-cache
swiftc \
  -module-cache-path build/test-cache \
  Sources/Models.swift \
  Sources/MinutoDomain.swift \
  Sources/MinutoPersistence.swift \
  Tests/MinutoRepositoryTests.swift \
  -o build/MinutoRepositoryTests
build/MinutoRepositoryTests
