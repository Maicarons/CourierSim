# 模块实现要点

本章为每个核心模块给出 Godot 具体实现方案（类结构、关键 API、注意事项）。

## 一、SimEngine（模拟内核）

```gdscript
class_name SimEngine
extends Node

signal tick_started(day: int)
signal tick_finished(day: int)

var current_day: int = 0
var time_scale: float = 1.0   # 0 暂停 / 1 / 2 / 4
var tick_interval_sec := 1.0  # 每个游戏日内 tick 的时长

func _process(delta):
    if time_scale == 0.0: return
    _accum += delta * time_scale
    if _accum >= tick_interval_sec:
        _accum = 0.0
        _advance_tick()
```

**要点**：采用 TransRoute 的"日结算"思路，但细化为**秒级 tick**（车辆移动）与**日级 tick**（货量/财务）两级。

## 二、路网图（RoadGraph）

```gdscript
class_name RoadGraph
extends RefCounted

var astar := AStar2D.new()
var node_id_map := {}   # "city_id" -> astar point id
var edges := {}         # (a,b) -> {dist_km, road_class}

func build_from_json(data: Dictionary):
    for node in data["nodes"]:
        var id = astar.add_point(Vector2(node["x"], node["y"]))
        node_id_map[node["id"]] = id
    for edge in data["edges"]:
        astar.connect_points(node_id_map[edge["a"]], node_id_map[edge["b"]])
        astar.set_point_weight_scale(...)  # 按道路等级/距离设权

func find_path(from_id: String, to_id: String) -> PackedVector2Array:
    return astar.get_point_path(node_id_map[from_id], node_id_map[to_id])
```

**要点**：路网从烘焙的 `road_graph.json` 构建，权重=距离（km）或混合成本（距离/速度）。

## 三、FleetManager（车队）

```gdscript
class_name FleetManager
extends Node

var vehicles := {}   # id -> Vehicle

func buy_vehicle(model: String, home_hub: String) -> Vehicle
func assign_route(vehicle_id: String, route: Route) -> void
func tick(delta: float):  # 更新车辆位置/状态
```

**要点**：车辆数据与车辆节点分离——`Vehicle`（数据）+ `vehicle.tscn`（表现），`FleetManager` 维护数据，场景树按需实例化可见车辆。

## 四、DemandSystem（货量生成）

```gdscript
class_name DemandSystem
extends Node

func generate_daily_demand():
    for origin in StationManager.stations:
        for dest in StationManager.stations:
            if origin == dest: continue
            var qty = calc_demand(origin, dest)
            create_shipments(origin, dest, qty)
```

**要点**：货量公式集中到 `calc_demand`，参数从配置读取；生成后交给 FlowSystem。

## 五、FlowSystem（货流状态机）

```gdscript
class_name FlowSystem
extends Node

var shipments: Array[Shipment]

func tick_day():
    for s in shipments:
        match s.status:
            ShipmentStatus.SORTING: _process_sorting(s)
            ...
```

**要点**：货单是 `RefCounted`，状态推进在 tick 中批量处理，避免逐单节点开销。

## 六、寻路性能（分层方案）

大世界用**两层寻路**：

```
区域层：城市/站点间用 AStar2D（粗粒度，几十~几百节点）
道路层：车辆在道路上用 AStarGrid2D 或预计算折线
```

- 车辆行驶路径**预计算缓存**，移动时只做插值，不逐帧寻路。
- 动态障碍（施工/事故）局部失效缓存，重新寻路该段。

## 七、地图渲染（TileMapLayer）

```gdscript
# 加载区域瓦片（示意）
func load_region_tiles(region: Region):
    var layer = TileMapLayer.new()
    layer.tile_set = region.tileset
    # 根据烘焙数据 set_cell 批量放置
    for cell_data in region.tile_cells:
        layer.set_cell(cell_data.coords, cell_data.source_id, cell_data.atlas_coords)
```

**要点**：
- 用 `set_cell` 批量 + 分块（chunk）加载，避免超大单层 TileMap 一次性构建。
- 相机视野外的 chunk 卸载（借鉴 Godot chunk loading 方案）。
- 建筑（站点/仓库）用 `Sprite2D` + `Area2D`，不混入 TileMap。

## 八、UI 架构

```
UIManager（Autoload）
├── HUD（顶部：现金/日期/时间流速/快捷入口）
├── Panel 栈（管理面板：车辆/仓库/站点/市场/财务…）
├── 弹窗（确认/提示/事件）
└── 菜单（主菜单/设置/存档/加载）
```

- 用 `CanvasLayer` 分层：世界层 / UI 层 / 弹窗层 / 菜单层。
- 面板用 `Control` 节点 + 主题（Theme），保持像素风统一。

## 九、信号约定

系统间通信统一用信号，避免直接引用造成耦合：

```gdscript
# FinanceSystem
signal cash_changed(new_cash: int)
signal bankrupt()

# EventSystem
signal event_triggered(event: Event)

# 订阅方
FinanceSystem.cash_changed.connect(_on_cash_changed)
```

## 十、常见坑位提醒

1. **浮点金额**：用整数分，勿用 float 存钱。
2. **Vector2 不能直接 JSON**：存档需手动转 `{x,y}`（见 [存档系统](/architecture/save-system)）。
3. **大坐标精度**：地理坐标先投影到局部米，避免大数值 float 误差。
4. **逐帧 set_cell**：性能差，用批量/chunk。
5. **信号泄漏**：节点销毁前 disconnect，避免悬空引用。
6. **Resource 循环引用**：存档时注意引用图，只存 id 不存对象。
