# 描述符 lint 核心

`lint_descriptor(Bytes) -> Result[Array[Lint], Diagnostic]` 检查已经能编译的描述符。
这是仓库新增的 API，尚未包含在已发布的 0.2.0 中；T12b 已接入 JSON、bridge 和 CLI，
网页检查面板留给 T12c。JSON v2 新增 `lints` 字段，不改变 `schema_version`，兼容策略见 [JSON v2](json-v2.md)。

先调用 `compile_descriptor`，失败时原样返回它的 `Diagnostic`，包括 code、offset 和 message。
成功时返回提示数组，不修改编译布局、解码或原描述符。Warning 表示需要审阅的映射或结构风险，
Info 表示编码、重复 Usage 或填充方面的建议；两者都不能代替设备在目标主机上的实际验收。

每条提示包含 `offset`、`code`、`level`、英文 `message` 和可选 `field_index`。
`offset` 从描述符第 0 字节起计，指向 item 前缀；`field_index` 是同一描述符编译后
`Layout.fields` 的零起始索引。集合提示没有字段索引。
结果按 offset、再按 code 的字典序排序；同一 Maximum item 只提示一次，并指向第一个受影响的数据字段。
code 和下表定义的级别/触发语义是契约；message 用于解释，消费方不应解析它。

## 规则与依据

章节号均指 [USB-IF HID 1.11（2001-06-27）](https://www.usb.org/sites/default/files/hid1_11.pdf)。
Linux 行为核对的是
[hid-core.c，提交 ce1e0223d8ad4211275c82a17ed6d43ab81e13d9](https://github.com/torvalds/linux/blob/ce1e0223d8ad4211275c82a17ed6d43ab81e13d9/drivers/hid/hid-core.c)，
用于行为对照，没有复制其实现或数据表。

| code | 级别 | 检查与定位 | 依据 |
| --- | --- | --- | --- |
| `logical_max_sign` | Info | 使用此 Maximum 的 Data 字段 Logical Minimum ≥ 0，原编码按补码解释为负；定位 Maximum | §5.8、§6.2.2.7；Linux `hid_parser_global` 根据 Minimum 选择 Maximum 的有符号/无符号读法 |
| `physical_max_sign` | Info | Data 字段的 Physical Minimum 已声明且 ≥ 0，Physical Maximum 原编码按补码解释为负；定位 Maximum | §6.2.2.7；同一个 Linux 函数对 Physical 端点也按 Minimum 选择读法 |
| `null_without_room` | Warning | Data 字段声明 Null State，却占满当前位宽的有符号或无符号逻辑域；定位 Main | §5.10、§6.2.2.5：Null 值位于逻辑范围之外 |
| `usage_count` | Warning / Info | Variable：Usage 多于 Count 为 Warning；1 < Usage 数 < Count 为 Info；Array：Usage 数与逻辑选择值数量不同为 Warning；定位 Main | §6.2.2.7、§6.2.2.8 和 Linux `hid_add_field`；Array 还基于 MoonHID 的 `value - logical_min` 映射约定 |
| `missing_usage` | Warning | Data 字段的优选 Usage 为空；定位 Main | §6.2.2 的必需项列表；Linux `hid_add_field` 将没有 Usage 的字段当作填充而不注册 |
| `unaligned_report` | Info | `(kind, report_id)` 总载荷不是整字节，需补零完成最后一字节；定位该报告最后一个 Main | §6.2.2.9、§8.4；库的 `report_length` 向上取整 |
| `field_outside_application` | Warning | Data 字段没有 Application Collection 祖先；定位 Main | §6.2.2.6、§8.4 的集合要求 |
| `collection_without_usage` | Warning | Collection 没有优选 Usage；定位 Collection Main | §6.2.2.6 要求 Collection 关联 Usage |
| `multiple_applications_without_report_id` | Warning / Info | 第二个及以后的顶层 Application 没有 Report ID；与先前 Application 的同方向报告相连时为 Warning，否则为 Info；定位该 Collection | §6.2.2.6、§6.2.2.7、§8.4：不能仅凭 Collection 数量断言所有方向都必须编号 |
| `report_id_shared_across_applications` | Warning | 相同方向、相同非零 ID 的报告跨顶层 Application；每个后来 Application / 报告只提示一次，定位其第一个 Main | §6.2.2.7 按 ID/Type 分报告，§8.4 禁止一个报告跨顶层集合 |

### 相对交接建议的调整

Maximum 两条规则降为 Info。核实的 §6.2.2.7 原文没有说 Maximum 短项一律有符号；
§5.8 和 §6.2.2.7 的符号说明涉及报告值，不能直接当作 `25 ff` 必须表示 -1 的证据。
对于 `15 00 25 ff`，MoonHID 与 Linux 都读为 255；`26 ff 00` 可让正值意图更清晰，
但这里没有跨主机失败证据，不将原写法判为错误。4 字节最大值不存在更宽的短项，提示也如实说明。

Report ID 冲突按 `(kind, id)` 检查，允许 Input / Output / Feature 复用 ID。
[Microsoft Learn 的顶层集合说明](https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/top-level-collections)
确认 Windows 按未嵌套集合创建 PDO，但没有给出“任何方向的 ID 都必须全局唯一”的原文；
因此采用 HID §8.4 的报告边界要求作为 Warning 依据。
无 ID 的多个 Application 也只有在同方向报告确实跨集合时才升为 Warning。
这些收窄都在正反例中固定，避免把方向不同的两个报告误判为同一个报告。

## 边界与实现选择

- Constant 字段不做 Usage、Null 或 Maximum 检查；它们仍参与报告位数和集合间报告边界检查。
- Usage 只统计 `usage_spans`（公共 Usage + 第一个 Delimiter 集合），不把备选集合混入数量；
  区间不展开。单个 Usage 用于多个 Variable 元素是常见的数据块写法，不提示重复。
- Array 数量不匹配是映射检查，不是设备协议错误认证。厂商可能将 Array 用作原始数据块，
  单个 Usage 只是标签；应由设备协议决定是否修改，见 [A–G 结果](real-devices.md#lint-结果)。
- ≤32 位时检查完整 Null 域；超宽 Variable 的整数端点无法占满整个位域，因此不报
  `null_without_room`，仍检查 Usage 数量。不要求主机把超宽字段解释成整数。
- `field_outside_application` 只检查有无 Application 祖先；报告归属规则只比较真正的顶层
  Application（parent 为 None、type 为 1），不把嵌套 Application 当作新的设备。
  这不是完整的顶层集合类型、HUT Usage 适用性或 USB 传输约束检查器。
- 布局与本地项语义复用已有编译器；另一次 `parse_items` 和很小的 Global 状态遍历只保存
  Logical/Physical Maximum 的原始 item，并实现 Push/Pop。没有为 lint 扩展公开 `Field`，
  没有复制整个编译状态机。取舍是多一次有界分词，换取 API 不暴露额外内部编码状态。
  JSON 导出通过内部 `lint_compiled` 复用已经编译的布局和 items，不重复编译。

## 文件 CLI

```sh
moon run src/cmd/moonhid --target native -- lint descriptor.hex
moon run src/cmd/moonhid --target js -- lint descriptor.hex
```

每条提示向 stdout 输出一行 `warning usage_count @18: ...` 或 `info logical_max_sign @8: ...`。
没有提示时 stdout 为空。有 Warning 时退出 3，仅 Info 或无提示时退出 0；
文件/十六进制/编译错误向 stderr 输出 Diagnostic 并退出 1，参数错误退出 2。
`inspect` 仍输出 JSON、成功退出 0，即使 JSON 中有 Warning。
固件 CI 可以直接检查构建后的可执行文件退出码，将 Warning 视为需要审阅的结果；
不要将进程状态 3 与文件或描述符编译失败混为一谈。

## 回归验证

`lint_test.mbt` 为每条规则检查正反例，并覆盖 Push/Pop、零长度/32 位 Maximum、
非零逻辑起点、Delimiter、超宽字段、方向/ID 隔离、Constant 填充和 280 次固定种子 A–G 突变。
检查编译结果不变、失败 Diagnostic 相同、提示位置对应真实 item、排序与重复调用稳定。
`src/examples/fixtures_test.mbt` 要求三份现有合成样例没有 Warning，未修改样例字节。
`real_devices_test.mbt` 固定 A–G 全部 code、级别、偏移与字段索引，不将英文文案冻结为解析协议。

```sh
moon test src/lint_test.mbt
moon test src/real_devices_test.mbt
moon test -p We1chan/moonhid/examples
```
