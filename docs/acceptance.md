# 验收说明与复现步骤

MoonHID 是以 MoonBit 为核心的通用 HID 描述符生成、报告编解码和字段访问工具库。
当前已发布版本为 **0.5.2**，在独立模块中安装：

```sh
moon add We1chan/moonhid@0.5.2
```

网页字段编辑、四场景入口和本页验收脚本是仓库源码的新增工作；注册表安装结果以
[0.5.2 发布记录](release-0.5.2.md) 为准，不将尚未发布的源码能力归入旧包。

## 环境与安装

基础环境为 Git、Node.js 22+ 和 [`toolchain.json`](../toolchain.json) 中固定的 MoonBit 工具链：
`moonc 0.10.14+7d59c7ec9`、`moon 0.1.20260920`。
完整模式测试 native，需要可用 C 编译器；只复核 wasm/js 可使用 `--quick`，不需要 native 工具链。
Python 3.13（本机 3.14 也已验证）与 hid-tools 0.12、Chrome 用于额外独立对照和 DOM 检查，缺失时显示 SKIP。

安装命令依据 [MoonBit 官方下载说明](https://www.moonbitlang.com/download/)；固定版本的使用方式也见
[仓库 CI 安装器](../.github/actions/setup-moon/action.yml)。macOS 和 Linux 分别在各自终端运行同一命令：

```sh
curl -fsSL https://cli.moonbitlang.com/install/unix.sh -o /tmp/install-moonbit.sh
bash /tmp/install-moonbit.sh '0.10.14+7d59c7ec9'
export PATH="$HOME/.moon/bin:$PATH"
moon version --all
```

Windows PowerShell：

```powershell
$env:MOONBIT_INSTALL_VERSION = '0.10.14+7d59c7ec9'
irm https://cli.moonbitlang.com/install/powershell.ps1 | iex
$env:PATH = "$HOME\.moon\bin;$env:PATH"
moon version --all
```

若工具链已安装到其他目录，设置 `MOON_HOME`，或把 `MOON_BIN` 指向 `moon` 可执行文件。
验收脚本会把找到的二进制目录传给子进程，文件路径和命令参数通过 argv 传递，不拼接 shell 命令。
完整模式的 native 编译器可使用 Windows 的 Visual Studio C++ Build Tools、macOS Command Line Tools 或 Linux 系统 C 工具链。

可选独立对照推荐单独创建 Python 虚拟环境并安装固定依赖：

```sh
python -m pip install hid-tools==0.12
```

`PYTHON` 可以指向该虚拟环境的解释器，`CHROME_BIN` 可指定 Chrome 二进制路径。
脚本只检测和执行可用依赖，不安装软件、不请求真实设备权限。

## 一键验收

克隆后在仓库根目录执行：

```sh
moon update
node scripts/acceptance.mjs
```

快速模式：

```sh
node scripts/acceptance.mjs --quick
```

完整模式按顺序检查文档、四后端无警告检查与测试、wasm/js 四场景演示、browser bridge、WebHID 模拟、
教学与 Xbox 42 帧回放、JS 文件 CLI、标准报告案例、固件 CI、离线打包与服务。
native 文件 CLI、native 标准案例、两项 hid-tools 独立对照、Chrome DOM 为额外检查。
`--quick` 仅执行 wasm/js 后端，跳过 native CLI、native 标准案例和需要 native 的 hid-tools 编码对照。

终端最后显示“步骤 / 结果 / 用时 / 是否必需”的表及汇总，例如依赖齐全的完整模式：

```text
汇总：PASS 22 / FAIL 0 / SKIP 0
报告：_build/acceptance-report.json
```

计数以实际输出为准，可选依赖缺失时对应步骤显示 SKIP，并提示安装/环境变量。
可选步骤一旦实际执行失败，同样会使本次验收失败；必需步骤未执行也不能算通过。
任一 FAIL 或必需 SKIP 导致退出码 1。完整模式缺 C 编译器时，四后端测试会失败，应安装编译器或明确改用快速模式。

JSON 报告包含 Git 提交、工作区是否有改动、平台、工具链预期和实际版本、每步命令、状态、耗时、退出码和日志位置。
详细日志保存在 `_build/acceptance-logs/`。依赖某次失败构建的步骤会跳过，避免读取旧的生成文件。
工作区有修改时报告保留 `dirty: true`；该报告证明当次源码验证，不等同于已发布包的独立安装验收。

## 四场景演示

```sh
moon run src/cmd/scenarios
```

该入口按申报场景顺序执行：键盘与 LED、鼠标与手柄、媒体键与厂商配置、固件回归。
完整 21 行预期输出及每个操作的解释见 [四场景演示](scenarios.md)。
它由 `scenario_lines()` 实际调用核心 API 得出，完整快照在四个后端参与测试；本页通过链接复用同一份完整输出。
例如 Shift+A 为 `02 00 04 00 00 00 00 00`，媒体 Play/Pause 为 `cd 00`，Hat 90 度为带 ID 的 `09 02`。

## 文件 CLI 演示链

以下均在仓库根目录运行，使用 Node.js 后端；换成 `--target native` 也可执行。

```sh
moon run src/cmd/moonhid --target js -- generate keyboard
moon run src/cmd/moonhid --target js -- lint examples/codec/keyboard.hex
moon run src/cmd/moonhid --target js -- encode --kind input --id 0 examples/codec/keyboard.hex examples/codec/keyboard-usages.json
moon run src/cmd/moonhid --target js -- decode --kind input examples/codec/keyboard.hex examples/codec/keyboard-report.hex
```

预期：generate 输出 [键盘描述符](../examples/codec/keyboard.hex) 的相同字节；lint 无输出、退出 0；
encode 输出 `02 00 04 06 00 00 00 00`；decode 返回 JSON v2，Left Shift = 1，数组包含 A 与 C。
生成 → 检查 → 编码 → 解码的真进程连接和逐元素比较还由 `scripts/test-cli.mjs` 自动执行。

## 网页与离线演示

- [在线检查器](https://we1chan.github.io/moonhid/)：键盘 → Output → 初始化 → Caps Lock 写 1，报告 `00 → 02`；Num Lock 写 1，变为 `03`。
- 将原始报告改为 `e0`，Caps Lock 写 1 得到 `e2`；写 2 显示 `value_range`，原报告保持不变。导出 HEX 包含完整报告字节。
- [GitHub Release](https://github.com/We1chan/moonhid/releases/latest) 提供历史已发布离线包；源码新增能力可执行
  `node scripts/build-web.mjs`、`node scripts/package-inspector.mjs`，然后在生成目录运行 `node scripts/serve-offline.mjs`。
  离线包运行仅需 Node.js，Windows 可双击 `start-inspector.cmd`。

具体步骤与已记录的浏览器环境见 [网页编辑](browser-editor.md)、[检查器验收](inspector-validation.md)。
本页的网页编辑与导出构造离线字节；它不表示已增加真实设备 Output/Feature 传输。

## 六项验收标准对照

| 标准 | 本项目的做法 | 可核验证据 |
| --- | --- | --- |
| MoonBit 为主 | 核心协议、编解码、构建器、Usage 访问、CLI 和 bridge 使用 MoonBit；JS 负责界面、传输适配与测试编排 | [设计](design.md)、[源码统计](#源码统计) |
| 仓库公开 | 保留提交、Issue、PR、里程碑和发布历史 | [提交](https://github.com/We1chan/moonhid/commits/main/)、[里程碑](https://github.com/We1chan/moonhid/milestone/1) |
| 能够运行 | 场景入口、固定输出、一键脚本、CI 与独立安装 | [场景](scenarios.md)、[脚本](../scripts/acceptance.mjs)、[0.5.2 安装](registry-0.5.2-validation.json) |
| 工作有效 | 仓库创建于 2026-10-01，版本和功能连续迭代，源码新增有对应 Issue/PR | [Release](https://github.com/We1chan/moonhid/releases)、[PR](https://github.com/We1chan/moonhid/pulls?q=is%3Apr) |
| 开源合规 | Apache-2.0，公开协议独立实现，描述符与模板参考有来源 | [LICENSE](../LICENSE)、[真实来源](real-devices.md)、README 协议与参考 |
| AI 可解释 | 如实披露 AI 工作和设计；参赛者目前尚未验证本人独立解释能力 | [实际分工](ai-collaboration.md)、[设计](design.md)；此项仍需参赛者本人掌握和讲解 |

脚本全绿证明列出的技术检查通过，不等同于赛事六项标准自动全部满足。
报名/验收提交正文和本人理解、实机操作由参赛者完成。

## 源码统计

在仓库根目录执行以下 Node.js 命令，统计 Git 跟踪的 `.mbt` 文件及非空行：

```sh
node --input-type=module -e 'import {execFileSync} from "node:child_process";import {readFileSync} from "node:fs";const files=execFileSync("git",["ls-files","-z","--","*.mbt"],{encoding:"utf8"}).split("\0").filter(Boolean);console.log(files.length+" 个 .mbt 文件，"+files.reduce((n,p)=>n+readFileSync(p,"utf8").split(/\r?\n/).filter(line=>line.trim()).length,0)+" 个非空行");'
```

该统计包括实现、示例、测试与注释，不把测试行数当作独立生产功能，也不隐藏 JS/Python。
GitHub 的语言字节统计与非空行数是不同指标，应分别理解。

## 范围与证据边界

- [HID 兼容目标](hid-compatibility.md) 定义 HID 1.11 Report Protocol 离线范围；[完整报告案例](report-cases.md) 区分标准、宽松扩展和拒绝案例。
- 33 位普通 Raw 是宽松扩展，不能算作普通标准字段的符合性证据；Buffered Bytes 则按整段字节流处理。
- 合成报告和模拟 HID 适配器验证软件语义；[七份真实描述符](real-devices.md) 验证结构；[Xbox 数据](xbox-bluetooth.md) 记录实际 Input 观测及其限制。
- 原生 HIDAPI、真实键盘 LED 与厂商 Feature 收发尚未完成。完整 Usage 名称库、跨单位制换算与自动描述符优化仍在规划。
- 编译、lint、独立实现对照与少数实机数据都不等同于完整 HID 认证或所有设备兼容。

## 本轮交付记录

2026-10-22，[网页编辑 PR #40](https://github.com/We1chan/moonhid/pull/40) 五项 CI 全绿后合并，
[Pages 部署](https://github.com/We1chan/moonhid/actions/runs/39803974333) 成功。
Windows / Chrome 155.0.8059.86 通过线上实际控件确认 `00 → 02 → 03`、`e0 → e2`，以及非法值 2 保持报告和显示诊断。
[四场景 PR #42](https://github.com/We1chan/moonhid/pull/42) 四后端各 113/113，五项 CI 全绿后合并。
后续运行结果以本机生成的 JSON 报告和对应提交的 CI 为准。

本机验收脚本实际运行（Windows x64，Node v24.14.0、固定 MoonBit 工具链、Python 3.14.3、hid-tools 0.12、Chrome 155）：

| 命令 | 结果 |
| --- | --- |
| `node scripts/test-acceptance.mjs` | 真实进程退出码、空格/Unicode 参数、失败后跳过依赖和可选检查结果判定通过 |
| `node scripts/acceptance.mjs --quick` | PASS 21 / FAIL 0 / SKIP 3；三项 native 检查按选定模式跳过 |
| `node scripts/acceptance.mjs` | PASS 22 / FAIL 0 / SKIP 0；四后端各 113/113 |

上述报告对应未提交工作区，`dirty: true`；发布时仍需在实际发布提交的干净克隆重新验收。
CI 的 JS 任务还会运行快速验收，保存 JSON 报告和每步日志，提供 Linux 上的可复现执行记录。
