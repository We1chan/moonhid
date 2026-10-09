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

## 界面重构复验

2026-10-01 重写 `web/` 界面：描述符与报告改为输入后自动解析/解码，Items 改为逐项注释的常驻列表，
位布局改为每行一个字节，两个十六进制编辑器会标出选中字段、item 或 Collection 的字节。
上文表格中提到「编译描述符」「解码报告」按钮、Items 折叠面板和标签切换的条目针对旧界面，以本节为准。

本节由 headless Chrome 154 通过 DevTools Protocol 脚本执行（脚本不在仓库中），
视口为 1440 × 900、1100 × 900 和 390 × 844；尚未在有界面的 Chrome 中手动复验。

- 鼠标：6 个值；位布局中填充 5 位单独标出；选中字段 #0 时描述符标出 `81 02`，报告标出 `05`。
- 键盘：数组槽位显示解码后的 `Key A` / `Key C`；Output 标签载入 `03` 得 `1, 1, 0, 0, 0`。
- 手柄：Report ID 行显示 `7`；16 位轴拆成 `X [7:0]` / `X [15:8]` 两行。
- 多 ID 描述符：在 Input ID 1 输入 `02 ff` 提示 `report_id_selection`，点「切换到 ID 2」后得 `-1`；
  Feature ID 2 得 `-1`；点击 Output 的 Main item 会切换到 Output 报告。
- 报告 `01` 报 `report_length`；`01 zz` 报 `invalid_hex`，编辑器标红 `z`；描述符 `05 q1` 标红 `q`。
- Physical / Unit 描述符：`-3175 … 3175`、`10⁻⁴ in`、集合路径 Mouse › Pointer；点击 Pointer 标出其字节范围。
- 256 个 1-bit 值：解码值表分两页（200 + 56 行）；导出 JSON 含 256 个值和 32 字节报告；
  报告改为 `00 zz` 后导出的 `wire_hex` 与 `decoded` 为 `null`。
- 600 个字段（1802 个 item）：解析和渲染约 73 ms；选中最后一个字段时 Items 翻到对应页。
- 三种视口均无水平溢出，浅色与深色主题均已截图检查；控制台没有 warning 或 error。

## 真实描述符与 JSON v2 复验

2026-10-02，Apple Silicon macOS，Google Chrome 154.0.8037.58，Node 24.19.0，Python 3.13.15。
本次使用仓库内可复现的 `node scripts/test-inspector.mjs` 通过 DevTools Protocol 控制
独立 headless Chrome；没有在有界面的 Chrome 手动验收，也没有捕获真实输入报告。
JS CI 现在也运行该 DOM 测试和独立 hid-tools 对照。

- A–G 全部成功解析；1440 × 900、1100 × 900、390 × 844 均没有页面水平溢出。
- B 的 Input ID 68 展示 1751 个元素，首屏 200 行，最后一页 151 行。
- F 的 Input ID 2 使用构造报告（ID `02` 加 2003 个 `a5` 字节）：显示前 16 字节，
  提示「共 2003 字节」与「原始字节字段，不解码为整数」；位布局最多 256 字节。
  导出的 schema v2 JSON 保留完整 2003 字节原始值。
- G 的 System Control 显示一个 `0x00 … 0x7FFF（32768 个）` 区间；
  构造报告 `03 ff 7f` 解码为 32767，Usage 为 `0x0001:0x7fff`。
- 浅色、深色截图均复查；`05 q1` 返回 invalid_hex 并禁用导出；页面控制台没有 warning/error。

可设置 `MOONHID_SCREENSHOTS=/tmp/moonhid-ui-checks` 保存三种视口的浅色/深色截图，
或用 `CHROME_BIN` 指定 Chromium 可执行文件。测试服务仅监听随机的 loopback 端口，
Chrome 使用独立临时 profile，结束后清理自己启动的进程和 profile。
关闭时仅向本次 Chrome 的独立进程组发信号，等待退出后删除 profile，目录清理采用有限重试。
2026-10-02 的 CI 曾在所有 DOM 断言通过后因 `ENOTEMPTY` 失败：父进程退出时子进程仍在写入，
现已修正关闭范围与清理顺序，避免将成功验收变成偶发的收尾失败。

## WebHID 模拟验收

2026-10-02。`node scripts/test-webhid.mjs` 验证非零/零 Report ID、DataView 子视图、
8192 字节载荷上限、顶层 collections 的嵌套字段不重复计数、字段差异提示、
断开/热拔插停止事件监听，以及 pending open 取消后关闭连接。

`node scripts/test-inspector.mjs` 在独立 headless Chrome 页中注入模拟 `navigator.hid`，
实际点击连接与断开按钮。模拟报告的底层 buffer 为 `63 ff 58`，只暴露中间一个字节，
Report ID 为 3：报告编辑器得到 `03 ff`，MoonBit 解码得到 -1，collections 对照无差异。
断开后再发模拟事件不会覆盖 `03 00`；模拟拔出后显示「设备已拔出」。
页面默认离线，只在用户点击连接后申请设备访问，描述符/报告数据不上传。

这些是适配器与 DOM 证据，没有请求真实 HID 权限，没有验证真实设备的实时输入。
手工验收应使用允许访问的手柄或厂商自定义 Collection，记录浏览器版本、权限选择、
描述符、实际报告与断开结果；受保护键鼠 Collection 不可据此承诺可读。

## 浏览器状态与重建边界复验

2026-10-09，Windows，Chrome 154.0.8037.98，Node v24.14.0，Python 3.14.3。
本次运行仓库内的 bridge、WebHID、usability、Chrome DOM 与重新打包的离线服务测试。
新增回归沿用现有 JS CI；MoonBit 四后端、公开接口及格式检查由 PR CI 执行，JS 任务重新构建网页解析器。

- 连接关闭期间禁止重连，重复断开等待同一次关闭；关闭失败后释放状态并停止旧报告监听。
- 采集页与检查器共用连接控制器，支持手柄筛选与打开前的参考描述符检查。
  取消设备选择、取消准备、延迟打开期间停止或离开页面，均不留下有效连接。
- 关闭失败仍可复制、导出已采集记录并重新连接；取消新连接保留上一份记录。
- 模拟历史页面的 `pagehide` / `pageshow` 后重连并拔出设备，两个页面都能停止接收。
- 编辑报告后在同一浏览器任务内立即导出，JSON 使用新输入；无效报告的解码组件为空。
  描述符一经编辑便清除旧结果并禁用导出，重新解析成功后恢复。
- Input / Output / Feature 的 ID 0、1、127、128、255 均重建、对照并解码成功。
  Collection 类型 128、255 保持单字节编码；页零 Usage 列表与范围不继承 Collection 的页。
- A–G 描述符、三个视口、浅色/深色主题、现有错误定位与 Xbox 42 帧回放继续通过。

连接与页面生命周期使用模拟设备，不请求真实 HID 权限；Xbox 数据重放沿用既有采集记录。

## 启动输入与 Collection Usage 复验

2026-10-10，Windows，使用独立 headless Chrome 和现有 Node 回归脚本。

- 暂停网页解析器下载后输入描述符，或恢复报告文本；解析器就绪时保留这些内容并进行解析。
  无效描述符保持错误定位，修正后仍保留尚未关联报告布局的输入；加载期间主动清空描述符也不自动填回样例。
- Collection 的 Usage Page 和 Usage 采用独立的 16 位项，验证页号
  `0`、`1`、`0xff00`、`0xffff` 与 Usage `0`、`0x7fff`、`0x8000`、`0xffff` 的全部组合；越界和小数值明确拒绝。
- Input / Output / Feature 的报告首字节匹配另一个已知 ID 时，载荷长度错误仍可切换到对应布局。
  切换后显示该布局的长度诊断；修正载荷可以解码。未知 ID 和无效十六进制保留原诊断，不提供误导性切换。
- 继续通过 bridge、WebHID 生命周期、Xbox 42 帧回放、三种视口与主题、导出和重新打包的离线服务检查。

MoonBit 四后端及公开接口、格式检查由 PR CI 执行；网页测试在 JS CI 中使用重新构建的解析器。

## 字段分页联动与单位显示复验

2026-10-10，Windows，独立 headless Chrome 回归。

- 包含 201 个元素的首字段后再声明第二字段，从 Items 或 lint 定位第二字段时，值表自动显示第 2 页并高亮目标字段。
  再选择当前页已有的首字段时保留页码；从 Input 的 Items 定位到 Output 的后置字段也显示对应页。
- 验证 199、200、201 行边界，目标字段不会落在不可见的另一页。
- 单位维度全部为零时仍显示十进制比例，例如 `10⁻³ 无量纲` 和 `10³ 无量纲`；零指数和有维度单位的显示保持正确。
- bridge、WebHID 生命周期、Xbox 42 帧回放、既有视口/主题、导出和页面恢复用例继续通过。
