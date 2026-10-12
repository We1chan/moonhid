# MoonHID 0.4.0

2026-10-12 已发布到 Mooncakes，并通过独立项目的四后端安装验收。
发布提交为 `1f1abfd815e254304c89e25b296b2e13c65ccab7`。
[main CI](https://github.com/We1chan/moonhid/actions/runs/38248198806) 的固定工具链四后端与最新 JS 任务全部成功，
[Pages 部署](https://github.com/We1chan/moonhid/actions/runs/38248305945) 也已完成。

0.4.0 将 MoonHID 扩展为通用 HID 报告工具库。调用方可以生成描述符、编码 Input / Output / Feature，
按字段或 Usage 读写报告，并将 Logical 值与物理量相互转换。完整范围与成熟库对比见
[功能范围](features.md) 和 [README](../src/README.mbt.md#与成熟-hid-库的功能对比)。

## 本版本内容

- `DescriptorBuilder` 链式构建器，支持集合、Usage、范围、Report ID、Physical / Unit 与 Global Push / Pop；
  `serialize_items` 保留原始 item 宽度和未知数据。
- `encode_report` 支持三方向、多 ID、整数和超宽 Raw 值，校验数量、范围与 Null，自动写入 ID 和零填充。
- `find_fields`、`read_field`、`write_field`、`array_selector` 与位/字节插入接口，可修改一个字段并保留相邻位。
- `list_reports`、`new_report`、按 Usage 按下/释放/列出按键与按钮、读写数值和物理量，参照 Windows `hidpi.h` 接口。
- 五种描述符模板：鼠标、键盘（含 LED）、手柄、媒体键、厂商数据。
- native / Node.js CLI 增加 `generate`、`encode`，编码支持位置数组与 Usage 对象两种值文件。
- JSON schema 保持 v2；修复最新 MoonBit 的 JSON 转换弃用调用，保留既有数字格式。

网页继续提供描述符分析、解码、lint、JSON 导出与 WebHID Input。
编码、字段修改与生成通过库和 CLI 使用。核心保持纯 MoonBit，设备传输边界见 [功能范围](features.md#明确边界)。

## 安装与交付入口

```sh
moon add We1chan/moonhid@0.4.0
```

- [Mooncakes 模块](https://mooncakes.io/docs/We1chan/moonhid)
- [GitHub Release 与离线检查器](https://github.com/We1chan/moonhid/releases/tag/v0.4.0)
- [在线检查器](https://we1chan.github.io/moonhid/)

离线 ZIP 包含编译好的 MoonBit JS 模块，只需 Node.js 22+。
Windows 双击 `start-inspector.cmd`，其他系统运行 `node scripts/serve-offline.mjs`。

## 发布验证

源码验收见 [编解码与生成验收](codec-validation.md)：四后端每后端 101 项测试，native / JS CLI、
浏览器、固件回归、headless Chrome、hid-tools 0.12 的七份真实描述符与五种模板独立对照通过。
固定工具链为 MoonBit `0.10.14+7d59c7ec9`、moon `0.1.20260920`，另检查最新工具链。
发布命令完成包解压后的依赖安装与检查，Mooncakes 返回 `200 OK`。
离线包已通过 Node-only 启动、资源与 MIME、HEAD 和路径限制检查，`BUILD.json` 记录同一发布提交。
GitHub 上传后重新下载 ZIP 与 `SHA256SUMS.txt`，校验一致；解压下载包后再次运行相同启动检查通过。
`moonhid-inspector-v0.4.0.zip` 的 SHA-256：

```text
2be79478c9284a4a0746bd3d0e407323807df720a5507f4fcc7648b354eeb034
```

## 独立安装验收

仓库外新建 `installcheck/moonhid-040`，执行 `moon add We1chan/moonhid@0.4.0`，
实际从注册表下载版本 0.4.0，没有本地路径覆盖。Windows 11 上的 wasm / wasm-gc / JS / native
无警告检查通过，每后端 6/6 发布验收测试通过。

56 份模块配置、`src/` 下全部源码、测试、可执行文档、接口与包配置均与发布工作树逐字节一致，
换行归一化后也与发布提交一致。[完整记录](registry-0.4.0-validation.json) 保存文件 SHA-256、
CI 与 Pages 结果，以及离线 ZIP 与 GitHub 上传资产校验值。

## 独立安装复现

在仓库外创建项目，不配置本地路径覆盖：

```sh
moon new --user installcheck --name moonhid-040 moonhid-040
cd moonhid-040
moon add We1chan/moonhid@0.4.0
```

在该项目的 `moon.pkg` 增加以下导入：

```text
import {
  "We1chan/moonhid" @moonhid,
  "We1chan/moonhid/examples" @examples,
} for "test"
```

将 [验收测试源码](registry-0.4.0-test.mbt.txt) 保存为 `verify_test.mbt`，执行
`moon check --target all --deny-warn` 和 `moon test verify_test.mbt --target all`。
测试覆盖五种模板及 item 往返、按键/LED 字段编辑、三方向和多 ID、Null/物理量、超宽 Raw Feature 与 JSON v2。
