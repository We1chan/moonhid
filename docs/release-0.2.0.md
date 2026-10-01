# 0.2.0 发布准备

当前状态：源码版本已升为 0.2.0，**尚未发布**。本页不代表 mooncakes 上已有可安装版本。

## 此版本变化

- 零长度 HID 短项按 0 解释，错误维度和 ID 继续拒绝。
- 超宽 Data Variable 字段返回原始字节，Constant 字段保留布局，Data Array 仍限 32 位。
- Report Count 由每报告 65536 位预算约束；大 Usage 范围按区间保存。
- 保留 String/Designator 元数据和 Delimiter 备选 Usage。
- 增加可选 WebHID Input 实时模式与 collections 差异提示（已模拟验证，真实输入待验收）。
- 增加 native/Node JS 文件 CLI，支持 inspect/decode 与 0/1/2 退出码。
- 七份真实描述符全部通过结构断言；hid-tools 对照和 headless Chrome 检查可复现并纳入 CI。
- 增加固定种子的随机/结构化/真实描述符突变测试，验证资源边界和解码性质。

## API / JSON 迁移

`Field.usages` 替换为 `usage_spans: Array[UsageSpan]`，需要逐元素查询时调用
`field_usage(field, index)`。Variable 索引越界重复末项，Array 越界返回 None；
Array 的索引仍为 `value - logical_min`，调用前检查 Logical 范围。
字段与 Collection 新增本地元数据；`DecodedReport` 新增 `opaque_values`。
手工构造这些类型的调用者需补充新数组，通常使用 `[]`。

所有 JSON 导出升级为 [schema v2](json-v2.md)。消费者应检查版本；
字段的 `usage_spans` 与 `usage_count` 替换展开数组，整数 `values` 与原始字节
`opaque_values` 分开保存。原始字节按 LSB 位序打包，末字节未用高位补 0。

## 参赛者本人执行的发布步骤

先审阅源码、公开接口和最近一次 CI。在自己打开的终端执行：

```sh
cd /path/to/moonhid
git switch main
git pull --ff-only
moon login
moon publish
```

按交接要求，账号登录与实际发布由参赛者本人操作；编码代理只准备源码和验证。
不要将密码、token 或登录验证码粘贴进仓库。

## 发布后的安装验收

发布成功后，在仓库之外新建 scratch 项目：

```sh
moon new moonhid-install-check
cd moonhid-install-check
moon add We1chan/moonhid
```

将包的 `moon.pkg` 加入 `"We1chan/moonhid" @hid`，运行 README 的单轴 API 示例，
断言 `ff` 解码为 `-1L`。需要确认安装的模块版本为 0.2.0，四后端运行结果与源码一致。
保存实际命令、工具链版本、安装版本和测试结果后，再将 README 改为「已发布」，
关闭发布 Issue。这里的 `moon add We1chan/moonhid` 是发布后的命令，当前未验证 registry 安装。
