# 网页报告编辑

检查器支持 Input / Output / Feature 报告初始化、按字段与元素写入，以及完整报告 HEX 导出。
该功能从 0.6.0 起提供，[在线检查器](https://we1chan.github.io/moonhid/) 和 Release 离线包都可以直接使用。
这项能力用于离线构造字节，设备 Output/Feature 传输仍在 [开发路线](../ROADMAP.md) 中。

## 启动与操作

在仓库根目录执行：

```sh
node scripts/build-web.mjs
python3 scripts/serve-web.py
```

Windows 可将 `python3` 换为 `python`。打开 <http://127.0.0.1:8765/>。

1. 载入样例或粘贴描述符，选择方向与 Report ID。
2. 点击「初始化报告」，或输入已有的完整报告。初始化写入 ID 前缀、可表示的 Null 值与数组空闲值，其余位清零，规则与核心 `new_report` 一致。
3. 在字段值表中点击要修改的元素，或选择字段后输入元素索引。多元素字段从 0 计数，远处元素会联动到对应值表页。
4. 在右侧填写值，点击「写入报告」或按 `Ctrl/⌘ + Enter`。原始报告、位布局和解码值立即同步更新。
5. 点击「导出报告 HEX」保存完整字节；「导出 JSON」保存描述符、当前方向/ID、完整报告与解码值。

各方向与 ID 的报告草稿分别保留。实时 WebHID 接收期间，先断开设备再编辑，避免下一帧覆盖修改。
初始化会替换当前报告；逐字段写入只替换目标元素，保留其他字段、Constant、尾部未用位和 ID 前缀。
初始化不是生成全部业务数据：没有可表示 Null/空闲值的字段仍为零，零超出 Logical 范围时继续显示越界标记。

## 键盘 LED 示例

1. 载入「键盘」样例，切到 Output，点击「初始化报告」，得到 `00`。
2. 在值表选 Caps Lock，或选择字段 #3 的元素 1，填入十进制 `1`，点击「写入报告」。结果为 `02`。
3. 选择 Num Lock（同字段元素 0），写入 `1`，得到 `03`。Caps Lock 保持开启。
4. 导出的 `moonhid-output-0.hex` 内容为 `03` 加换行；无 ID 的报告不添加传输层的额外 `00`。

若先输入报告 `e0`，再将 Caps Lock 写为 `1`，结果为 `e2`：上方三位 Constant 保持原值。
写入 `2` 会触发 `value_range`，报告继续保持 `e2`，错误文本保留以便修改。

## 值类型与错误

| 字段 | 编辑方式 | 校验 |
| --- | --- | --- |
| 1..32 位 Variable | 十进制整数，支持负数与完整 uint32 | 位宽、有符号性、Logical 范围；Null 字段允许可表示的范围外值 |
| Array | 每个槽位填写十进制选择器整数 | 根据 `value - logical_min` 映射 Usage；界面同步显示选中的按键或未映射状态 |
| 超过 32 位的 Variable | 原始十六进制字节 | 长度匹配元素位宽，末字节未用高位为零 |
| Buffered Bytes | 一次填写整个 Main 字段的十六进制字节流 | 精确匹配 `Report Size × Report Count / 8` 字节，元素索引固定为 0 |
| Constant | 只读 | 修改数据元素时保留这些位 |

错误沿用核心诊断，例如 `value_type`、`value_range`、`logical_range`、`element_index`。
解析字节文本错误时显示字符偏移；字段校验错误通常指向声明字段的描述符字节位置。
任何错误均不提交新报告。编辑描述符会立即禁用旧字段和导出；原始报告无效或待解码时禁用字段写入和 HEX 导出。
超宽普通字段仍属于 [兼容说明](hid-compatibility.md) 记录的宽松扩展。

桥接 API、成功/失败 JSON 与导出文件约定见 [JSON v2](json-v2.md#浏览器桥接与下载文件)。

## 自动验收

```sh
node scripts/build-web.mjs
node scripts/test-web.mjs
node scripts/test-inspector.mjs
node scripts/package-inspector.mjs
node scripts/test-offline.mjs
```

DOM 回归需要 Chrome 与 Python，可通过 `CHROME_BIN`、`PYTHON` 指定程序路径。
两组新增回归沿用现有 JS CI，覆盖初始化、整数边界、Array/Null、三方向 Buffered Bytes、
跨字节写入、Constant/尾位/ID 保留、错误时保留报告、多元素分页、独立草稿和 HEX/JSON 导出。
DOM 还检查 1440、1100、390 宽度和浅深色主题，并验证实时输入时编辑禁用、断开后恢复。
这些证据使用合成描述符和模拟设备；既有真实设备与 Xbox 数据回放继续独立运行。
