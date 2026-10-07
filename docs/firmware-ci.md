# 将描述符检查接入固件 CI

这个可运行示例验证一个合成的 4 位方向开关，不代表真实手柄采集。
`examples/firmware-ci/descriptor-before.hex` 将逻辑范围设为 0–15，却声明 Null；
lint 在 Main item 的 @16 返回 `null_without_room`，CLI 退出 3。
`descriptor.hex` 改为 0–7，保留同一报告长度；`idle-report.hex` 的 `0f` 被解码为空闲值。
`expected.json` 冻结字段、原始值和 Null 判定，防止固件变更悄悄改变协议。

```sh
moon update
node scripts/firmware-ci.mjs
node scripts/firmware-ci.mjs native
```

检查器中展开“第一次使用”，可交互比较两个配置，点击提示定位对应字节。
Warning 提醒人工核对，不能仅凭提示认定设备违反协议；无提示也不能替代实机验证。

## 迁移到自己的固件仓库

1. 将 `examples/firmware-ci/` 复制为固件仓库中的 `hid-regression/`。
2. 用固件导出的描述符替换 `descriptor.hex`，保存一条真实或明确标为合成的
   Input 报告到 `idle-report.hex`，按该设备更新 `expected.json`。
3. 删除与自己的设备无关的 `descriptor-before.hex`；该文件存在时测试还要求它产生 Warning。
4. 将示例 `workflow.yml` 复制到 `.github/workflows/hid-regression.yml`。
   它从固定的 `v0.3.0` 获取 MoonHID，复制本仓库的样例，再执行实际 CLI。

`node scripts/firmware-ci.mjs js <case-directory>` 可指定其他案例目录。
这个示例对当前描述符要求没有 Warning，退出 3 会使 CI 失败。
若某个厂商协议有意产生提示，应先解释该提示，再为自己的工作流制定明确的放行规则。
参数/文件/编译错误分别保留 CLI 原有的 2/1 状态，不应当作 Warning 放行。
