# MoonMatrixProfile v0.1.0

MoonBit 时间序列模式发现与异常候选分析库的首个公开版本。

## 功能

- 纯 MoonBit 自连接 Matrix Profile、有方向 AB-join、单片段距离查询。
- 重复模式与异常候选提取，返回最近邻位置和标准化距离。
- 常量、缺失值、无邻居、并列结果和输入资源边界的明确处理。
- CSV 数值列解析、JSON 接口、命令行工具与浏览器交互演示。
- 合成信号与有来源、校验值、许可的 NAB 工业设备温度数据。

## 快速体验

下载附件 `MoonMatrixProfile-0.1.0.zip` 并解压，安装 Node.js 22 或更新版本后，在 `moonmatrixprofile` 目录运行：

```sh
npm run demo
```

访问 http://127.0.0.1:4173 。附件已包含编译核心，无需安装 npm 第三方依赖。GitHub 自动生成的 Source code 压缩包只有源码，需要先安装 MoonBit 并运行 `npm run build`。

命令行示例：

```sh
node cli.mjs profile examples/tiny.json --window 4 --json
```

## 验证

- 本地 Wasm / Wasm GC / JavaScript 三个目标各 9 项 MoonBit 测试通过。
- 本地 20 项 Node 接口与命令行集成测试通过。
- STUMPY 1.14.1 对照：64 组案例、5,037 个窗口通过，最大距离绝对误差约 2.91e-10。
- CSV 文件导入、分析 JSON 导出和手机布局经过浏览器操作验证。
- GitHub 自动检查状态见仓库 Actions；本地结果与远程结果分别记录。

## 使用边界

首版用于离线单变量形状比较；异常候选不等于故障概率。未实现流式、多变量、GPU 或自动窗口选择，也未提交完整 NAB 检测成绩。算法采用既有 Matrix Profile/STOMP 方法，贡献是 MoonBit 实现及配套工程，不宣称新算法或未经确认的生态首创。

源码采用 Apache-2.0；第三方数据保留其单独许可。Mooncakes 包尚未发布。
