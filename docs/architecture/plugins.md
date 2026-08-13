# 插件与第三方库

按用途推荐 Godot 插件与第三方库，标注是否必需、许可与用途。

## 一、地图与地理

| 插件/库 | 用途 | 许可 | 优先级 |
|---------|------|------|--------|
| **GDScript 原生 TileMapLayer + TileSet** | 像素地图渲染（自研，无需插件） | 内置 | 必需 |
| [MapTileProvider](https://godotengine.org/asset-library/asset/2987) | 加载真实地图瓦片（可选，用于开发期参考底图） | MIT | 可选 |
| [godot-geo-tile-loader](https://github.com/pka/godot-geo-tile-loader) | 加载 Mapbox 矢量瓦片（Rust 扩展） | MIT | 可选 |
| **OSRM**（外部服务/Docker） | 真实路网距离/用时计算 | BSD-2 | 开发期 |

> **核心结论**：像素地图以自研 TileMapLayer 为主，真实地图瓦片插件仅作开发期参考/底图对照，不进入正式表现层（因为要"像素卡通"风格，而非真实卫星图）。

## 二、寻路与导航

| 方案 | 说明 | 优先级 |
|------|------|--------|
| **AStar2D**（内置） | 城市/站点级路网寻路，加权图 | 必需 |
| **AStarGrid2D**（内置） | 规则网格寻路（建筑摆放） | 必需 |
| NavigationServer2D（内置） | 精细导航网格（可选，移动端优化场景） | 可选 |

> 大世界建议**分层寻路**：区域层（城市间，AStar2D 粗粒度）→ 局部层（站点内/道路，AStarGrid2D），性能可从 45ms 优化到 3ms（见调研结论）。

## 三、存档系统

| 方案 | 说明 | 优先级 |
|------|------|--------|
| **自研 JSON + FileAccess** | 版本迁移 + 原子写 + 多槽位（见 [存档系统](/architecture/save-system)） | 必需 |
| [Godot 官方 Saving Games 教程](https://docs.godotengine.org/en/4.0/tutorials/io/saving_games.html) | 参考实现 | 参考 |
| ConfigFile（内置） | 仅存设置（音量/键位），不存进度 | 辅助 |

> 结论：存档用自研 JSON 方案，不引入第三方（存档格式要可控、可迁移）。

## 四、UI 与交互

| 插件/库 | 用途 | 许可 | 优先级 |
|---------|------|------|--------|
| **Godot 内置 Control 节点** | 面板/按钮/滚动（自研 UI） | 内置 | 必需 |
| [Godot UI 主题](https://github.com/godotengine/godot-themes) | 像素风 UI 参考 | MIT | 参考 |

## 五、测试与调试

| 工具 | 用途 | 许可 | 优先级 |
|------|------|------|--------|
| [GUT](https://github.com/bitwes/Gut) | GDScript 单元测试框架 | MIT | 必需 |
| Godot 内置 Profiler / Debugger | 性能剖析 | 内置 | 必需 |
| [gdUnit4](https://github.com/MikeSchulze/gdUnit4) | 更强的 GDScript 测试（可选替代） | MIT | 可选 |

## 六、动画与特效

| 方案 | 用途 | 优先级 |
|------|------|--------|
| **AnimationPlayer + Tween**（内置） | 车辆移动、UI 动效 | 必需 |
| 自定义 Shader（CanvasItem） | 像素化效果、昼夜、天气 | 可选 |

## 七、音频

| 方案 | 用途 | 优先级 |
|------|------|--------|
| **AudioStreamPlayer（内置）** | BGM/SFX 播放 | 必需 |
| AudioStreamPlayer2D（内置） | 空间音频（车辆引擎声） | 可选 |

## 八、第三方数据/服务（离线工具链，非运行时）

| 库 | 用途 | 许可 |
|----|------|------|
| `osmium` | PBF 裁剪/过滤 | BSL-1.0 |
| `GDAL (ogr2ogr)` | 矢量转换 | MIT/X |
| `tippecanoe` | 矢量瓦片生成 | BSD-2 |
| Python `requests`/`geojson`/`shapely` | 脚本处理 | BSD |

## 九、GDExtension（可选性能下放）

| 场景 | 方案 |
|------|------|
| 大规模寻路/矩阵计算 | Rust GDExtension（godot-rust） |
| 数值模拟热点 | C# 或 Rust |
| 地图数据解析 | Rust（PBF 解析） |

> 首版全部用 GDScript 实现，出现性能瓶颈再按 Profiler 结果下放热点到 GDExtension，避免过早优化。

## 十、选型总结

**必需引入**：GUT（测试）、Godot 内置 TileMapLayer/AStar2D/JSON。
**开发期用**：OSRM（距离烘焙）、osmium/GDAL（工具链）、MapTileProvider（底图参考）。
**其余自研**：存档、UI、动画、音频、模拟内核均基于 Godot 内置能力自研，保持项目轻量与可控。
