# 数据管线

数据管线负责把**原始地理数据 + 数值设计**加工成游戏可直接加载的资源，是"真实地图"承诺的工程保障。

## 一、管线总览

```
┌──────────────┐   ┌──────────────┐   ┌──────────────────┐
│ 原始地理数据  │──▶│  烘焙脚本     │──▶│  游戏资源         │
│ PBF/GeoJSON  │   │  tools/geo/  │   │  data/regions/    │
└──────────────┘   └──────────────┘   └──────────────────┘
                          │
┌──────────────┐          │
│ 数值配置      │──────────┘
│ config/*.json│
└──────────────┘
```

## 二、地理数据烘焙管线

### 步骤 1：下载

```bash
bash tools/geo/download.sh korea   # 下载 south-korea-latest.osm.pbf
```

### 步骤 2：提取要素

```bash
python tools/geo/extract_region.py korea \
  --cities "首尔,釜山,仁川,大邱,光州,大田,蔚山,..." \
  --output data/regions/korea/
```

产出：
- `cities.json` — 城市目录（Overpass 采集或 PBF 提取 `place=city`）。
- `poi.json` — 物流 POI / 商业区 / 工业区。
- `boundaries.json` — 行政区边界。

### 步骤 3：构建路网图

```bash
python tools/geo/build_road_graph.py korea
```

- 提取 `highway` 道路 → 简化（道格拉斯-普克）→ 节点/边。
- 边权重：距离 km（+ 道路等级速度）。
- 产出 `road_graph.json`。

### 步骤 4：距离矩阵（OSRM）

```bash
python tools/geo/build_distance_matrix.py korea --osrm http://localhost:5000
```

- 遍历城市对，调 OSRM 拿真实距离/用时。
- 产出 `distance_matrix.json`。
- 无 OSRM 时降级 Haversine × 系数。

### 步骤 5：需求密度栅格

```bash
python tools/geo/build_demand_grid.py korea
```

- 统计商业/工业/居民 POI 密度 → 栅格。
- 产出 `demand_grid.json`。

### 步骤 6：像素化瓦片

```bash
python tools/geo/rasterize_tiles.py korea
```

- 道路/水系/边界矢量 → 像素瓦片数据（供 TileSet 生成）。
- 产出瓦片坐标数据或直接生成 `.png` 瓦片集。

## 三、数值配置管线

数值配置与代码分离，直接放 `data/config/*.json`：

```
data/config/
├── vehicles.json      # 车型谱系
├── hubs.json          # 仓库等级
├── stations.json      # 站点等级
├── cargo.json         # 货种
├── tech_tree.json     # 科技树
├── events.json        # 事件表
├── marketing.json     # 推广渠道
├── staff.json         # 岗位
└── economy.json       # 经济常数（税率、利率、绕路系数）
```

**示例（vehicles.json 片段）**：

```json
{
  "van": {
    "name": "面包车",
    "tier": 1,
    "capacity_kg": 800,
    "speed_kmh": 60,
    "fuel_cost_per_km": 0.8,
    "price": 30000
  }
}
```

## 四、配置加载

运行时用 `ConfigLoader`（Autoload）统一加载，避免散落 `load()`：

```gdscript
class_name ConfigLoader
extends Node

var cache := {}

func get_config(name: String) -> Dictionary:
    if cache.has(name): return cache[name]
    var path = "res://data/config/%s.json" % name
    var data = JSON.parse_string(FileAccess.get_file_as_string(path))
    cache[name] = data
    return data
```

## 五、一键烘焙

```bash
python tools/pipeline.py korea      # 单区域全流程
python tools/pipeline.py --all      # 所有区域
```

## 六、数据校验

- 烘焙脚本附带**断言校验**：城市坐标合法、路网连通、距离矩阵对称。
- CI 中运行数据校验，防止坏数据入库（见 [测试与发布](/development/qa)）。

## 七、大文件管理

- PBF / OSRM 中间产物不入 Git（`.gitignore`）。
- 只提交**最终 JSON/资源**，通过脚本可一键重建。
- 若最终资源仍过大，用 Git LFS 或单独发布数据包。
