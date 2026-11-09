#!/bin/bash
# 生成构建副本源码：从仓库复制 iina/*.swift 到 $BUILD/src，
# 再把用到 SwiftUI @State 宏的两个文件就地展开为 State<T> + 计算属性。
# 同时把 AssetSymbolsShim.swift 复制到构建目录供编译引用。
# 注意：本脚本只改构建副本 $BUILD/src，绝不改动仓库源码。
set -euo pipefail

BUILD=${IINA_BUILD_DIR:-/tmp/iinabuild}
REPO=${IINA_REPO_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}

mkdir -p "$BUILD/src"
rm -rf "$BUILD/src"/*
cp "$REPO"/iina/*.swift "$BUILD/src/"
cp "$(dirname "$0")/AssetSymbolsShim.swift" "$BUILD/"

python3 - "$BUILD/src/JavascriptDevTool.swift" "$BUILD/src/PluginStorePanel.swift" <<'PY'
import re, sys

# 匹配：@State [private ]var name[: Type][ = init]
# 注意必须带 re.M：这些声明位于文件中间，没有 MULTILINE 时 `^` 只匹配文件开头（曾因此静默展开 0 处）。
state_re = re.compile(
    r'^(?P<indent>[ \t]*)@State\s+(?:private\s+)?var\s+'
    r'(?P<name>[A-Za-z_][A-Za-z0-9_]*)'
    r'(?:\s*:\s*(?P<type>[^=\n]+?))?'
    r'(?:\s*=\s*(?P<init>[^\n]+?))?[ \t]*$',
    re.M
)

def infer_type(name, typ, init):
    if typ:
        return typ.strip()
    if init is None:
        raise SystemExit(f'cannot infer type for @State {name} (no explicit type)')
    init = init.strip()
    if init in ('false', 'true'):
        return 'Bool'
    if init.startswith('"'):
        return 'String'
    if re.fullmatch(r'-?\d+', init):
        return 'Int'
    if re.fullmatch(r'-?\d+\.\d+', init):
        return 'Double'
    raise SystemExit(f'cannot infer type for @State {name} = {init}')

for path in sys.argv[1:]:
    with open(path, encoding='utf-8') as f:
        text = f.read()
    names = []
    def repl(m):
        indent = m.group('indent')
        name = m.group('name')
        typ = infer_type(name, m.group('type'), m.group('init'))
        init = (m.group('init') or '').strip()
        if not init:
            # 无初始值的声明只出现在可选类型上（如 `@State private var errorMessage: String?`）。
            if not typ.rstrip().endswith('?'):
                raise SystemExit(f'@State {name}: {typ} has no initial value')
            init = 'nil'
        names.append(name)
        decl = f"{indent}private var _{name} = State<{typ}>(initialValue: {init})"
        accessor = (
            f"{indent}private var {name}: {typ} {{\n"
            f"{indent}  get {{ _{name}.wrappedValue }}\n"
            f"{indent}  nonmutating set {{ _{name}.wrappedValue = newValue }}\n"
            f"{indent}}}"
        )
        return decl + "\n" + accessor
    text = state_re.sub(repl, text)
    # `$name` binding 投影 -> `_name.projectedValue`
    for name in names:
        text = text.replace(f'${name}', f'_{name}.projectedValue')
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)
    print(f'expanded @State in {path}: {len(names)} decls -> {names}')
PY

echo "SRC READY"
ls "$BUILD/src" | wc -l