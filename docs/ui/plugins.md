# Godot UI / 地图 / 图标资源调研报告

> 调研日期：2026-08-13 · 引擎版本：Godot 4.7.1
> 适用对象：CourierSim 快递王国（2D 像素卡通管理模拟经营）以及后续类似风格项目

## 一、UI 插件推荐

### 1. Tooltips Pro（推荐 — 已收录在调研清单，备选）

- **地址**：[Godot Asset Library #4026](https://www.godotengine.org/asset-library/asset/4026)
- **许可**：Proprietary（需付费授权）；社区资源库中可下到 1.0/1.1 试用版
- **核心能力**：可为任意 Control / 2D / 3D 节点注册 tooltip；CK3 式嵌套 tooltip、Endless Legend 2 式 pin tooltip；String 占位符 + 实时更新；多语言、本地化、动画支持
- **对 CourierSim 的价值**：与我们自研的 `Tooltips` 单例思路一致，可作为后续升级；当需要嵌套 tooltip（如 tooltip 内嵌图标按钮）时可直接引入
- **采用建议**：当前自研 `Tooltips.gd` 已覆盖 hover/延迟/位置自动避屏等 80% 需求；Tooltips Pro 可作为进阶

### 2. Dialogic 2（强烈推荐给叙事向项目）

- **地址**：[github.com/dialogic-godot/dialogic](https://github.com/dialogic-godot/dialogic)（[Asset Library](https://godotengine.org/asset-library/asset)）
- **许可**：MIT 开源
- **核心能力**：可视化时间线编辑器、分支对话、角色立绘/表情、变量系统、子系统扩展、自定义事件、与 Godot 视觉脚本集成、多语言
- **对 CourierSim 的价值**：我们目前用 `TutorialSystem` + `DialogueBox` 手写了一套最小教程/对白系统（8 段剧情）；若后续要加入完整 NPC 支线、城市拜访剧情、可选职业剧情，Dialogic 2 是省时利器
- **采用建议**：当前体量不需要引入；若超过 20 段对话 / 需要分支选项时迁移

### 3. GUT（Godot Unit Test）

- **用途**：单元测试、UI 集成测试、回归测试
- **对 CourierSim 的价值**：核心系统（订单/车辆/科技/财务）有大量状态机与计算逻辑，目前零测试覆盖；引入 GUT 后可在 CI 自动验证
- **采用建议**：建议下个迭代补齐核心系统测试

## 二、地图插件 / 地理数据方案

### 1. godot-openstreetmap

- **地址**：[github.com/locherunderscore/godot-openstreetmap-v4.1.2](https://github.com/locherunderscore/godot-openstreetmap-v4.1.2)（社区 4.x 移植）
- **许可**：MIT
- **能力**：OSM 数据渲染为 3D 场景；含建筑、道路、地形
- **对 CourierSim 的价值**：3D 写实风格，我们做的是 2D 卡通 + 战略视角，**不直接适用**；但思路可借鉴（从 OSM PBF → 烘焙 → 运行时零依赖）

### 2. Terrain3D / HTerrain（高度图地形系统）

- **地址**：C++ GDExtension，适合大规模 3D 地形
- **对 CourierSim 的价值**：不适合——我们是 2D 等距投影 + 战略地图，不需要 3D 地形

### 3. **CourierSim 自研方案（推荐）**

- **数据源**：
  - **Natural Earth 50m land**：海岸线/陆地多边形（Public Domain）
    - 下载：[cdn.jsdelivr.net/gh/nvkelso/natural-earth-vector@master/geojson/ne_50m_land.geojson](https://cdn.jsdelivr.net/gh/nvkelso/natural-earth-vector@master/geojson/ne_50m_land.geojson)
  - **OSM / Geofabrik / Overpass**：城市 POI、道路、行政区（ODbL）
  - **Nominatim**：地理编码（ODbL）
  - **OSRM**：真实路网距离/用时（兜底用球面 Haversine）
- **烘焙链路**（`tools/bake_land.py` + `tools/bake_terrain.py`）：
  1. 区域 JSON（城市经纬度） → 包围盒
  2. Natural Earth 50m 陆地多边形 → Sutherland-Hodgman 裁剪到区域 bbox → Douglas-Peucker 简化 → `<id>_land.json`
  3. PIL 光栅化多边形 → 像素噪声地形色（grass/hill/sand）→ `<id>_terrain.png`
- **运行时零依赖**：MapView 直接 load PNG（按 bbox 拉伸）+ 读取海岸线 JSON 描边
- **可复现**：所有数据脚本在 `tools/`，刷新一次约 1-2 秒

## 三、图标资源库

### 1. **ComfyUI 自研（推荐 · 项目当前方案）**

- **工作流**：`comfyui/nintendo_pixel_asset_workflow.json` + `gen_ui_icons.py` / `gen_ui_icons_v2.py`
- **链路**：Ernie Image Turbo 文生图 → PerfectPixel 像素网格 → BiRefNet 抠图 → 16 色调色板 → 透明 PNG
- **许可**：本项目内自用，无外部授权问题
- **当前已生成**：27 个 UI 图标（v1 12 + v2 15），全部 Nintendo 8-bit 风格、512×512、透明背景、粗黑边
- **优势**：风格统一、可复现、可批量；提示词模板保证视觉一致

### 2. Kenney（强烈推荐备选）

- **地址**：[kenney.nl](https://kenney.nl)
- **许可**：**CC0**（Public Domain）— 完全免费商用、可修改、无需署名
- **覆盖**：40000+ 资源（角色、平台跳跃套件、Tiny Town、Tiny Farm、UI Pack、Input Prompts、游戏图标字体）
- **对 CourierSim 的价值**：当我们需要更复杂的图标（如建筑物外观、特殊载具、装饰性小物件）时，可从 Kenney 提取单色 SVG 重新上色
- **风格匹配度**：UI Pack 的简洁平涂风格与我们自研 8-bit 风高度一致

### 3. game-icons.net

- **地址**：[game-icons.net](https://game-icons.net)
- **许可**：**CC BY 3.0**（需署名）— 商用允许，需修改或衍生
- **覆盖**：2000+ 单色矢量游戏图标（动作/物品/技能）
- **对 CourierSim 的价值**：丰富的「动作类」图标（升级/建造/卖出/调查等），可作为精修图标补充；本项目自研图标后剩余的边角功能可从这里取
- **注意**：单色 SVG，需自行上色到我们的卡通调色板

### 4. OpenGameArt

- **地址**：[opengameart.org](https://opengameart.org)
- **许可**：按作品过滤（CC0 / CC-BY / CC-BY-SA / GPL）
- **覆盖**：海量 2D 像素资源（角色、Tilesets、UI）
- **对 CourierSim 的价值**：NPC 头像、立绘素材；按 CC0 过滤后可直接使用

## 四、本项目最终采用方案

| 类别 | 选择 | 原因 |
|---|---|---|
| UI 基础控件 | **自研 `widgets.gd` + Tooltips 单例** | 完全可控、风格统一；管理模拟类游戏不需要太复杂控件 |
| Tooltip | **自研 `src/ui/Tooltips.gd`** | 与未来 Tooltips Pro 升级路径清晰；不引入专有依赖 |
| 对白/教程 | **自研 `TutorialSystem` + `DialogueBox`** | 体量小（8 段）、数据驱动、易扩展；后续可迁移 Dialogic 2 |
| 地图渲染 | **自研 `MapView` + Natural Earth 烘焙** | 2D 战略视角、零运行时网络、风格化卡通地形 |
| 地理数据 | **Natural Earth 50m + OSM**（ODbL/Public Domain） | 公开数据可复用；与 TransRoute 一致 |
| 图标 | **ComfyUI 自研 + Kenney 备选** | 风格统一、可批量、零授权问题 |

## 五、参考链接

- Godot 官方 Asset Library：<https://godotengine.org/asset-library/>
- Dialogic 2 文档：<https://github.com/dialogic-godot/dialogic>
- Natural Earth 数据集：<https://www.naturalearthdata.com/>
- OpenStreetMap 派生数据：<https://www.openstreetmap.org/>
- Geofabrik 下载：<https://download.geofabrik.de/>
- Kenney 免费游戏素材：<https://kenney.nl/>
- game-icons.net：<https://game-icons.net/>