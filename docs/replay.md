# 批量报告帧重放

`replay` 在 native 与 Node.js CLI 中复用同一份 MoonBit 解码与 Usage 访问逻辑。
它读取离线文件，不连接设备，也不等待或模拟采集时间间隔。

```sh
moon run src/cmd/moonhid --target js -- replay --kind input examples/device-cases/xbox-bluetooth-descriptor.hex examples/device-cases/xbox-bluetooth-frames.txt --expect examples/device-cases/xbox-bluetooth-expected.jsonl
moon run src/cmd/moonhid --target native -- replay --kind input examples/firmware-ci/descriptor.hex examples/firmware-ci/frames.txt --expect examples/firmware-ci/expected.jsonl
```

## 输入和 JSON Lines 输出

```text
moonhid replay --kind input|output|feature <descriptor.hex> <frames.txt> [--expect <expected.jsonl>]
```

帧文件采用 UTF-8 无 BOM，每个非空行是一帧完整 wire hex，包括描述符要求的 Report ID。
允许 CRLF、空行、整行或行尾 `#` 注释；注释前的内容交给 `parse_hex`。
一帧失败后继续处理后面的帧。空文件或只有注释时输出为空、退出 0。

stdout 每个数据行输出一个 JSON 对象，以 LF/CRLF 分隔：

- 成功：`line`（原帧文件从 1 开始的物理行号）、`ok: true`、`report_id`、
  规范化的 `wire_hex` 和 `decoded`。`decoded` 与 [JSON v2](json-v2.md) 的解码组件一致。
- 失败：`line`、`ok: false` 和 `diagnostic: {code, offset, message}`。
  保留原始诊断码和偏移；hex 偏移相对于该行注释前的文本，报告诊断偏移遵循核心接口。
- 指定期望文件且成功解码时，额外输出 `matched`；不匹配时还有 `difference`，描述该帧首处差异。

stderr 输出第一帧错误，以及存在时的第一处期望差异，例如：

```text
replay line 5: invalid_hex @0: ...
replay_mismatch line 2: values[0] Usage 1:48: expected 1, got -1
```

## 期望文件

每个非空 JSONL 行对应一帧，按数据帧顺序配对，帧出错也占一项。
期望文件允许空行；不接受注释。非空行数量必须与帧数相同。
使用 [CLI encode](codec.md#文件-cli-与样例) 的 Usage 对象写法，三个键均可省略：

```json
{"values":[{"page":1,"id":48,"value":-1}],"physical":[{"page":1,"id":49,"value":90}],"active":[{"page":9,"id":1}]}
```

- `values`：只比较列出的唯一 Variable Usage。`value` 为 -2147483648..4294967295 的整数，
  或以 `hex` 替代 `value`，逐字节比较 Raw / Buffered Bytes。读取原值，不重新编码，
  因此可以断言 Null 或异常范围内的原始整数。
- `physical`：只比较列出的唯一 Usage，有限数值容差为 `1e-9 × max(1, abs(expected))`，
  用于双精度运算误差。Null、不可换算或缺失 Usage 视为差异。
- `active`：比较全部开关/Array 活跃 Usage 的集合，顺序不限；`[]` 要求全部释放。
  省略此键则不检查活跃集合。`{}` 只要求这一帧能解码。

重复 Usage（在同一个数组中）、未知键、类型错误、无穷数和错误 Raw hex 都是期望格式错误。
不存在或有歧义的 Usage、数值/字节差异属于期望不匹配。

| 退出码 | 含义 |
| --- | --- |
| 0 | 全部帧解码成功，指定的期望全部匹配 |
| 1 | 文件、描述符、帧、期望格式或资源限制错误；优先于不匹配状态 |
| 2 | 命令参数错误 |
| 3 | 帧均有效，但至少一个期望不匹配 |

新增诊断 `replay_expect` 的 offset 为期望文件从 1 开始的物理行号；帧数不同时为 0。
其 message 保留内部格式诊断和元素索引。`replay_limit` 的 offset 为超过帧数限制的行号，
文件过大时为 0。每个帧/期望文件最多 8388608 个 UTF-16 单元、65536 帧；每份期望最多
65536 个条目。文件整体读入，JSONL 按帧输出，不在内存中积累全部解码 JSON。
描述符和单帧另遵守核心资源上限。

## 证据和边界

Xbox 的 42 帧和期望来自 [已有采集](../examples/device-cases/xbox-bluetooth.json)，
轴、16 个按钮、Hat 原值直接取自已保存的独立 `expected_*` 数组，期望不由解码器生成。
这批数据是 Windows/Chrome WebHID 主机输入；使用作者创建的原始值参考描述符，
不能据此验证原始设备描述符、蓝牙包格式、真实 Logical/Null/Array 语义或 Output/Feature。

固件示例是合成方向开关，三帧依次为 Null `0f`、方向 `00` 和 `02`，
见 [固件 CI](firmware-ci.md)。`node scripts/test-cli.mjs` 在 JS/native 实际进程中覆盖
这 42 帧、行号/注释、坏帧后继续、长度错误、ID、三方向、Raw、集合顺序、部分断言、
数值差异、期望格式、资源限制及退出码。2026-10-23 Windows 本地两后端均通过。
