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
