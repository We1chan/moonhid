# MoonHID 0.6.1

0.6.1 是文档与验收补丁，库代码、公开 API、展示 JSON v2 和声明 v1 与 [0.6.0](release-0.6.0.md) 相同。

## 本次变更

- [AI 协作说明](ai-collaboration.md) 改为记录参赛者与 AI 编程工具（Codex、Claude Code）的实际分工；
  README、[验收说明](acceptance.md) 与 0.6.0 发布记录同步更新。
- 修复 `scripts/test-cli.mjs` 在 Git for Windows 默认 `core.autocrlf=true` 检出下的失败：
  原先按 `\n` 切分 Xbox 帧文件会残留 `\r`，导致 `node scripts/acceptance.mjs` 退出 1。
- 新增 [Windows 工作流](https://github.com/We1chan/moonhid/actions/workflows/windows.yml)，以 CRLF 检出后运行一键快速验收；
  `setup-moon` 支持在 Windows 安装固定版本工具链。
- 更新声明与网页编辑文档中“尚未发布”“需源码构建”的过时说明。

## 安装与复现

```sh
moon add We1chan/moonhid@0.6.1
```

```sh
git clone --branch v0.6.1 https://github.com/We1chan/moonhid.git
cd moonhid
moon update
node scripts/acceptance.mjs
```

Windows 使用默认 Git 设置克隆即可，无需修改换行配置。完整条件见 [验收说明](acceptance.md)。

发布后执行：

```sh
node scripts/verify-registry.mjs
node scripts/check-public-docs.mjs --urls docs/acceptance-urls.txt
```

注册表验收使用 [14 项公开 API 测试](registry-0.6.1-test.mbt.txt)，内容与 0.6.0 相同，
结果写入 `docs/registry-0.6.1-validation.json`。

## 2026-10-24 实际交付验收

发布提交为 `f0420829bc00b1f40b311978d41b67ff1f659c0f`，Mooncakes 返回 `200 OK`，
[GitHub v0.6.1](https://github.com/We1chan/moonhid/releases/tag/v0.6.1) 已公开。
Mooncakes 包从 `core.autocrlf=false` 的标签克隆发布，安装包文件与 Git 对象原始字节一致。

| 检查 | 实际结果 |
| --- | --- |
| 发布前 PR 与发布提交 CI | [PR #59](https://github.com/We1chan/moonhid/pull/59) 与发布提交的 CI 五项、Windows 验收均通过；[发布提交 CI](https://github.com/We1chan/moonhid/actions/runs/40102524461)、[Windows 验收](https://github.com/We1chan/moonhid/actions/runs/40102524479) |
| 默认 Windows Git 全新克隆完整验收 | Windows x64，Git 默认 `core.autocrlf=true`（CRLF 检出），`dirty: false`；PASS 23 / FAIL 0 / SKIP 0，四后端各 123/123 |
| 注册表独立安装 | 仓库外新项目实际下载 0.6.1，无本地覆盖；四后端各 14/14；71 份源码/配置与标签原始字节一致，见 [机器记录](registry-0.6.1-validation.json) |
| 公开交付链接 | GitHub/Mooncakes 0.6.1、全部 7 个 Release 正文与额外入口，共 324 个来源、115 个不同 URL；0 失败；[发布触发的公开文档 CI](https://github.com/We1chan/moonhid/actions/runs/40102708448) 通过 |
| Mooncakes 页面 | 0.6.1 README 为更新后的 AI 协作表述 |
| 离线包 | 从 GitHub 重新下载，SHA-256 与 SHA256SUMS.txt 一致；17 个文件，打包后离线服务检查通过 |
| 线上检查器 | [Pages 部署](https://github.com/We1chan/moonhid/actions/runs/40102637598) 成功；线上 index/app/core 为 HTTP 200，与离线包对应文件逐字节相同 |

离线 ZIP SHA-256：

```text
b9080de1706ab7e653d442d265669b53e6cf8b979b21950732ee1bf4626c41cd
```
