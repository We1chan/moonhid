# MoonHID 0.5.1

**公开文档验收未通过，请使用 [0.5.2](release-0.5.2.md)。**
0.5.1 安装测试通过，但 Mooncakes 仍优先展示包内可执行 README，
发布后检查检出 27 个相对路径断链。修改模块 readme 配置未达到预期效果。
以下保留该版本的发布准备内容；当前有效修复采用源 README 的明确跨页地址。

0.5.1 是文档与验收补丁，核心公开 API 和编解码行为与 0.5.0 相同，JSON schema 仍为 v2。
本页随发布准备提交；发布完成后的注册表、公开链接与离线包复核结果记录在
[2026-10-20 排查记录](review-audit-2026-10-20.md)。

## 修正内容

- 根 README 从可执行 README 生成，修正 GitHub 首页符号链接的路径解析问题。
- `moon.mod` 改用生成的根 `README.md`；修正 Mooncakes 按模块根解析 README 时产生的 25 个文档/接口断链。
- 标准兼容说明逐项对应 HID 1.11 §6.2.2、§8.1–8.4；13 位普通 Feature 纳入标准案例，
  33 位 Raw Feature 独立标为宽松扩展，不计作标准兼容证据。
- 案例脚本独立核对固定 wire、全部解码值及元数据，并检查标准范围内普通字段的四字节跨度约束。
- 本地文档检查覆盖发布入口、README 同步、文件和锚点；线上检查消费 GitHub 与 Mooncakes 实际生成的链接。

## 安装与复核

```sh
moon add We1chan/moonhid@0.5.1
```

独立安装项目可沿用 [0.5.0 安装验收测试](registry-0.5.0-test.mbt.txt)：
在新项目中导入 `We1chan/moonhid` 与 `We1chan/moonhid/examples` 作为测试依赖，
把该文件保存为 `verify_test.mbt`，执行 `moon check --target all --deny-warn` 与
`moon test verify_test.mbt --target all`。这些测试验证相同的 9 项公开能力。

从包含 0.5.1 修订的仓库根目录运行：

```sh
moon update
node scripts/sync-readme.mjs --check
node scripts/test-compatibility.mjs js
node scripts/test-compatibility.mjs native
node scripts/check-public-docs.mjs
```

案例脚本区分 10 个标准范围案例、1 个宽松扩展和 7 个错误案例。
最后一条需要网络和已发布的版本页面，检查实际公开入口，而非仅推算 URL。

## 交付入口与版本边界

- [Mooncakes 模块](https://mooncakes.io/docs/We1chan/moonhid)
- [0.5.1 GitHub Release](https://github.com/We1chan/moonhid/releases/tag/v0.5.1)
- [完整报告案例](report-cases.md)、[标准兼容目标](hid-compatibility.md)、[初审回复](hackathon-review-response.md)
- [在线检查器](https://we1chan.github.io/moonhid/)

离线包 `moonhid-inspector-v0.5.1.zip` 解压后运行 `node scripts/serve-offline.mjs`，
或在 Windows 双击 `start-inspector.cmd`。需要 Node.js 22+；`BUILD.json` 记录构建提交，
`SHA256SUMS.txt` 提供校验值。

已发布的 0.5.0 保留原始包和历史记录，其 Mooncakes README 不会随 main 修改而更新。
复审请使用 0.5.1 或当前仓库的证据入口。离线案例不作为 Output/Feature 实机收发或完整 HID 认证证明。
