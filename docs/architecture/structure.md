# 项目目录结构

采用 GitHub 单仓库（Monorepo）结构，AGPL-3.0 协议。Godot 项目在 `game/`，文档在 `docs/`，地理数据工具链在 `tools/`。

## 一、顶层结构

```
CourierSim/
├── .github/                    # GitHub 工作流与模板
│   ├── workflows/
│   │   ├── ci.yml              # CI：GDScript 静态检查 + 导出测试
│   │   ├── docs.yml            # VitePress 文档构建部署
│   │   └── release.yml         # 导出并发布 Release
│   ├── ISSUE_TEMPLATE/
│   └── PULL_REQUEST_TEMPLATE.md
├── .gitignore                  # Godot + Node 忽略规则
├── LICENSE                     # AGPL-3.0
├── README.md                   # 项目说明（指向 docs）
├── docs/                       # VitePress 文档站（本规划）
├── game/                       # Godot 工程
├── tools/                      # 离线工具链（Python）
└── third_party/                # 第三方资源许可与来源记录
```

## 二、Godot 工程（`game/`）

```
game/
├── project.godot               # 工程配置
├── export_presets.cfg          # 导出预设
├── icon.svg                    # 图标
├── autoload/                   # Autoload 单例（脚本）
│   ├── game.gd
│   ├── sim_engine.gd
│   ├── geo_utils.gd
│   ├── distance_service.gd
│   ├── region_manager.gd
│   ├── city_catalog.gd
│   ├── fleet_manager.gd
│   ├── hub_manager.gd
│   ├── station_manager.gd
│   ├── demand_system.gd
│   ├── flow_system.gd
│   ├── marketing_system.gd
│   ├── finance_system.gd
│   ├── staff_system.gd
│   ├── tech_system.gd
│   ├── event_system.gd
│   ├── ai_system.gd
│   ├── save_manager.gd
│   └── ui_manager.gd
├── scenes/                     # 场景
│   ├── main/
│   │   └── main.tscn           # 主场景
│   ├── world/
│   │   ├── world.tscn          # 世界根
│   │   ├── map_view.tscn       # 地图视图
│   │   └── region/             # 各区域地图场景
│   ├── entities/
│   │   ├── vehicle.tscn        # 车辆
│   │   ├── hub.tscn            # 仓库
│   │   └── station.tscn        # 站点
│   └── ui/
│       ├── hud.tscn            # 顶部 HUD
│       ├── panels/             # 各管理面板
│       └── menus/              # 主菜单/设置/存档
├── scripts/                    # 非单例脚本（挂载到场景）
│   ├── entities/
│   ├── ui/
│   └── utils/
├── resources/                  # 自定义 Resource 类定义
│   ├── vehicle_stats.gd
│   ├── hub_stats.gd
│   ├── station_stats.gd
│   ├── cargo_type.gd
│   └── ...
├── assets/                     # 美术/音频资源
│   ├── sprites/
│   ├── tilesets/
│   ├── audio/
│   ├── ui/
│   ├── fonts/
│   └── shaders/
├── data/                       # 游戏数据（JSON/CSV）
│   ├── regions/                # 区域数据包
│   │   ├── korea/
│   │   ├── hainan/
│   │   ├── vietnam/
│   │   └── malaysia/
│   ├── config/                 # 数值配置
│   │   ├── vehicles.json
│   │   ├── hubs.json
│   │   ├── stations.json
│   │   ├── cargo.json
│   │   ├── tech_tree.json
│   │   ├── events.json
│   │   └── marketing.json
│   └── i18n/                   # 本地化
├── addons/                     # Godot 插件
└── tests/                      # 单元测试（GUT）
```

## 三、工具链（`tools/`）

```
tools/
├── geo/                        # 地理数据处理
│   ├── download.sh             # Geofabrik 下载
│   ├── extract_region.py       # 提取区域/城市/POI
│   ├── build_road_graph.py     # 路网图构建
│   ├── build_distance_matrix.py# OSRM 距离矩阵
│   ├── build_demand_grid.py    # 需求密度栅格
│   └── rasterize_tiles.py      # 矢量→像素瓦片
├── pipeline.py                 # 一键烘焙管线
└── requirements.txt
```

## 四、文档（`docs/`）

```
docs/
├── .vitepress/config.ts
├── index.md                    # 首页
├── overview/                   # 概览
├── gameplay/                   # 核心玩法
├── map/                        # 地图与区域
├── architecture/               # 技术架构
├── assets/                     # 素材清单
└── development/                # 开发计划
```

## 五、`.gitignore` 要点

```gitignore
# Godot
.godot/
*.import
export/

# Node / VitePress
node_modules/
docs/.vitepress/cache/
docs/.vitepress/dist/

# 数据（体积大，单独管理）
tools/osrm-data/
*.osm.pbf

# 系统
.DS_Store
Thumbs.db
```

> 大体积地理数据（PBF、OSRM 文件）不入库，只提交**烘焙后的 JSON/资源**，原始数据按需本地下载（脚本一键重建）。
