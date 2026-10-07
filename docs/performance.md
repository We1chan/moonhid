# 性能基准

```sh
node scripts/build-web.mjs
node --expose-gc scripts/benchmark.mjs > benchmark.json
```

包含七份 A–G 实际来源描述符、4096 Main 字段的合成描述符，以及 65536 个一位值的
8192 字节合成报告。每个任务预热两次，记录最小值、中位数和最大值。
测量范围是 JS bridge、JSON 序列化及 JSON 解析，不能当作纯编译器或纯解码器耗时。
启用 GC 时记录前后保留堆差值；它不是峰值内存或总分配量。

CI 保存每次测量的 JSON，不设依赖机器速度的通过阈值。
工具链版本见 `toolchain.json`；结果另包含 Node、系统、架构、提交及工作树修改状态。
大报告的结果用于确定后续分析方向，不能推断一般键鼠报告有相同开销。
