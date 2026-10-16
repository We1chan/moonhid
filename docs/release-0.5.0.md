# MoonHID 0.5.0

0.5.0 将 HID 1.11 Main item bit 8 的 Buffered Bytes 纳入报告编解码，
修复 0.4.0 拒绝标准已定义字节流的问题。[PR #34](https://github.com/We1chan/moonhid/pull/34)
已经审阅并合并，标准条款与三方向案例见 [HID 1.11 兼容目标](hid-compatibility.md)，
补充申报可使用 [初审反馈回复](hackathon-review-response.md)。

## 本版本内容

- Input、Output、Feature 均支持 Buffered Bytes，保留 Report ID、固定长度、原始字节及 Size/Count。
- 每个 Main item 编码为一个 `Raw(Bytes)`，解码进入 `DecodedReport.buffered_values`；
  数值、Array、Null 与物理量规则不解释缓冲区内容。
- 检查起始位与长度按字节对齐，长度和类型错误明确返回诊断。
- 字段与 Usage 访问、初始化、lint、CLI、JSON v2、浏览器显示和 WebHID 参考描述符使用一致规则。
- 增加九组回归测试、README 可执行示例和固定种子的 128 个布局、384 个混合报告。

## 从 0.4.0 升级

```sh
moon add We1chan/moonhid@0.5.0
```

`DecodedReport` 新增公开字段 `buffered_values`。手工构造该结构体时需增加此数组，
没有缓冲区时为 `[]`；因此本次提升到 0.5.0。既有函数签名、整数与超宽 Variable 值的语义不变。
JSON schema 仍为 v2，新增 `buffered_values` 数组，旧 v2 缺少时按空数组处理。

Buffered Bytes 的 `Raw` 必须是整个 Main item 的精确长度；字段接口的元素索引为 0。
按 Usage 访问整段流时使用该 Main item 的首个 Usage。详见 [编解码契约](codec.md)。

## 发布与交付入口

- [Mooncakes 模块](https://mooncakes.io/docs/We1chan/moonhid)
- [GitHub Release 与离线检查器](https://github.com/We1chan/moonhid/releases/tag/v0.5.0)
- [在线检查器](https://we1chan.github.io/moonhid/)

离线包 `moonhid-inspector-v0.5.0.zip` 包含编译好的 JS 模块，需要 Node.js 22+。
解压后运行 `node scripts/serve-offline.mjs`；Windows 也可双击 `start-inspector.cmd`。
`BUILD.json` 记录构建提交，`SHA256SUMS.txt` 校验下载文件。

## 验证与边界

PR 审阅复验通过四后端无警告检查、每后端 112 项测试，以及 native / JS CLI、
browser bridge、WebHID 参考描述符与原有设备回归；[源码验收](buffered-bytes-validation.md)
另记录浏览器、固件、离线包和既有 hid-tools 对照。
Buffered Bytes 的案例来自标准语义和离线合成数据，不包含新硬件采集或 Output/Feature 实机发送。

## 独立安装复现

在仓库外创建项目，不设置本地依赖覆盖：

```sh
moon new --user installcheck --name moonhid-050 moonhid-050
cd moonhid-050
moon add We1chan/moonhid@0.5.0
```

在该项目的 `moon.pkg` 声明测试导入：

```text
import {
  "We1chan/moonhid" @moonhid,
  "We1chan/moonhid/examples" @examples,
} for "test"
```

将 [验收测试源码](registry-0.5.0-test.mbt.txt) 保存为 `verify_test.mbt`，运行：

```sh
moon check --target all --deny-warn
moon test verify_test.mbt --target all
```

九项验收测试覆盖旧版的模板、按键/LED、Null、物理量和超宽值，
以及三方向 Buffered Bytes、JSON、Usage 访问、相邻位保留、对齐、非 8 位 Size 和最大报告。
