#!/bin/bash
# 下载并编译三方依赖（Just / PromiseKit / GRMustache+GRMustacheKeyAccess / Sparkle），
# 产出静态库和 swiftmodule 到 /tmp/iinabuild/out。
set -euo pipefail

BUILD=${IINA_BUILD_DIR:-/tmp/iinabuild}
SDK=${IINA_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk}
TARGET=${IINA_TARGET:-arm64-apple-macos12}
OUT="$BUILD/out"
MOD="$OUT/modules/GRMustacheKeyAccess"

mkdir -p "$BUILD" "$OUT" "$MOD"
cd "$BUILD"

# ---- 1. 下载并解压 Sparkle（官方 SwiftPM 分发，含 Headers/Modules） ----
SPARKLE_VERSION=2.10.1
if [ ! -d "$BUILD/sparkle/Sparkle.xcframework" ]; then
  curl -L -o "$BUILD/sparkle.zip" \
    "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-for-Swift-Package-Manager.zip"
  mkdir -p "$BUILD/sparkle"
  ditto -x -k "$BUILD/sparkle.zip" "$BUILD/sparkle"
fi

# ---- 2. clone 三方源码（浅克隆） ----
[ -d "$BUILD/Just" ]    || git clone --depth 1 https://github.com/dduan/Just.git "$BUILD/Just"
[ -d "$BUILD/PromiseKit" ] || git clone --depth 1 https://github.com/mxcl/PromiseKit.git "$BUILD/PromiseKit"
[ -d "$BUILD/GRMustache.swift" ] || git clone --depth 1 https://github.com/groue/GRMustache.swift.git "$BUILD/GRMustache.swift"

# ---- 3. Just ----
swiftc -emit-library -static -emit-module -module-name Just \
  -target "$TARGET" -sdk "$SDK" -swift-version 5 \
  -module-cache-path "$BUILD/mcache" \
  -emit-module-path "$OUT/Just.swiftmodule" \
  -o "$OUT/libJust.a" \
  "$BUILD/Just/Sources/Just/Just.swift"

# ---- 4. PromiseKit（排除 AnyPromise.swift / Deprecations.swift，需 -D SWIFT_PACKAGE） ----
# macOS 自带 bash 3.2 没有 mapfile，用 read 循环代替。
PK_SRCS=()
while IFS= read -r f; do PK_SRCS+=("$f"); done < <(find "$BUILD/PromiseKit/Sources" -name '*.swift' \
  ! -name 'AnyPromise.swift' ! -name 'Deprecations.swift' | sort)
swiftc -emit-library -static -emit-module -module-name PromiseKit \
  -target "$TARGET" -sdk "$SDK" -swift-version 5 -D SWIFT_PACKAGE \
  -module-cache-path "$BUILD/mcache" \
  -emit-module-path "$OUT/PromiseKit.swiftmodule" \
  -o "$OUT/libPromiseKit.a" \
  "${PK_SRCS[@]}"

# ---- 5. GRMustacheKeyAccess（ObjC）+ 手写 modulemap ----
cp "$BUILD/GRMustache.swift/ObjC/GRMustacheKeyAccess.h" "$MOD/"
cp "$BUILD/GRMustache.swift/ObjC/Mustache.h" "$MOD/"
cat > "$MOD/module.modulemap" <<'MM'
module GRMustacheKeyAccess {
  header "GRMustacheKeyAccess.h"
  export *
}
MM
clang -c -target "$TARGET" -isysroot "$SDK" -fobjc-arc \
  -fmodules -fmodules-cache-path="$BUILD/clangmcache" \
  -I "$BUILD/GRMustache.swift/ObjC" \
  -o "$OUT/GRMustacheKeyAccess.o" \
  "$BUILD/GRMustache.swift/ObjC/GRMustacheKeyAccess.m"
ar rcs "$OUT/libGRMustacheKeyAccess.a" "$OUT/GRMustacheKeyAccess.o"

# ---- 6. Mustache（定义 OBJC，走 GRMustacheKeyAccess 分支） ----
MS_SRCS=()
while IFS= read -r f; do MS_SRCS+=("$f"); done < <(find "$BUILD/GRMustache.swift/Sources" -name '*.swift' | sort)
swiftc -emit-library -static -emit-module -module-name Mustache \
  -target "$TARGET" -sdk "$SDK" -swift-version 5 -D OBJC \
  -module-cache-path "$BUILD/mcache" \
  -Xcc -fmodules -Xcc -fmodules-cache-path="$BUILD/clangmcache" \
  -Xcc -I -Xcc "$OUT/modules" \
  -emit-module-path "$OUT/Mustache.swiftmodule" \
  -o "$OUT/libMustache.a" \
  "${MS_SRCS[@]}"

echo "DEPS DONE"
ls -la "$OUT"