# MoonHID 0.3.0

2026-10-07 已发布到 Mooncakes，在线检查器与 GitHub Release 均可用。
[PR #28](https://github.com/We1chan/moonhid/pull/28) 通过五项 CI 后以 merge 合并，
发布提交为 `8148a323014bc8a47a906ad576d0093b5f516d13`。
[main CI](https://github.com/We1chan/moonhid/actions/runs/37597349559) 与
[Pages 部署](https://github.com/We1chan/moonhid/actions/runs/37597491391) 均成功。

本版本增加描述符 lint 核心、JSON v2 `lints`、CLI `lint`、网页中文提示和 item 定位。
公开新增 API 为 `Lint`、`LintLevel`、`lint_descriptor` 和 `lint_to_json`，
其余 v2 字段语义不变；旧 v2 文档缺少 lints 时按空数组处理。

网页提供 Null 状态教学案例和手柄实际 Input 采集入口。
采集页生成的描述符来自浏览器可见字段重建，不是设备原始 USB/BLE 描述符，
不验证原编码、嵌套集合、物理单位或本地元数据。元数据不完整时必须明确选择原始位值模式，
不进行原始 Logical、Array 或 Null 语义验证。
[Xbox 蓝牙实测](xbox-bluetooth.md) 收录 42 条实际 Input，以及 A 状态、轴两端和回中的回归。

交付入口：

- [在线检查器](https://we1chan.github.io/moonhid/)
- [GitHub Release 与离线包](https://github.com/We1chan/moonhid/releases/tag/v0.3.0)
- Mooncakes：`moon add We1chan/moonhid@0.3.0`

发布前运行四后端检查、构建与测试，检查公开接口和格式，并运行网页、CLI、
固件示例、外部 hid-tools 及 headless Chrome 验证。PR 合并后以 main 的成功 CI 为发布依据。
版本内容在本文件中记录；实际发布和安装结果以对应 Release、注册表条目及验证记录为准。

稳定 CI 固定 MoonBit `0.10.14+7d59c7ec9`，另一个 job 检查最新工具链。
`Publish inspector` 只在本仓库 main 的 push CI 成功后部署对应提交，也支持手动部署 main。
离线包包含编译好的解析器，只需 Node.js 22+ 运行本地服务，不需要 MoonBit 或 Python。

## 独立安装验收

仓库外新建 `installcheck/moonhid-030`，执行 `moon add We1chan/moonhid@0.3.0`，
确认下载版本为 0.3.0，没有本地路径覆盖。四后端各 3/3 测试通过，
覆盖新增 lint / JSON 公开 API、修正后的 Null 判定，以及 Xbox 实测轴端点。
12 份核心源码、接口及配置与发布工作树逐字节匹配，换行归一化后也与发布提交匹配。
[完整记录](registry-0.3.0-validation.json) 包含文件 SHA-256、版本、CI 和离线 ZIP 校验值。

复现：

```sh
moon new --user installcheck --name moonhid-030 moonhid-030
cd moonhid-030
moon add We1chan/moonhid@0.3.0
```

在 `moon.pkg` 增加 `"We1chan/moonhid" @moonhid` 的 `for "test"` 导入，
将 [验收测试源码](registry-0.3.0-test.mbt.txt) 保存为 `verify_test.mbt`，执行
`moon check --target all --deny-warn` 和 `moon test --target all`。
