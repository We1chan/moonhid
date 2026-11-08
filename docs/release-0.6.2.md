# MoonHID 0.6.2

0.6.2 补齐第三方材料声明并将其随发布包分发。库实现、公开 API、展示 JSON v2 和声明 v1 与 0.6.1 相同。

## 本次变更

- 固定 TinyUSB 参考基准为 0.21.0、提交 `dae3f9a366bfcddbf9dcf1b48d7500286a849539`，记录两个来源头文件、版权行、MIT 许可全文以及模板和宏展开测试数据清单。
- 新增 [NOTICE](../NOTICE)、[第三方材料声明](../THIRD_PARTY_NOTICES.md) 和 [示例数据来源说明](../examples/README.md)；登记实机采集数据、规范参考与构建测试依赖。
- 离线检查器随附 `LICENSE`、`NOTICE`、`THIRD_PARTY_NOTICES.md`；Mooncakes 安装验收逐文件比对这些声明和源码。
- 第三方声明检查接入 CI 与一键验收；固定工具链升级到 MoonBit 0.10.18，最新工具链任务仅豁免 derive 后置语法的弃用警告。
- README、安装说明和验收入口更新到 0.6.2。0.6.1 及更早版本的旧包缺少声明文件，复核本次整改应使用 0.6.2。

## 安装与复现

```sh
moon add We1chan/moonhid@0.6.2
```

```sh
git clone --branch v0.6.2 https://github.com/We1chan/moonhid.git
cd moonhid
moon update
node scripts/acceptance.mjs
```

工具链与可选依赖见 [验收说明](acceptance.md)。Windows 无 C++ 工具链时可运行 `node scripts/acceptance.mjs --quick`。

## 发布后复核

```sh
node scripts/verify-registry.mjs
node scripts/check-public-docs.mjs --urls docs/acceptance-urls.txt
```

注册表验收在仓库外新建项目，实际安装 0.6.2 并运行 [14 项公开 API 测试](registry-0.6.2-test.mbt.txt)，
在四后端检查功能，并将源码、README、LICENSE、NOTICE 和第三方声明与发布标签逐文件比较。
机器记录默认写入 `docs/registry-0.6.2-validation.json`。

正式交付入口为 [GitHub v0.6.2](https://github.com/We1chan/moonhid/releases/tag/v0.6.2)、
[Mooncakes 0.6.2](https://mooncakes.io/docs/We1chan/moonhid@0.6.2) 和 [在线检查器](https://we1chan.github.io/moonhid/)。
Release 附件提供预构建离线检查器、`SHA256SUMS.txt` 和发布验收机器记录。
