# 核心设计说明

MoonHID 将描述符和报告字节转换为可复用的布局，再围绕该布局编解码与访问字段。
本文解释实现选择；完整接口签名、使用示例和错误规则见 [编解码文档](codec.md)，不重复维护接口表。
所有代码链接指向仓库源码，函数名可用于定位。兼容范围以 [HID 兼容目标](hid-compatibility.md) 为准。

## 流水线与诊断位置

| 阶段 | 实现 | 输入与输出 | 错误示例 |
| --- | --- | --- | --- |
| 文本 | [`parse_hex`](../src/hex.mbt) | UTF-16 十六进制文本 → Bytes | `invalid_hex`、`odd_hex`、`split_byte`；偏移为原始文本字符索引 |
| 分词 | [`parse_items`](../src/items.mbt) | Bytes → 含原始宽度与数据的 Item 数组 | `truncated_item`；偏移为字节位置 |
| 布局 | [`compile_descriptor`](../src/layout.mbt) | Bytes → Field 数组、Collection 树、Report ID 状态 | `global_stack`、`collection`、`logical_range`、`unsupported_item` |
| 报告 | [`decode_report`](../src/decode.mbt)、[`encode_report`](../src/encode.mbt) | Layout + wire → 解码组件；Layout + 值 → wire | `report_length`、`unknown_report`、`value_count`、`value_range` |
| 检查 | [`lint_descriptor`](../src/lint.mbt) | 描述符 → 编译错误或独立的 Lint 数组 | 编译错误原样传播；Warning/Info 不修改布局 |
| 展示 | [`descriptor_to_json`、`report_to_json`](../src/json.mbt) | 布局、items、元数据、报告 → JSON v2 | 复用前序诊断；JSON 契约见 [JSON v2](json-v2.md) |

核心返回 `Result[..., Diagnostic]`，不通过异常表示普通输入错误。`Diagnostic` 含稳定的 `code`、`offset` 和可读 `message`。
报告长度错误使用实际字节数作为偏移；字段写入错误通常指向描述符中的字段声明。
浏览器桥接另带 `stage`，区分文本位置、描述符位置和报告位置。

## 描述符状态机

[`compile_descriptor`](../src/layout.mbt) 对 Item 线性遍历，分别维护四类状态：

- **GlobalState**：Usage Page、Logical/Physical、Unit、Report Size/Count/ID。它持续影响后续字段。
  Push 将整个 GlobalState 压栈，Pop 恢复；两者不保存 Local 状态、Collection 栈或报告位游标。
- **Local 状态**：Usage 区间、String/Designator、Delimiter 备选 Usage。在处理每个 Main item 后清空，
  包括 Collection 和 End Collection，避免上一个控件的 Usage 泄漏到下一个控件。
- **Collection 栈**：开始时记录父节点与声明偏移，结束时补上结束偏移；字段保存当前最内层 Collection 索引。
- **位游标 Map**：键为 `Main tag × 256 + report_id`。Input、Output、Feature 即使使用同一 ID，仍各自从载荷位 0 开始。

保留 Constant 字段是为了计算真实长度和位置；解码时再省略其值。
Global Push/Pop 必须平衡，Collection 必须配对；未完成的 Local 范围和 Delimiter 也明确报错。

### 键盘位偏移手算

使用 [`keyboard_descriptor`](../src/examples/templates.mbt) 的模板：

| Main 字段 | Size × Count | 该方向起始位 | 结束后游标 |
| --- | --- | --- | --- |
| Input：八个修饰键 | 1 × 8 | 0 | Input = 8 |
| Input：Constant | 8 × 1 | 8 | Input = 16 |
| Input：六个按键槽 | 8 × 6 | 16 | Input = 64 |
| Output：五个 LED | 1 × 5 | 0 | Output = 5 |
| Output：Constant | 3 × 1 | 5 | Output = 8 |

所以 Input 为 8 字节，Output 为 1 字节。Caps Lock 是 Output 首字段的元素 1，占载荷位 1；
Num Lock 与 Caps Lock 同时为 1 得到 `03`。Output 不继承 Input 已使用的 64 位游标。

## 位序与 Report ID

[`extract_bits`](../src/bits.mbt) 逐位计算字节索引和字节内位索引；第一个字段从字节的最低位开始。
`Field.bit_offset` 始终是载荷偏移。带 Report ID 时，解码器先读取首字节选择布局，再给物理字节偏移加 8 位；
无 ID 时不添加额外字节。传输层特有的前缀不属于核心 wire 格式。

一个跨字节的 13 位字段，从载荷偏移 3 开始，原始字节为 `ad 65`：

```text
第一个字节贡献：0xad >> 3 = 0x15（字段位 0..4）
第二个字节贡献：0x65 << 5 = 0xca0（字段位 5..12）
合并：0x15 | 0xca0 = 0xcb5 = 3253
```

这与 `extract_bits(b"\xad\x65", 3, 13)` 的结果相同。有符号字段随后按字段最高位进行符号扩展，
不会把整个源字节按有符号整数解释。浏览器每行左边显示高位，不改变协议的 LSB-first 排列。

## 数值、Usage 与物理量

[`GlobalState`](../src/layout.mbt) 同时保存 Maximum 的有符号与无符号读法，在 Main 字段形成时根据 Minimum 选择。
Logical Minimum 小于 0 时选择有符号 Maximum，否则选择无符号 Maximum；报告值的符号性也取决于 Logical Minimum。
例如非负下限配单字节 `ff` 表示 255。构建器对 255 生成 `26 ff 00`，使有符号和无符号读法一致，减少解释歧义和 lint 提示。

[`decode_report`](../src/decode.mbt) 保留范围外原值：`in_logical_range` 为 false；
只有字段声明 Null State 时，`is_null` 才同时为 true。超范围不是自动的解码失败，也不被钳制或改为零。
编码默认拒绝普通字段的范围外值，Null 字段接受可表示的范围外整数；显式重放开关可保留其他范围外原值。

Variable 的第 n 个元素使用第 n 个 Usage，Usage 不足时重复末个 Usage。
Array 则用 `value - logical_min` 索引 Usage 序列，先检查 Logical 范围与索引是否存在。
[`array_usage`](../src/access.mbt) 进一步将未映射、范围外或 Usage ID 0 视作空槽，供按键置位与释放使用。
Usage 同时出现在多个可写元素时返回 `ambiguous_usage`，调用方可改用明确的字段/元素索引。

[`physical_value`](../src/units.mbt) 先做线性映射，再应用 `10^Unit Exponent`：

```text
物理值 = [Pmin + (逻辑值 - Lmin) × (Pmax - Pmin) / (Lmax - Lmin)] × 10^e
```

Physical 任一端点缺失或两端均为零时，有效范围沿用 Logical，原声明仍保留。
反向转换先消除十进制指数，再做逆线性映射，并使用“恰好一半时远离零”的四舍五入。
固定工具链的 `Double::round` 将负半值也朝正无穷取整，不能满足正负对称，因此实现对绝对值取整后恢复符号。
非有限数、退化范围、映射到范围外和 Null 的物理量换算均返回明确诊断。这里不转换英寸/厘米等不同单位制。

## 编码、初始化与字段写入

[`encode_report`](../src/encode.mbt) 要求按字段/元素顺序提供全部非 Constant 值，不能用缺少的值隐式补齐。
1..32 位普通字段用 `Integer`，更宽 Variable 用 `Raw`，末字节未用高位为零。
新报告的 Constant、未用尾位清零，并写入所选 ID；`write_field` 从原报告复制，只修改目标元素的位。
这解释了为什么 LED `e0` 写 Caps Lock 后为 `e2`，而重新编码同一逻辑数据时可得到 `02`。

[`new_report`](../src/access.mbt) 用于初始化：先清零，再写 ID，并为可表示的 Null 与 Array 空闲值设置初始整数。
它不推断业务数据；没有可表示空闲值时保留零，零本身仍可能超出 Logical 范围。

Buffered Bytes 的 Main bit 8 表示整个固定字节流：`Size × Count / 8` 字节只对应一个 `Raw`，
解码进入 `buffered_values`，字段元素索引固定为 0。它要求字节对齐，不套用普通整数、Array、Logical/Physical 或 Null 解释。

## 错误、资源上限与支持边界

不支持的长项和保留语义在布局编译时明确报错；原始 tokenizer/`serialize_items` 仍可保留其字节。
String/Designator 和 Unit 中保留的信息不等于已实现全部上层语义，见 [兼容目标](hid-compatibility.md)。

主要上限由编译器和 [`report_length`](../src/decode.mbt) 双重约束：

| 资源 | 上限 |
| --- | --- |
| 描述符 | 65536 字节 |
| Main 报告字段、Collection | 各 4096 |
| Collection、Global 栈深度 | 各 64 |
| 每个方向/ID 报告 | 65536 位 |
| 普通整数元素 / Array 元素 | 1..32 位 |
| Usage、String、Designator 区间 | 每类限额见 README；Usage 优选/备选合计 1024 段 |

区间不展开成海量 Usage：一个区间即可表示同页的全部 65536 个 ID，查询按索引定位。
总报告位数限制进一步约束元素数和原始字节分配。手工构造的 Layout 也必须经过长度/布局校验，不能绕过限制。
超宽普通 Variable 和普通字段跨越超过四字节的布局属于宽松扩展，不作为完整 HID 1.11 符合性证据。

## 关键取舍与证据

- **参照 `hidpi.h`**：用 Usage 访问按钮、按键与数值，避免调用方写死字段偏移；字段级入口仍处理歧义和底层编辑。
  这是接口语义参考，核心按公开描述符规则独立实现，具体对应见 [codec](codec.md)。
- **JSON v2 的 `number64`**：当前范围的 HID 整数可以被 JSON 数字精确表示；默认 Int64 的 ToJson 会输出字符串，
  因而在 [`json.mbt`](../src/json.mbt) 显式转换为数字，完整 uint32 不经有符号 32 位截断。
- **多种独立证据**：手工固定字节、四后端回归、hid-tools 对照、模糊性质、注册表独立安装与公开链接检查回答不同问题。
  合成测试与虚拟设备不替代 [Xbox 实际 Input 记录](xbox-bluetooth.md)，后者也不能证明未经测试的 Output/Feature 传输。

质量记录与纠错过程见 [AI 协作说明](ai-collaboration.md)、[标准报告案例](report-cases.md) 和 [独立排查](review-audit-2026-10-20.md)。
