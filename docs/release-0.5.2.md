# MoonHID 0.5.2

0.5.2 修复跨平台 README 文档链接；核心公开 API、编解码实现和 JSON v2 与 0.5.0 相同。
标准证据包含 10 个标准范围案例、1 个明确区分的宽松扩展与 7 个错误案例。

## 文档交付修复

0.5.1 将模块发布 README 改为根文件后，Mooncakes 同时展示模块根 README 和包内可执行 README。
前者链接正确，后者仍按错误基址解析相对链接。
发布后的线上检查检出 27 个错误相对链接，因而未将该版本的文档修复计作通过。

0.5.2 将源 README 所有跨页链接改为 GitHub 上明确的文件地址；内部章节保留锚点。
无论 GitHub 或 Mooncakes 选择哪份 README，均不再依赖相对链接的展示基址。
本地检查也将这些自有仓库地址映射到源文件并检查锚点，且拒绝重新引入跨页相对地址。

## 安装与验收

```sh
moon add We1chan/moonhid@0.5.2
```

独立安装可使用 [公开 API 验收测试](registry-0.5.0-test.mbt.txt)，四后端各 9 项。
源码中的完整报告案例与线上链接检查：

```sh
moon update
node scripts/sync-readme.mjs --check
node scripts/test-compatibility.mjs js
node scripts/test-compatibility.mjs native
node scripts/check-public-docs.mjs
```

发布结果、真实下载安装、线上链接和离线包校验值以
[本次实际排查记录](review-audit-2026-10-20.md) 为准，不将发布准备当作验收通过。
本版本从 Git 提交导出的文件发布；本机 Git 导出仍采用 CRLF，
包文件与 Git 的 LF 文本按换行归一后比较，不能声称原始字节 SHA 一致。
实际 58 份配置、源码与接口归一后均与发布提交一致，详见 [安装验证记录](registry-0.5.2-validation.json)。

## 交付入口

- [Mooncakes](https://mooncakes.io/docs/We1chan/moonhid)
- [GitHub Release](https://github.com/We1chan/moonhid/releases/tag/v0.5.2)
- [标准兼容目标](hid-compatibility.md)、[完整报告案例](report-cases.md)、[初审回复](hackathon-review-response.md)
- [在线检查器](https://we1chan.github.io/moonhid/)

离线包 `moonhid-inspector-v0.5.2.zip` 解压后运行 `node scripts/serve-offline.mjs`，
或 Windows 双击 `start-inspector.cmd`。需要 Node.js 22+；`BUILD.json` 记录构建提交，
`SHA256SUMS.txt` 校验下载文件。
HID 1.11 §8.4 的普通字段约束与宽松扩展已明确区分，不将离线验证计作设备认证或实机 Output/Feature 收发。
