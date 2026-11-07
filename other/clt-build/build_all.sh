#!/bin/bash
# IINA 无 Xcode 手工构建总入口。按顺序执行：
#   prepare_deps -> prepare_src -> build_swift -> link -> assemble -> sign -> install
set -euo pipefail

cd "$(dirname "$0")"
export IINA_REPO_DIR="${IINA_REPO_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
export IINA_BUILD_DIR="${IINA_BUILD_DIR:-/tmp/iinabuild}"

echo "== [1/7] prepare_deps =="
./prepare_deps.sh

echo "== [2/7] prepare_src =="
./prepare_src.sh

echo "== [3/7] build_swift =="
./build_swift.sh

echo "== [4/7] link =="
./link.sh

echo "== [5/7] assemble =="
./assemble.sh

echo "== [6/7] sign =="
./sign.sh

echo "== [7/7] install =="
./install.sh

echo "ALL DONE. 启动验证：open /Applications/IINA.app"