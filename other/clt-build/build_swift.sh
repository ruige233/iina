#!/bin/bash
# swiftc 编译 218 个 Swift 文件 + 3 个 ObjC 文件为对象文件。
# 产出 /tmp/iinabuild/obj_swift/*.o + IINA-Swift.h，以及 /tmp/iinabuild/obj/*.o
set -euo pipefail

BUILD=${IINA_BUILD_DIR:-/tmp/iinabuild}
SDK=${IINA_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk}
TARGET=${IINA_TARGET:-arm64-apple-macos12}
REPO=${IINA_REPO_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}
SPARKLE_FW="$BUILD/sparkle/Sparkle.xcframework/macos-arm64_x86_64"

mkdir -p "$BUILD/obj_swift" "$BUILD/obj"
rm -rf "$BUILD/obj_swift" "$BUILD/obj"
mkdir -p "$BUILD/obj_swift" "$BUILD/obj"

# ---- 1. Swift -> 对象文件 + 生成 ObjC 桥接头 IINA-Swift.h ----
( cd "$BUILD/obj_swift" && swiftc -emit-object -parse-as-library \
    -emit-objc-header-path "$BUILD/obj_swift/IINA-Swift.h" \
    -module-name IINA \
    -target "$TARGET" -sdk "$SDK" -swift-version 5 \
    -module-cache-path "$BUILD/mcache" \
    -import-objc-header "$REPO/iina/iina-Bridging-Header.h" \
    -Xcc -I -Xcc "$REPO/deps/include" -Xcc -I -Xcc "$REPO/iina" \
    -Xcc -DMPV_ENABLE_DEPRECATED=0 -Xcc -DGL_SILENCE_DEPRECATION=1 \
    -Xcc -fmodules -Xcc -fmodules-cache-path="$BUILD/clangmcache" \
    -Xcc -I -Xcc "$BUILD/out/modules" \
    -D MACOS_13_AVAILABLE -D MACOS_27_AVAILABLE \
    -I "$BUILD/out" \
    -F "$SPARKLE_FW" \
    -O \
    "$BUILD/src/"*.swift "$BUILD/AssetSymbolsShim.swift" )

# ---- 2. ObjC -> 对象文件（FFmpegController.m 依赖上面生成的 IINA-Swift.h） ----
for m in ObjcUtils FixedFontManager; do
  clang -c -target "$TARGET" -isysroot "$SDK" -fobjc-arc \
    -fmodules -fmodules-cache-path="$BUILD/clangmcache" \
    -I "$REPO/deps/include" -I "$REPO/iina" \
    -DGL_SILENCE_DEPRECATION=1 \
    -o "$BUILD/obj/$m.o" "$REPO/iina/$m.m"
done
clang -c -target "$TARGET" -isysroot "$SDK" -fobjc-arc \
  -fmodules -fmodules-cache-path="$BUILD/clangmcache" \
  -I "$REPO/deps/include" -I "$REPO/iina" -I "$BUILD/obj_swift" \
  -F "$SPARKLE_FW" -fobjc-weak -ObjC \
  -DGL_SILENCE_DEPRECATION=1 \
  -o "$BUILD/obj/FFmpegController.o" "$REPO/iina/FFmpegController.m"

echo "BUILD SWIFT+OBJC DONE"
echo "swift objects: $(ls "$BUILD/obj_swift"/*.o | wc -l)"
echo "objc objects:  $(ls "$BUILD/obj"/*.o | wc -l)"