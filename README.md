# MoonMatrixProfile

[![Verify](https://github.com/2973181701/moonmatrixprofile/actions/workflows/ci.yml/badge.svg)](https://github.com/2973181701/moonmatrixprofile/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](LICENSE)

> 纯 MoonBit 的时间序列分析库：找到相似波形、重复模式与异常候选，并用最近邻片段解释结果。

工业设备温度、能耗和服务指标往往是一长串数值。开发者除了想知道“某个值是否超过阈值”，还需要知道“这段变化以前出现过吗”“哪些工作周期最相似”“哪一段形状最少见”。

MoonMatrixProfile 将这类问题封装成可复用的 MoonBit 基础库。算法核心不联网、不读文件，只接收数组并返回结构化结果；命令行与浏览器使用同一份编译核心，文件读取与界面绘制由宿主负责。

## 项目目标

为 MoonBit 开发者提供一套可直接组合的**时间序列子片段最近邻分析能力**，覆盖距离计算、模式候选、输入处理和可解释结果，降低设备数据离线探索与原型开发的成本。

项目采用已有的 Matrix Profile / STOMP 方法。主要贡献是 MoonBit 实现、数值与输入边界处理、可复现的参考对照，以及共享核心的 CLI 和浏览器工具。项目与 [moongpx](https://github.com/2973181701/moongpx) 独立，不依赖其代码。

## 状态

**v0.1.0 首版功能已实现，并通过本地验证。** GitHub 自动检查由每次推送触发，实际运行结果以顶部徽章和 [Actions](https://github.com/2973181701/moonmatrixprofile/actions) 为准。

| 模块 | 状态与行为 |
| --- | --- |
| 自连接 Matrix Profile | 已实现；为每个窗口寻找排除邻近重叠区后的最近邻 |
| 有方向 AB-join | 已实现；在另一条序列中寻找每个 source 窗口的最近邻 |
| 单片段查询 | 已实现；返回查询片段与目标各窗口的距离 |
| 重复模式 / 异常候选 | 已实现；候选附最近邻位置，结果可查看波形依据 |
| 数值与无效输入处理 | 已实现；明确区分常量、缺失窗口与没有合法邻居 |
| CSV / JSON 接口与 CLI | 已实现；结构化错误、资源上限、明确退出码 |
| 浏览器交互演示 | 已实现；本地 Worker 计算、导入导出、移动端布局 |
| 自动测试与参考对照 | 本地通过；远程状态见 Actions |
| Mooncakes 包 | 尚未发布；暂不提供 `moon add` 安装命令 |

### 演示界面

![MoonMatrixProfile 桌面界面：原始序列、距离轮廓、重复模式与波形对比](docs/images/desktop.jpg)

合成信号包含起点 96 与 336 的相同片段。选择“重复模式”后可看到它们的零距离匹配；切换真实工业设备温度数据，可查看各个异常候选及其最近邻。[手机端截图](docs/images/mobile.jpg)。

## 为什么需要它

| 实际需求 | 提供的能力 | 解释结果时需要注意 |
| --- | --- | --- |
| 查找重复的设备工作周期 | 低距离窗口对 / motifs | 结果按波形形状比较，窗口长度由调用者选择 |
| 找到形状较少见的变化 | 高距离窗口 / discords | 它是异常候选，不能直接等同于设备故障 |
| 在历史数据中找一段波形 | 查询距离轮廓 | 可屏蔽查询原位置附近的平凡匹配 |
| 比较两次采集的序列 | 有方向 AB-join | source→target 与 target→source 含义不同 |
| 把分析放入 MoonBit 项目 | 数组 API 与 JSON 入口 | 不需要 Python 分析运行时或在线服务 |

## 快速上手

### 从源码运行

环境：MoonBit `moonc v0.10.20` 对应的稳定工具链，Node.js 22 或更新版本。Python 仅用于可选的参考对照与 ZIP 打包。工具链安装见 [MoonBit 官网](https://www.moonbitlang.com/download/)。早期本地记录使用 v0.10.14；公开源码已迁移到当前稳定版的 `#derive` 语法，旧版本需要更新后再构建。

```sh
git clone https://github.com/2973181701/moonmatrixprofile.git
cd moonmatrixprofile
moon test --target wasm-gc --deny-warn
moon run cmd/main
npm run build
npm test
npm run demo
```

打开 http://127.0.0.1:4173 。运行不需要 npm 第三方包。浏览器需要 HTTP 服务来加载模块和 Worker，不能直接双击 HTML。

### 从发布附件体验

在 [Releases](https://github.com/2973181701/moonmatrixprofile/releases) 下载 `MoonMatrixProfile-0.1.0.zip`，解压后进入 `moonmatrixprofile` 目录，运行 `npm run demo`。该附件包含预先编译的 `web/core.js`，只体验网页和 CLI 时不需要安装 MoonBit。

GitHub 自动生成的 “Source code” 压缩包与上述附件不同：它不包含编译核心，需要先运行 `npm run build`。

### 命令行

```sh
node cli.mjs profile examples/tiny.json --window 4
node cli.mjs profile "examples/signal sample.csv" --column value --window 3 --json
node cli.mjs query examples/tiny.json examples/query.json --json
node cli.mjs abjoin examples/tiny.json examples/tiny.json --window 4 --json
```

命令行退出码：0 成功、1 输入/计算错误、2 未知命令。JSON 文件为数值数组，`null` 表示缺失。CSV 首行是表头，必须明确列名；空单元格、`NA`、`NaN`、`null` 保留为缺失样本。CSV 数值采用 JSON 数字语法，包括负数、小数与指数，不接受前导加号。

## MoonBit API

在当前源码的其他包中导入 `2973181701/moonmatrixprofile`，示例见 `cmd/main/`。

```moonbit nocheck
let series = [0.0, 1.0, 0.0, -1.0, 0.0, 1.0, 0.0, -1.0]
let profile = @mp.matrix_profile(series, 4).unwrap()
let repeated = @mp.motifs(profile, 2).unwrap()
let unusual = @mp.discords(profile, 2)
```

| 接口 | 行为 |
| --- | --- |
| `matrix_profile(series, window, exclusion_zone?, max_pairs?)` | 自连接，默认排除距离不超过 `ceil(window/4)` 的邻近窗口 |
| `ab_join(source, target, window, max_pairs?)` | 有方向的跨序列连接，每个 source 窗口在 target 中寻找邻居；不排除自身匹配 |
| `distance_profile(query, target, max_pairs?)` | 查询片段与目标所有等长窗口的距离 |
| `motifs(profile, count)` | 自连接 profile 中互不重叠的低距离对；AB-join 返回错误 |
| `discords(profile, count)` | 互不重叠的高距离窗口及其邻居 |
| `parse_csv(text, column)` | 具名数值列解析，支持引号、转义、CRLF 与字段内换行 |
| `profile_to_json(profile)` | 将缺失距离与索引明确编码为 JSON null |
| `analyze_json(request)` | CLI/浏览器共用的结构化请求入口 |

完整签名由 `moon info` 生成在 `pkg.generated.mbti`。

### 返回结果

`Profile` 的距离数组和索引数组按窗口起点对齐；`Match` 记录被选片段、邻居起点及两者距离。

```moonbit nocheck
pub struct Match {
  index : Int
  neighbor : Int
  distance : Double
}
```

`valid[i]=false` 表示第 i 个窗口含无效值；`valid[i]=true` 但距离与索引为空，表示该窗口本身合法，却没有可比较的邻居。JSON 中缺失项编码为 `null`。

### JSON 请求

CLI 与浏览器的计算入口都是 `analyze_json`。例如：

```json
{
  "op": "profile",
  "series": [0, 1, 0, -1, 0, 1, 0, -1],
  "window": 4,
  "count": 2
}
```

支持 `profile`、`abjoin`、`query`、`parse` 四类操作；成功返回 `ok: true`，失败返回 `ok: false` 和含 `code`、`message` 的 `error` 对象。完整行为由 `json_api.mbt` 和集成测试约束。

## 设计取舍

### 用形状相似度回答模式问题

距离采用 **z 标准化欧氏距离**：先在窗口内减去均值、除以总体标准差，再计算两段波形的距离。因此正比例缩放和平移后的同形状片段通常仍然匹配。绝对温度越界、峰值超标等问题应由调用者另行判断。

### 递推点积，同时处理数值误差

自连接只扫描排除区之外的上三角对角线，并利用对称性更新两侧最近邻；沿对角线递推点积，每 128 次移动重新计算。窗口统计使用 Welford 累积，输入先进行统一条件化；低方差、近似相同的窗口使用直接距离回退。

实现不保存完整窗口距离矩阵，额外空间为 O(n_source+n_target)。常规连接扫描近似 O(AB)，预处理、周期性重算及大量数值回退会增加工作；最坏可达到 O(ABm)。详细推导与资源限制见 [算法说明](docs/ALGORITHM.md)。

### 一个核心，多个入口

MoonBit 负责距离、最近邻、模式候选、CSV 解析和 JSON 协议。Node 负责 I/O，浏览器负责绘图，并在 Worker 中运行同一编译产物。STUMPY 仅用于开发验证，不参与日常运行。

## 含义与边界

- 窗口按样本数计，索引从 0 开始。窗口至少 3 个样本。调用者需要自己保证采样间隔适合比较。
- 距离是 **z 标准化欧氏距离**，反映形状相似度，对正比例缩放与平移基本不敏感。它不会直接反映温度越界或幅度变化。
- 非有限数值使覆盖它的窗口无效，不做插值。`valid=false` 表示无效输入窗口；`valid=true` 且距离/索引为空表示没有合法邻居。
- 两个精确常量窗口距离为 0；仅一个为常量时距离为 `sqrt(window)`。常量判定是精确相等，与 STUMPY 默认绝对阈值不同。
- 距离并列容差为 `1e-10 * (1 + current_distance)`，容差内优先较小的邻居索引。
- 重复模式从一邻居 profile 中选择，要求两端及已选择的其他片段不重叠；不声称穷举了全部 k-motif。
- 首版为离线单变量分析。没有增量流式 API、多变量分析、GPU、自动窗口选择或故障概率校准。
- 默认 `max_pairs=25,000,000`，同时保守限制连接候选数和每侧预处理工作量。JSON/CSV 边界限制见 [算法说明](docs/ALGORITHM.md)。

## 验证与性能

```sh
node scripts/verify.mjs
python -m venv .venv
# Windows: .venv\Scripts\python.exe；其他系统: .venv/bin/python
.venv\Scripts\python.exe -m pip install -r requirements-validation.txt
.venv\Scripts\python.exe scripts/validate_stumpy.py
npm run bench
```

STUMPY 只用于开发对照，不是库、CLI 或网页运行所需依赖。对照采用固定随机种子、显式常量规则及条件化输入，检查距离和返回邻居的实际距离；不要求并列邻居的索引与 STUMPY 相同。

实际结果保存在 [evidence/](evidence/)。性能脚本包含 JSON 边界开销，说明环境、预热和重复次数。它不代表与 Python、Rust 或其他实现的速度排名。

### 已取得的本地证据

| 验证 | 实际结果 |
| --- | --- |
| MoonBit 单元测试 | Wasm / Wasm GC / JavaScript 三个目标各 9 项通过 |
| Node 接口与 CLI 集成 | 20 项通过，含真实文件路径、输入错误与 JSON 语义 |
| STUMPY 1.14.1 对照 | 64 组案例、5,037 个窗口通过 |
| 对照最大距离绝对误差 | 约 2.91e-10；该数值只描述固定对照集合 |
| 浏览器操作 | 导入、导出、真实数据切换和手机布局已验证 |

对照覆盖随机自连接 / AB-join、偏置 1e12、小尺度、常量、线性、重复与缺失样本。参考实现显式采用相同常量规则及条件化输入；这不是未经处理的任意默认参数对比。

浏览器导入、导出和手机布局的实际操作记录见 [本地交付验证](docs/LOCAL-VERIFICATION.md)。`python scripts/package.py` 可生成带编译核心的本地交付 ZIP，输出到项目相邻的 `deliverables/` 目录；解压后可直接运行 `npm run demo`。

## 数据、来源与贡献

演示包含项目生成的合成信号，以及 NAB 真实工业设备温度数据。真实数据保留原 CSV、来源提交与 SHA-256；交互视图每 10 点取 1 点并明确标注，未作平均。见 [数据来源](web/data/SOURCES.md)。真实数据演示不是完整 NAB 检测基准评分。

Matrix Profile/STOMP 是已有研究方法。本项目的工作是 MoonBit 中的独立实现、可解释接口、数值与输入边界、可复现对照及交互工具；不宣称新算法或未经确认的生态首创。参考与许可见 [NOTICE](NOTICE.md)，参赛边界见 [项目申报说明](docs/SUBMISSION.md)。

源码采用 Apache-2.0，第三方数据保留其单独许可。

## 项目结构

| 路径 | 职责 |
| --- | --- |
| `statistics.mbt` / `profile.mbt` | 数值预处理、距离与对角线最近邻扫描 |
| `discovery.mbt` | 重复模式与异常候选提取 |
| `csv.mbt` / `json_api.mbt` | 输入解析与共享协议 |
| `bridge/` / `cmd/main/` | JavaScript 导出与 MoonBit 示例 |
| `cli.mjs` / `web/` | 命令行和交互演示 |
| `scripts/` / `tests/` / `evidence/` | 构建、检查、参考对照与实测记录 |
| `docs/` | 算法说明、交付验证与参赛材料 |

## 开发与贡献

```sh
moon info
moon fmt
node scripts/verify.mjs
```

提交问题时，请附最小输入、窗口长度、工具链版本、期望行为与实际结果。修改数值逻辑时应同时验证返回距离和邻居对应的真实距离；不要仅因并列邻居索引不同就认定算法错误。

GitHub Actions 会重跑构建、三个目标的测试、Node 集成测试及 STUMPY 对照。远程环境的运行结果独立于本地记录，以实际完成的检查为准。
