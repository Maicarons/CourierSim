# CourierSim · 快递王国

> 2D 像素卡通任天堂风快递公司模拟经营游戏 · Godot 4.7 + 真实地理数据

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](LICENSE)

一款以**真实地理数据**为骨架的快递公司模拟经营游戏。玩家从一辆面包车和一间总部仓库起步，通过车辆购置调度、中转仓库建设、站点覆盖规划、市场推广与精细化运营，成长为跨国物流帝国。

## 特性

- **真实世界地图**：韩国 16 城首发（海南/越南/马来西亚数据已就绪），海岸线与陆地来自 Natural Earth 50m（Public Domain）离线烘焙，运行时零网络。
- **像素卡通表现**：任天堂 8-bit 风格，全部美术由 ComfyUI 工作流批量生成（透明底 + 粗黑边 + 16 色调色板）。
- **图标驱动 UI**：全图标 + 悬停 Tooltip，管理模拟类信息层级（顶栏状态 + 分组 Tab + 中央内容）。
- **深度经营模拟**：车辆、仓库、站点、市场、订单、财务、员工、科技、事件、多对手 AI 竞争、成就系统。
- **双模式**：生涯模式（8 段剧情教程 + 评级 S/A/B/C + 通关结算）+ 沙盒模式（自由经营）。
- **多槽位存档**：9 槽位 + 活跃槽位绑定，主菜单槽位选择面板。
- **双语言**：简体中文 / English 运行时切换。

## 运行

```bash
# Godot 4.7.1（Editor 模式打开 project.godot 后按 F5 运行）
# 或命令行无头验证：
godot --headless --path . --quit
```

## 仓库结构

| 目录 | 说明 |
|------|------|
| `src/` | Godot 工程（autoload 单例 / core 数据模型 / systems 子系统 / ui / scenes / map 数据 / i18n） |
| `assets/` | 生成素材（图片 73+ / 音频 10） |
| `comfyui/` | ComfyUI 工作流与批量生成脚本（像素图标/角色/建筑/音频） |
| `tools/` | 离线烘焙与开发工具（地图数据 / i18n 合并 / 无头回归测试 / 平衡模拟） |
| `docs/` | VitePress 设计文档站（完整开发规划与实现说明） |
| `LICENSE` | AGPL-3.0 |

## 无头回归测试

```bash
godot --headless --path . res://tools/smoke_test.tscn --quit-after 300
godot --headless --path . res://tools/balance_sim.tscn --quit-after 400   # 120 天平衡模拟
```

## 文档站

```bash
cd docs
npm install
npm run dev      # http://localhost:5173
npm run build    # 构建到 docs/.vitepress/dist
```

## 版本历史

| 版本 | 里程碑 |
|------|--------|
| v0.4 | UI/UX 全面重做（图标驱动 + 生涯教程 + 真实地图） |
| v0.5 | 评级/结算、多槽位存档、多对手竞争、事件扩展 |
| v0.6 | ESC 暂停菜单、确认弹窗、成就系统、竞争修正、导出预设 |
| v0.7 | 数值平衡长局模拟与调优、CI、仓库工程化 |

## 许可证

本项目以 **GNU Affero General Public License v3.0 (AGPL-3.0)** 发布。详见 [LICENSE](LICENSE)。

地图数据：Natural Earth（Public Domain）、OpenStreetMap（© OpenStreetMap contributors，ODbL）。
