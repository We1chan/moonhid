# MoonHID 0.6.3

0.6.3 用 MoonBit 1.0.0-rc1 构建和发布，对应十一月赛 `moonc` 不低于 1.0.0-rc1 的要求。
库实现、公开 API、展示 JSON v2 和声明 v1 与 0.6.2 相同。

## 本次变更

- [`toolchain.json`](../toolchain.json) 固定 `moonc v1.0.0-rc1+3c0520448` 和 `moon 0.1.20261126`，CI 四后端和 Windows 验收都安装这一版本。
- 源码的类型派生改用前置 `#derive(...)`；`pkg.generated.mbti` 的差异只来自 rc1 的接口文件格式（`Json` 显示为 `@json.Json`）。
- Windows 上 rc1 的 native 运行时只支持 MSVC。验收脚本按 `moon` 的查找顺序检测 `MOON_CC`、`PATH` 中的 `cl.exe` 和 `vswhere`，
  未检测到时测试 wasm、wasm-gc、js，并把四个 native 相关步骤标为 SKIP、说明原因，不再报告四后端测试失败。
- [Windows 工作流](../.github/workflows/windows.yml) 新增 MSVC 完整验收，要求包括 native 在内的所有步骤 PASS。
- README、安装说明和验收入口更新到 0.6.3。0.6.2 的 Mooncakes 页面仍写着旧的 `moonc` 0.10.16 门槛，复核本次要求应使用 0.6.3。

## 安装与复现

```sh
moon add We1chan/moonhid@0.6.3
```

```sh
git clone --branch v0.6.3 https://github.com/We1chan/moonhid.git
cd moonhid
moon update
node scripts/acceptance.mjs
```

工具链与可选依赖见 [验收说明](acceptance.md)。Windows 没有 MSVC 时，完整模式会跳过 native 步骤；只复核 wasm/js 可运行 `node scripts/acceptance.mjs --quick`。

## 发布后复核

```sh
node scripts/verify-registry.mjs
node scripts/check-public-docs.mjs --urls docs/acceptance-urls.txt
```

注册表验收在仓库外新建项目，实际安装 0.6.3 并运行 [14 项公开 API 测试](registry-0.6.3-test.mbt.txt)，
在四后端检查功能，并将源码、README、LICENSE、NOTICE 和第三方声明与发布标签逐文件比较。
机器记录默认写入 `docs/registry-0.6.3-validation.json`。

正式交付入口为 [GitHub v0.6.3](https://github.com/We1chan/moonhid/releases/tag/v0.6.3)、
[Mooncakes 0.6.3](https://mooncakes.io/docs/We1chan/moonhid@0.6.3) 和 [在线检查器](https://we1chan.github.io/moonhid/)。
Release 附件提供预构建离线检查器、`SHA256SUMS.txt` 和发布验收机器记录。
