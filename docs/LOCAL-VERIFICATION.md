# 本地交付验证记录

日期：2026-11-11。项目版本：0.1.0。以下为本机实际检查，未代表远程 CI 或官方验收。

## 自动检查

`node scripts/verify.mjs` 全部成功：MoonBit 无警告检查、格式检查、Wasm / Wasm GC / JavaScript 三个目标各 9 项测试、Wasm GC 构建、命令行示例、JavaScript 核心构建，以及 20 项 Node 集成测试。

STUMPY 对照见 `evidence/stumpy-validation.json`，性能实测见 `evidence/benchmark.json`。输入集合、版本、常量规则与数值比较方式均由验证脚本记录，不把并列索引差异当作距离错误。

## 浏览器实际操作

- 导入 `examples/signal sample.csv`（文件名含空格），显示 8 个样本；窗口自动限制为 3，运行成功。
- 导出分析 JSON，读取导出文件确认 `ok=true`、窗口为 3、距离数组长度为 6。
- 从短文件切换至工业设备温度，显示 2,270 样本、窗口 48、2,223 个可比较窗口；参数文字与实际结果一致。
- 手机视口检查：页面可见宽度与内容宽度均为 375 CSS 像素，没有横向溢出。
- 切回合成信号，在“重复模式”中确认起点 96 与 336 的距离为 0，波形对比一致。
- 桌面与手机截图保存在 `output/playwright/`，截图中的耗时仅为当次浏览器运行。

## 打包

`moon package --list` 检查通过；生成包不包含 `.venv`、`node_modules` 或构建缓存。repository 元信息为空会提示警告，这是远程仓库尚未创建的真实状态。

本地交付包可用 `python scripts/package.py` 重建。它包含源码、编译好的 `web/core.js`、数据许可、验证证据及截图，排除开发依赖与 Git 元数据。解压后直接运行 `npm run demo`；修改 MoonBit 核心后需要先运行 `npm run build`。ZIP 使用完整性校验并附 SHA-256。

## 尚未执行

GitHub 公开发布、真实仓库地址配置、远程 CI、Mooncakes 发布、赛事报名与官方验收。
