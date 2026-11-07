#!/bin/bash
# 组装 /tmp/iinabuild/IINA-built.app：
# 复制官方已安装 app → 移除签名 → 替换主程序 + Sparkle → 追加本地化键（正确处理 BOM）。
set -euo pipefail

BUILD=${IINA_BUILD_DIR:-/tmp/iinabuild}
SRC=${IINA_SRC_APP:-/Applications/IINA.app}
DST="$BUILD/IINA-built.app"
SPARKLE_FW="$BUILD/sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"

rm -rf "$DST"
cp -R "$SRC" "$DST"

# 1. 移除签名（深度），以便干净重签
codesign --remove-signature "$DST" 2>/dev/null || true
codesign --remove-signature "$DST/Contents/PlugIns/OpenInIINA.appex" 2>/dev/null || true
rm -rf "$DST/_CodeSignature"
rm -rf "$DST/Contents/PlugIns/OpenInIINA.appex/Contents/_CodeSignature"

# 2. 替换主程序
cp "$BUILD/IINA-bin" "$DST/Contents/MacOS/IINA"
chmod 755 "$DST/Contents/MacOS/IINA"

# 3. 替换 Sparkle framework
rm -rf "$DST/Contents/Frameworks/Sparkle.framework"
cp -R "$SPARKLE_FW" "$DST/Contents/Frameworks/Sparkle.framework"

# 4. 追加本地化键。关键：从官方 .strings 单 BOM 文件 decode，追加后 encode 回单 BOM。
#    （之前用 iconv + printf '\xff\xfe' 叠加导致双 BOM 损坏，这里用 python 的 utf-16 自动处理 BOM。）
python3 - "$DST" <<'PY'
import sys, os
dst = sys.argv[1]
base_keys = [
    '// Added by IINA history modification',
    '"initial.recent.disabled" = "Playback history is turned off";',
    '"initial.recent.empty" = "No recent items";',
]
zh_keys = [
    '// Added by IINA history modification',
    '"initial.recent.disabled" = "播放历史记录已关闭";',
    '"initial.recent.empty" = "没有最近播放的项目";',
]
for lp, keys in (('Base', base_keys), ('en', base_keys), ('zh-Hans', zh_keys)):
    p = os.path.join(dst, 'Contents/Resources', f'{lp}.lproj', 'Localizable.strings')
    data = open(p, 'rb').read()
    body = data.decode('utf-16')  # 自动识别并去掉 BOM
    if not body.endswith('\n'):
        body += '\n'
    body += '\n'.join(keys) + '\n'
    open(p, 'wb').write(body.encode('utf-16'))  # 单 BOM
    print(f'strings updated: {lp}')
PY

echo "ASSEMBLY DONE -> $DST"