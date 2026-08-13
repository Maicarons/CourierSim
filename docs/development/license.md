# 开源与许可（AGPL）

## 一、主许可：AGPL-3.0

本项目以 **GNU Affero General Public License v3.0 (AGPL-3.0)** 发布，与 TransRoute 一致。

### AGPL-3.0 核心要点

| 要点 | 说明 |
|------|------|
| 可自由使用/修改/分发 | 保留原许可声明 |
| 源码公开 | 分发时提供完整对应源码 |
| **网络服务条款** | 若通过网络（SaaS）提供修改版，必须向**服务使用者**提供源码（AGPL 与 GPL 的关键区别） |
| 无担保 | 软件按"现状"提供，无任何担保 |

> 完整文本见仓库根目录 `LICENSE`。

### 为什么选 AGPL

- TransRoute 已采用 AGPL，保持一致性。
- 单机游戏为主，但若未来做多人/在线版，AGPL 的网络条款保护开源生态。

## 二、第三方依赖许可

| 依赖 | 许可 | 说明 |
|------|------|------|
| Godot 引擎 | MIT | 引擎本身，不影响游戏源码许可 |
| GUT | MIT | 测试框架 |
| OSM 地图数据 | ODbL 1.0 | 需署名，派生需同许可共享 |
| Geofabrik 数据 | ODbL | 同 OSM |
| OSRM | BSD-2-Clause | 开发期工具 |
| osmium | BSL-1.0 | 工具链 |
| 像素字体（Zpix 等） | SIL OFL | 字体 |
| 音效/音乐 | CC0 / CC-BY / 自产 | 逐项记录 |

## 三、数据许可注意事项（重要）

**OpenStreetMap 数据采用 ODbL 1.0**，这意味着：

1. **署名**：使用 OSM 数据需注明 "© OpenStreetMap contributors"。
2. **派生数据库**：烘焙产出的 `road_graph.json`、`distance_matrix.json` 等属于**派生数据库**，若公开分发，需按 ODbL 共享（或以等价开放许可发布）。
3. **像素瓦片**：由 OSM 矢量派生的像素地图属于派生作品，同样受 ODbL 约束。

**处理建议**：

- 在游戏内和文档中显著署名 OSM。
- 将烘焙数据单独置于 `data/regions/`，并附 ODbL 声明，与游戏代码（AGPL）分开标注许可。
- 若担心许可复杂性，可考虑用 **Natural Earth（Public Domain）** 提供低精度底图，OSM 仅用于高精度路网。

## 四、许可证文件清单

| 文件 | 内容 |
|------|------|
| `LICENSE` | AGPL-3.0 全文 |
| `assets/CREDITS.md` | 美术/音频/字体来源与许可 |
| `data/regions/README.md` | OSM 数据署名与 ODbL 声明 |
| `third_party/` | 第三方依赖清单 |
| 源码文件头 | 可选：每个源文件头注明 AGPL |

## 五、文件头模板

```gdscript
## CourierSim · 快递王国
## Copyright (C) 2026 项目作者
## 本文件按 AGPL-3.0 许可发布。
```

## 六、贡献者协议

- 采用 GitHub 标准 PR 流程。
- 贡献者提交即默认同意其代码按 AGPL-3.0 发布。
- 可后续引入 DCO（Developer Certificate of Origin）。

## 七、合规自检清单

- [ ] 根目录 `LICENSE` 为 AGPL-3.0 全文
- [ ] README 明确许可与署名
- [ ] OSM 数据署名（游戏内 + 文档）
- [ ] 派生数据附 ODbL 声明
- [ ] 素材许可记录完整（CREDITS.md）
- [ ] 第三方依赖许可不冲突
