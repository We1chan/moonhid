# 检查器验收记录

日期：2026-10-01。环境：Apple Silicon macOS、Google Chrome，实际浏览器视口 1408 × 613。
工具链：`moon 0.1.20260920`、`moonc v0.10.14+7d59c7ec9`。
所有测试输入均为仓库合成样例或为验收编写的描述符，不代表真实设备兼容性验证。

## 自动检查

`moon check --target all --deny-warn` 通过。wasm、wasm-gc、js、native 四个后端
分别构建、通过 31 项测试，并运行三个设备示例。
`moon info` / `moon fmt` 已运行，公开接口新增 Collection、Physical/Unit 与 JSON API。

`node scripts/build-web.mjs` 从 MoonBit 构建 ESM，`node scripts/test-web.mjs` 验证：
鼠标、键盘、手柄整数值；键盘 LED Output；多 ID 与 Feature；嵌套集合与物理/单位信息；
uint32 最大值 `4294967295`；十六进制、截断、未知语义、方向、长度和 ID 错误。
CI 的 JS 任务也执行这两条命令，下面的 Chrome DOM 验收不由 CI 自动执行。

## Chrome 实际交互

| 操作 | 实际结果 |
| --- | --- |
| 鼠标样例 | `1, 0, 1, -1, 2, -2`；填充仍显示，解码省略 Constant |
| 键盘 Input | 14 个值，Left Shift=1，数组映射 Key A / Key C |
| 键盘 Output + 载入样例 | 原始报告 `03`，5 个 LED 值 `1, 1, 0, 0, 0` |
| 手柄 | Report ID=7，按钮 1 / 12 按下，轴为 `-32768 / 32767` |
| 输入 `05 q1` | invalid_hex，UTF-16 偏移 3；定位后选中 `[3,4)` |
| 修改描述符 | 清除旧布局与解码值，禁用导出，要求重新解析 |
| 嵌套 Mouse / Pointer | 两层 Collection；字段所属最内层 Pointer，显示完整路径 |
| Physical / Unit 示例 | `-3175 … 3175`、English Linear、L^1、`10^-4` |
| 点击字段来源 @30 | 展开 Items，只定位对应 Main / Input / `06` |
| 多 ID：Input 1 / 2 | ID 2 报告在选择 ID 1 时提示不匹配；改选 ID 2 后得 `-1` |
| Feature ID 2 | 正确切换独立布局并解码 `-1` |
| 256 个 1-bit 值 | 初页 200 行，下一页 56 行；JSON 下载含全部 256 个值、32 字节报告 |
| 报告文本改为 `00 zz` | invalid_hex，偏移 3；旧解码值清空，随后 JSON 中 decoded / wire_hex 为 null |
| 桌面排版与控制台 | 页面无水平溢出；页面控制台未记录 warning / error |

多 ID 验收描述符：

```text
75 08 95 01 85 01 15 00 25 ff 81 02 91 02 85 02 15 81 25 7f 81 02 b1 02
```

Physical / Unit 验收描述符（报告 `ff`）：

```text
05 01 09 02 a1 01 09 01 a1 00 15 81 25 7f 36 99 f3 46 67 0c 55 0c 65 13 75 08 95 01 09 30 81 06 c0 c0
```

分页验收描述符：`15 00 25 01 75 01 96 00 01 81 02`；报告为 32 个 `00` 字节。

## 启动入口

`MOONHID_NO_OPEN=1 ./start-inspector.command` 在本机成功找到工具链、构建模块并启动服务。
服务仅监听 `127.0.0.1:8765`。再次运行能识别同一仓库的服务并正常退出，避免重复启动。
`MOONHID_NO_OPEN` 用于检查入口而不启动额外浏览器窗口；正常双击会打开默认浏览器。

真实设备差异验证、mooncakes 发布，以及其他浏览器和移动设备的运行验收仍在开发路线中。
