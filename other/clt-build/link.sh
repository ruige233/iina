#!/bin/bash
# 链接成 arm64 可执行文件 /tmp/iinabuild/IINA-bin。
# dylib 全部来自已安装官方版 /Applications/IINA.app/Contents/Frameworks（install name 均为 @rpath/lib*.dylib）。
set -euo pipefail

BUILD=${IINA_BUILD_DIR:-/tmp/iinabuild}
SDK=${IINA_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk}
TARGET=${IINA_TARGET:-arm64-apple-macos12}
FRW=/Applications/IINA.app/Contents/Frameworks
SPARKLE_FW="$BUILD/sparkle/Sparkle.xcframework/macos-arm64_x86_64"
OUT="$BUILD/IINA-bin"

OBJS=$(ls "$BUILD"/obj_swift/*.o "$BUILD"/obj/*.o)
STATIC="$BUILD/out/libJust.a $BUILD/out/libPromiseKit.a $BUILD/out/libMustache.a $BUILD/out/libGRMustacheKeyAccess.a"

# 从官方 app 的 Frameworks 里提取所有 lib*.dylib，转成 -l 标志（排除 swift_Concurrency）
DLIBS=$(cd "$FRW" && for f in lib*.dylib; do
  b="${f#lib}"; b="${b%.dylib}"
  [ "$b" = "swift_Concurrency" ] && continue
  echo "-l$b"
done | tr '\n' ' ')

SYSFW="-framework Accelerate -framework AppKit -framework Carbon -framework ColorSync -framework Combine -framework CoreDisplay -framework CoreFoundation -framework CoreGraphics -framework CoreServices -framework CoreVideo -framework CryptoKit -framework Foundation -framework IOKit -framework ImageIO -framework JavaScriptCore -framework MediaPlayer -framework OpenGL -framework QuartzCore -framework QuickLookThumbnailing -framework SafariServices -framework Security -framework SwiftUI -framework Symbols -framework VideoToolbox -framework VisionKit -framework WebKit"

cd "$BUILD"
swiftc \
  $OBJS \
  $STATIC \
  -L "$FRW" \
  $DLIBS \
  -F "$SPARKLE_FW" -framework Sparkle \
  -F /System/Library/Frameworks -F /System/Library/PrivateFrameworks -framework PIP \
  $SYSFW \
  -target "$TARGET" -sdk "$SDK" -swift-version 5 \
  -Xlinker -rpath -Xlinker '@executable_path/../Frameworks' \
  -Xlinker -rpath -Xlinker '/usr/lib/swift' \
  -o "$OUT"

echo "LINK DONE -> $OUT"
file "$OUT"