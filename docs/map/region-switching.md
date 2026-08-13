# 区域切换机制

多区域（韩国 → 海南 → 越南 → 马来西亚）是本作的扩展方向，需要一套**区域（Region）抽象**支持无缝加载与切换。

## 一、区域抽象

每个区域是一套**自包含的数据包 + 场景**：

```
Region {
  id: String            // "korea" / "hainan" / "vietnam" / "malaysia"
  name: String
  origin_lng, origin_lat: float   // 投影原点
  bounds: Rect2         // 米坐标范围
  cities: Array[City]
  road_graph: RoadGraph // 路网图
  distance_matrix: Dictionary  // 城市对 → {距离, 用时}
  demand_grid: DemandGrid       // 需求密度
  tileset: TileSet      // 像素瓦片
  scene: PackedScene    // 地图场景
}
```

## 二、数据组织

```
res://data/regions/
├── korea/
│   ├── cities.json
│   ├── road_graph.json
│   ├── distance_matrix.json
│   ├── demand_grid.json
│   └── tileset.res
├── hainan/
├── vietnam/
└── malaysia/
```

每个区域目录自包含，加载时只读取对应目录，**内存占用可控**（不一次性加载所有区域）。

## 三、切换流程

```
切换区域(region_id)
   │
   ├─ 卸载当前区域场景（释放路网/瓦片）
   ├─ 设置新区域投影原点（GeoUtils.region_origin_*）
   ├─ 加载新区域数据（异步，显示加载过渡）
   ├─ 实例化新地图场景（TileMapLayer + 建筑 + 车辆）
   └─ 恢复相机位置到新区域中心
```

- **异步加载**：用 `ResourceLoader.load_threaded_request` + 进度条，避免卡顿。
- **卸载释放**：`queue_free()` 旧场景 + 清空引用，让 Godot 自动回收。

## 四、跨区域物流

跨区域（如韩国 ↔ 越南）的货物如何处理？

- **简化方案（首版）**：跨区域通过"国际航线/海运"抽象为**高成本、长时效的虚拟线路**，不渲染具体船只/飞机动画，只走计时。
- **区域间 Hub**：每个区域设"国际枢纽"（仁川港/釜山港、胡志明港），跨区域货物在国际枢纽之间"转运"。
- **用时计算**：跨区域用预设的航运/空运时间表（如首尔→河内空运 1 天、海运 5 天）。

```
区域A站点 → 区域A国际枢纽 ⇢(海运/空运 计时)⇢ 区域B国际枢纽 → 区域B站点
```

## 五、解锁与存档

- **区域解锁**：生涯模式按章节解锁；沙盒可自由开启。
- **存档隔离**：每个区域的资产状态独立存档，切换不丢数据。
- **全局资产**：公司级（现金、科技、员工）跨区域共享；区域级（站点、仓库、车辆位置）按区域存储。

## 六、技术实现要点

```gdscript
# RegionManager.gd（Autoload）
class_name RegionManager
extends Node

const REGION_LIST := ["korea", "hainan", "vietnam", "malaysia"]
var current_region: Region
var loaded_regions := {}   # 缓存已加载区域（可选）

func switch_region(id: String) -> void:
    if current_region:
        _unload(current_region)
    current_region = await _load_region(id)
    GeoUtils.set_origin(current_region.origin_lng, current_region.origin_lat)
    get_tree().current_scene.add_child(current_region.scene.instantiate())
```
