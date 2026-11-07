#!/bin/bash
# ad-hoc 重签 /tmp/iinabuild/IINA-built.app（正确顺序：appex → Sparkle → 主 binary → 外层 app，不用--deep）。
set -euo pipefail

BUILD=${IINA_BUILD_DIR:-/tmp/iinabuild}
APP="$BUILD/IINA-built.app"
ENT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 1. appex（保留沙盒 entitlements）
codesign --force --sign - --entitlements "$ENT_DIR/OpenInIINA.entitlements" \
  "$APP/Contents/PlugIns/OpenInIINA.appex"

# 2. Sparkle.framework（不带 entitlements）
codesign --force --sign - "$APP/Contents/Frameworks/Sparkle.framework"

# 3. 主 binary（带主 app entitlements）
codesign --force --sign - --entitlements "$ENT_DIR/IINA.entitlements" \
  "$APP/Contents/MacOS/IINA"

# 4. 外层 app（不带 --deep，避免覆盖嵌套 bundle 各自的 entitlements）
codesign --force --sign - --entitlements "$ENT_DIR/IINA.entitlements" "$APP"

# 5. 校验
codesign --verify --deep --strict --verbose=2 "$APP"

echo "SIGN DONE"