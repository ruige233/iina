# 无 Xcode 手工构建 IINA（CommandLineTools 构建）

本目录用于在**只装了 CommandLineTools（没有 Xcode）**的 macOS 上，把修改后的 IINA 源码编译链接成可运行的 `IINA.app`，安装到 `/Applications` 直接使用。

## 为什么能不用 Xcode 构建

IINA 的官方构建需要 Xcode（`xcodebuild` + `actool` + `ibtool`）。但本仓库的这次改动**只涉及**：

- Swift 源码：`iina/AppDelegate.swift`、`iina/InitialWindowController.swift`
- 本地化字符串：`iina/{Base,en,zh-Hans}.lproj/Localizable.strings`

**没有改** xib / storyboard / Assets.xcassets / 工程文件。所以可以避开 `actool` 和 `ibtool`，用 CommandLineTools 自带的 `swiftc` + `clang` 手工编译，再复用官方已安装版 `IINA.app` 里的 dylib、nib、Assets.car 等资源组装。

## 两个必须绕过的坑（已在本目录脚本中处理）

1. **asset 符号缺失**：工程开启了 `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`，Xcode 会由 `actool` 从 Assets.xcassets 生成 `NSColor.*` / `NSImage.*` 静态符号。CLT 无 actool，故用 `AssetSymbolsShim.swift` 手工补齐全部符号（运行时按原目录名从 `Assets.car` 查找）。此文件已保存在本目录，无需改动。

2. **SwiftUI `@State` 宏插件缺失**：`@State` 是宏（`SwiftUIMacros.StateMacro`），CLT 没有 `libSwiftUIMacros.dylib`。全工程只有 2 个文件 12 处用到 `@State`（`iina/JavascriptDevTool.swift`、`iina/PluginStorePanel.swift`），且这些文件**都不是本次改动的文件**。`prepare_src.sh` 会把这两个文件复制到构建目录，就地展开 `@State` 为等价的 `State<T>` + 计算属性（不改仓库源码）。

## 前置要求

- 已安装 CommandLineTools：`xcode-select -p` 指向 `/Library/Developer/CommandLineTools`。
- 已安装官方版 IINA 到 `/Applications/IINA.app`（作为资源/dylib 来源，脚本会先备份成 `IINA.app.original`）。
- 本机 CPU 为 arm64（脚本硬编码 `arm64-apple-macos12`；x86_64 需自行改 target）。
- 磁盘 `/tmp` 可用约 500MB（三方依赖 clone + 编译产物）。

## 一键构建

```bash
cd /Users/<you>/path/to/iina/other/clt-build
./build_all.sh
```

脚本会依次完成：下载并编译三方依赖 → 生成 asset shim → 展开 @State → 编译 Swift/ObjC → 链接 → 组装 `.app` → ad-hoc 签名 → 校验 → 备份官方版并安装到 `/Applications`。

安装阶段会写 `/Applications`（沙箱外），如果脚本提示权限不足，用 `sudo ./install.sh` 或手动执行 `install.sh` 内容。

## 脚本清单

| 文件 | 作用 |
|------|------|
| `build_all.sh` | 总入口，按顺序调用下面全部脚本 |
| `prepare_deps.sh` | clone Just/PromiseKit/GRMustache + 下载 Sparkle，编译成静态库和 swiftmodule |
| `prepare_src.sh` | 生成 AssetSymbolsShim.swift + 展开 @State 到构建副本 `/tmp/iinabuild/src` |
| `build_swift.sh` | swiftc 编译 218 个 Swift 文件 + 3 个 ObjC 为对象文件 |
| `link.sh` | 链接成 `/tmp/iinabuild/IINA-bin`（arm64） |
| `assemble.sh` | 复制官方 app → 替换主程序/Sparkle → 追加 .strings 键 → 组装 `/tmp/iinabuild/IINA-built.app` |
| `sign.sh` | 按正确顺序 ad-hoc 重签（appex → Sparkle → 主 binary → 外层 app） |
| `install.sh` | 备份官方版到 `/Applications/IINA.app.original` 并安装 |
| `AssetSymbolsShim.swift` | actool 生成符号的替身（跟随上游 Assets 增删需同步维护） |

## 还原官方版

```bash
rm -rf /Applications/IINA.app
mv /Applications/IINA.app.original /Applications/IINA.app
```

## 注意事项

- 改版是 **ad-hoc 签名**（非 Apple 开发者证书），本机可正常用，但 **Sparkle 自动更新会失效**（官方更新会覆盖你的改动）。
- 构建产物在 `/tmp/iinabuild/`，重启后会清空；脚本可随时重跑。
- 若上游源码新增了 `@State`（在其它文件）或新增了 Assets 资源，需要同步更新 `prepare_src.sh` 和 `AssetSymbolsShim.swift`。