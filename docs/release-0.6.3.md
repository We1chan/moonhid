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

## 2026-11-27 实际交付验收

发布提交为 `a5a3252778434ed88c53c44d078c10b1ae098368`，Mooncakes 返回 `200 OK`，
[GitHub v0.6.3](https://github.com/We1chan/moonhid/releases/tag/v0.6.3) 已公开。
Mooncakes 包用 `moonc v1.0.0-rc1+3c0520448` 从 `core.autocrlf=false` 的标签克隆发布，`moon publish` 在打包前后各运行一次 `moon check`。

| 检查 | 实际结果 |
| --- | --- |
| 发布前 PR 与发布提交 CI | [PR #66](https://github.com/We1chan/moonhid/pull/66) 七项检查通过；[发布提交 CI](https://github.com/We1chan/moonhid/actions/runs/46000806939) 的 wasm、wasm-gc、js、native 和最新工具链任务各 123/123 |
| Windows MSVC 完整验收 | [Windows 验收](https://github.com/We1chan/moonhid/actions/runs/46000806938)：GitHub Windows 环境，CRLF 检出，`dirty: false`；PASS 24 / FAIL 0 / SKIP 0，native 测试、native CLI、native 标准案例和 hid-tools 编码对照均实际执行 |
| 默认 Windows Git 全新克隆完整验收 | Windows x64，`core.autocrlf=true`，未安装 MSVC，`dirty: false`；PASS 21 / FAIL 0 / SKIP 4，wasm、wasm-gc、js 各 123/123，四个 SKIP 均为 native 相关步骤 |
| 注册表独立安装 | Linux x64、rc1，仓库外新项目实际下载 0.6.3，无本地覆盖；四后端各 14/14；73 份源码、配置和许可文件与标签原始字节一致，见 [机器记录](registry-0.6.3-validation.json) |
| Mooncakes 页面 | 0.6.3 文档构建成功，README 显示 `moonc` 1.0.0-rc1 门槛，不再出现 0.10.16 |
| 公开交付链接 | GitHub/Mooncakes 0.6.3、全部 9 个 Release 正文与额外入口，共 346 个来源、139 个不同 URL，0 失败、无缺失的注册表链接；本机与 [手动触发的公开文档 CI](https://github.com/We1chan/moonhid/actions/runs/46006478264) 结果相同。发布时自动触发的运行因 github.com 返回 HTTP 503 而失败 |
| 离线包 | 从标签构建，19 个文件，包含 `LICENSE`、`NOTICE`、`THIRD_PARTY_NOTICES.md`；从 GitHub 重新下载后 SHA-256 与 `SHA256SUMS.txt` 一致，离线服务检查通过 |
| 线上检查器 | [Pages 部署](https://github.com/We1chan/moonhid/actions/runs/46001043129) 成功；线上 index/app/core 为 HTTP 200，与离线包对应文件逐字节相同 |

离线 ZIP SHA-256：

```text
a20d10aefafb95fb28b9152089e764d84fd2a677b2fc3bfb467c4ebd73975b70
```
