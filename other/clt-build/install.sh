#!/bin/bash
# 安装改版 app 到 /Applications/IINA.app（先备份官方版为 IINA.app.original）。
# 需要写 /Applications：在 DSH 沙箱内可能要 sudo 或在有权限的环境执行。
set -euo pipefail

BUILD=${IINA_BUILD_DIR:-/tmp/iinabuild}
SRC="$BUILD/IINA-built.app"
DST=/Applications/IINA.app
BAK=/Applications/IINA.app.original

[ -d "$SRC" ] || { echo "先运行 build_all.sh 生成 $SRC" >&2; exit 1; }

if [ ! -e "$BAK" ]; then
  mv "$DST" "$BAK"
  echo "已备份官方版到 $BAK"
else
  echo "备份已存在：$BAK，跳过"
fi

ditto "$SRC" "$DST"
echo "已安装到 $DST"

codesign --verify --deep --strict "$DST" && echo "签名校验通过"
plutil -p "$DST/Contents/Info.plist" | grep -E "CFBundleShortVersionString|CFBundleVersion"

echo "INSTALL DONE"