# 演示数据来源

**工业设备温度（真实数据）**

- 来源：Numenta Anomaly Benchmark，`data/realKnownCause/machine_temperature_system_failure.csv`。
- 固定提交：`ea702d75cc2258d9d7dd35ca8e5e2539d71f3140`。
- 原始文件：[GitHub 固定版本](https://github.com/numenta/NAB/blob/ea702d75cc2258d9d7dd35ca8e5e2539d71f3140/data/realKnownCause/machine_temperature_system_failure.csv)。
- 本地副本：`machine_temperature.csv`，22,695 条原始记录。SHA-256：`92bf5b87fc7f9bba8ca0b7ec63ccaac8cb4a1371a258e8c29a10ae9c018d82a4`。
- 许可：上游仓库 MIT，完整文本保存在 `NAB-LICENSE.txt`，原作者 Copyright 2014–2024 Numenta Inc.。
- 浏览器预设每 10 点取 1 点，共 2,270 点；不是平均降采样。JSON 保留原始索引与时间戳。`python scripts/prepare_data.py` 可复现该处理。
- 数据描述参见 [上游数据说明](https://github.com/numenta/NAB/blob/ea702d75cc2258d9d7dd35ca8e5e2539d71f3140/data/README.md)。本项目未以这一个抽样视图声称完成 NAB 流式检测评测或达到任何故障检测准确率。

**合成信号**

本项目使用固定种子 73183 生成 768 点；在位置 96 与 336 放入相同的 48 点片段，在 550–585 注入交替扰动。其作用是解释重复与罕见形状，不能当作真实世界检测精度的证明。实现见 `web/app.js`，采用项目源码许可。

**用户导入数据**

CSV/JSON 文件由浏览器本地读取、Worker 本地计算，不发送到服务器。用户导出文件包含结果和来源摘要；不自动发布或共享。
