# 技术架构总览

## 一、技术栈

| 层 | 选择 |
|----|------|
| 引擎 | Godot 4.x（4.3/4.4 稳定版） |
| 语言 | GDScript 为主，性能热点 C# / GDExtension(Rust) |
| 渲染 | 2D TileMapLayer + TileSet + CanvasItem |
| 寻路 | AStar2D（城市/站点级）+ NavigationServer2D（可选精细） |
| 存档 | JSON（FileAccess）+ 版本迁移 + 原子写 |
| 数据 | JSON/CSV 资源（数据驱动，逻辑数据分离） |
| 文档 | VitePress（本目录） |
| 工具链 | Python（geo 烘焙脚本）、Docker（OSRM） |

## 二、分层架构

```
┌────────────────────────────────────────────┐
│  表现层（Presentation）                     │
│  场景、精灵、TileMap、UI、动画、相机        │
├────────────────────────────────────────────┤
│  玩法层（Gameplay Systems，Autoload 单例）  │
│  FleetManager / HubManager / StationManager │
│  MarketingSystem / FinanceSystem / ...      │
├────────────────────────────────────────────┤
│  模拟内核（Simulation Core）                │
│  SimEngine（tick 驱动）、Demand/Flow/Route   │
├────────────────────────────────────────────┤
│  数据层（Data & Services）                  │
│  存档、配置加载、距离/路网服务、事件服务      │
└────────────────────────────────────────────┘
```

## 三、核心设计原则

1. **数据驱动**：所有数值/配置在 JSON/CSV，逻辑代码不写死数值。
2. **Autoload 单例管理状态**：各玩法系统为 Autoload，场景节点只做表现。
3. **表现与逻辑分离**：车辆/建筑节点只渲染，数据在 Manager 里，避免场景树混乱。
4. **tick 模拟**：采用离散时间步（TransRoute 的 advanceDay 思路），暂停/调速。
5. **信号解耦**：系统间用 Godot Signal 通信，降低耦合。

## 四、Autoload 单例清单

| 单例 | 职责 |
|------|------|
| `Game` | 全局状态、模式、时间流速 |
| `SimEngine` | tick 循环、调度各系统结算 |
| `GeoUtils` | 坐标转换、Haversine |
| `DistanceService` | 距离/用时查询 |
| `RegionManager` | 区域加载/切换 |
| `CityCatalog` | 城市目录 |
| `FleetManager` | 车队管理 |
| `HubManager` | 仓库管理 |
| `StationManager` | 站点管理 |
| `DemandSystem` | 货量生成 |
| `FlowSystem` | 货流状态机 |
| `MarketingSystem` | 知名度/活动 |
| `FinanceSystem` | 现金/信用/报表 |
| `StaffSystem` | 员工 |
| `TechSystem` | 科技树 |
| `EventSystem` | 突发事件 |
| `AISystem` | AI 对手 |
| `SaveManager` | 存档读写 |
| `UIManager` | UI 路由 |

> 后续章节：[目录结构](/architecture/structure)、[插件库](/architecture/plugins)、[模块实现](/architecture/modules)、[数据管线](/architecture/data-pipeline)、[存档系统](/architecture/save-system)、[性能优化](/architecture/performance)。
