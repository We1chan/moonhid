# 0.2.0 发布与安装验收

当前状态：**0.2.0 已发布到 mooncakes.io**。2026-10-02 已在仓库外新建项目，
通过 `moon add We1chan/moonhid` 从 registry 下载并验证实际安装版本，四后端均通过。
原始验收数据及核心文件 SHA-256 见 [安装记录](registry-install-validation.json)。

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

## 发布方式

此版本已由参赛者本人执行登录和发布。后续发布前先审阅源码、公开接口和最近一次 CI，
再在自己的终端执行：

```sh
cd /path/to/moonhid
git switch main
git pull --ff-only
moon login
moon publish
```

按交接要求，账号登录与实际发布由参赛者本人操作；编码代理负责源码和安装验证。
不要将密码、token 或登录验证码粘贴进仓库。

## 实际安装验收

使用独立 `moon new` 项目，模块名为 `installcheck/moonhid-install-check`，
没有本地源码覆盖。`moon add We1chan/moonhid` 输出 `Downloading We1chan/moonhid@0.2.0`，
项目的 `moon.mod` 声明 `We1chan/moonhid@0.2.0`，下载包也声明版本 0.2.0。

测试三项公开 API 行为：

- README 的相对轴示例：`ff` 解码为 `-1L`，Usage 为 Generic Desktop X。
- 带 ID 的非字节对齐 33 位字段：得到 `ff ff ff ff 01`，JSON `schema_version` 为 2。
- 完整 16 位 Usage 区间：数组映射两个端点，并保留 String/Designator 元数据。

| 后端 | 安装包 API 测试 | 可执行示例 stdout |
| --- | --- | --- |
| wasm | 3/3 通过 | `-1` |
| wasm-gc | 3/3 通过 | `-1` |
| js | 3/3 通过 | `-1` |
| native | 3/3 通过 | `-1` |

`moon check --target all --deny-warn` 通过。工具链为 `moon 0.1.20260920`、
`moonc v0.10.14+7d59c7ec9`，环境信息保存在安装记录中。
下载包的 11 个核心源码、接口和模块/包配置文件逐字节匹配
已通过 CI 的 [发布提交 0fcce75](https://github.com/We1chan/moonhid/commit/0fcce7570dd8d17cef95409e4b6765a429448d1c)。

## 复现最小安装验证

在仓库之外新建项目：

```sh
moon new --user installcheck --name moonhid-install-check moonhid-install-check
cd moonhid-install-check
moon add We1chan/moonhid
```

在根包 `moon.pkg` 中加入测试导入：

```text
import {
  "We1chan/moonhid" @moonhid,
} for "test"
```

将 README 的单轴 API 示例保存为 `verify_test.mbt`，然后分别运行：

```sh
moon check --target all --deny-warn
moon test --target wasm
moon test --target wasm-gc
moon test --target js
moon test --target native
```

最小示例断言 `ff` 解码为 `-1L`；以上三项完整安装验收的结果以安装记录为准。
