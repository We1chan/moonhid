# 确定性模糊测试与性质验证

2026-10-02。`fuzz_test.mbt` 使用测试内实现的 xorshift32；UInt 位移与固定种子使
wasm、wasm-gc、js、native 使用相同语料，不增加随机库或模糊测试框架依赖。

| 种子 | 语料 | 检查重点 |
| --- | --- | --- |
| `0x4d484944` | 2000 份 0..256 字节随机描述符，另加 65536/65537 字节边界 | 分词与编译不崩溃；已知诊断、合法偏移、分词连续且不越界 |
| `0x13579bdf` | 500 份保证有效的结构化描述符、1500 份随机报告 | 有/无 ID、三种报告方向、Array/Variable/Constant、整数/原始字节与本地元数据 |
| `0xa5a5c3c3` | A–G 每份 40 次突变，共 280 份 | 单个位翻转、删除、插入、截断；成功布局继续解码随机报告 |

随机字节通常很早触发诊断，因此单独生成结构化有效语料，保证每次都进入布局和解码。
结构化语料还包括带符号/无符号与完整/收窄 Logical 范围、Null State、
非字节对齐的超宽 Variable 字段、平衡的 Push/Pop、String/Designator 和 Delimiter。
测试要求整数、超宽与 Array 字段各至少覆盖 500 个。

对所有成功布局检查：

- 字段数最多 4096，Collection 最多 4096，Usage 及备选 Usage 合计最多 1024 段，索引区间合法。
- 每个方向/ID 的载荷最多 65536 位，完整 wire 长度包含所需 ID，最多 8193 字节。
- 长度正确的报告必须解码成功，Constant 省略，整数/原始字节元素数与声明一致。
- 整数位于其位宽的二补码或无符号范围，偏移在载荷内；Usage 属于主区间，超出 Logical 范围的 Array 不映射 Usage。
- `in_logical_range`、`is_array`、`is_null` 与声明一致；原始字节长度正确且末字节未用高位为零。
- 多一个 wire 字节必须返回 `report_length`，不能悄悄接受尾部数据。

诊断码采用显式允许列表；协议边界改变时，需同时审阅该列表与核心、网页、JSON 文档。
测试覆盖固定语料及现有资源上限，不代表穷尽 HID 协议或证明任意输入的运行时间。

## 复现

```sh
moon test src/fuzz_test.mbt --target wasm
moon test src/fuzz_test.mbt --target wasm-gc
moon test src/fuzz_test.mbt --target js
moon test src/fuzz_test.mbt --target native
```

本机使用 `moon 0.1.20260920`、`moonc v0.10.14+7d59c7ec9`。
新增三项测试与现有用例一起运行；四后端均为 56 项通过，CI 也运行全部语料。
