# 真实地图系统

> 适用版本：v0.12+ · OSRM 真实路网 · 线性投影一致 · 描边与贴图同源
> 数据许可：Natural Earth — Public Domain；OpenStreetMap — ODbL

## 一、数据来源

| 数据 | 用途 | 来源 | 许可 |
|---|---|---|---|
| 陆地/海岸线 | 地图底图 | [Natural Earth 1:50m](https://www.naturalearthdata.com/) via jsDelivr CDN | Public Domain |
| 城市经纬度 | 城市节点 | OSM / Geofabrik / Overpass | ODbL |
| **城市对里程/耗时/折线** | 配送耗时与车辆移动路径 | **OSRM（OpenStreetMap 路网引擎）** | ODbL |

## 二、烘焙链路（离线脚本，可复现）

```
原始数据                                  运行时
─────────                                  ──────
Natural Earth 50m land GeoJSON
        │
        ├─ tools/bake_land.py
        │     ├── 按区域 bbox 裁剪（Sutherland-Hodgman）
        │     ├── Douglas-Peucker 简化（tol 0.008°）
        │     └── 输出 <id>_land.json（多边形环，WGS84）
        │
        ├─ tools/bake_terrain.py
        │     ├── PIL 光栅化多边形（768×768 max）
        │     ├── 像素噪声地形色（grass/hill/sand）
        │     ├── 网格暗线（10px 卡通 tile 感）
        │     └── 输出 <id>_terrain.png（RGBA，海透明）
        │
        └─ tools/bake_routes.py                  ★ v0.12 新增
              ├── 遍历区域所有城市对 → OSRM 公共实例
              ├── dist_km / dur_h / 折线路径（Douglas-Peucker 简化）
              └── 输出 <id>_routes.json
        ▼
res://src/map/data/regions/
  ├── korea.json           (城市定义)
  ├── korea_land.json      (陆地多边形)
  ├── korea_terrain.png    (地形贴图)
  ├── korea_routes.json    (真实路网矩阵)      ★
  ├── hainan.* / vietnam.* / malaysia.*
```

## 三、运行时渲染（MapView.gd）

```gdscript
# 加载（区域切换时一次性）
_load_land()        # 读取 _land.json + _terrain.png + _routes.json
_build_routes()     # 从 OSRM 折线构建真实道路网络（非贝塞尔假路网）

# 每帧绘制 _draw()：
# 1. 海底色（天空蓝）
# 2. 陆地贴图（按 bbox 拉伸）
# 3. 真实道路折线（奶油白路面 + 深棕描边，来自 OSRM path）
# 4. 海运虚线（港口对，无 OSRM 时用直线）
# 5. 海岸描边（线性 bbox 映射，与贴图同源贴合）
# 6. 城市节点 + 名称
# 7. 仓库/站点
# 8. 订单路线（待派橙虚线 / 在途蓝实线 + 流动光点）
# 9. 车辆精灵（沿折线移动）
# 10. 悬停/选中高亮
# 11. 图例
```

## 四、描边错位修复（v0.12 关键修复）

早期版本海岸线描边与陆地贴图错位，根因是**两套投影不一致**：

- terrain.png 由 PIL 按 `bbox` **线性拉伸**光栅化；
- 海岸线却用**等距圆柱投影**（含 `cos(lat)` 修正）绘制——韩国位于 37°N，纬度越高偏差越大。

**修复**：`_coastlines` 统一存**经纬度**，绘制时用 `_bbox_to_screen()` **线性 bbox 映射**与贴图同源；
同时 `MapView` 开启 `clip_contents = true`，防止任何绘制溢出到相邻 UI（底栏日志曾被海色盖住）。

## 五、玩法整合（地图即玩法）

```
玩家操作                          系统反馈
─────────                          ────────
点击城市 → 选中                  → 显示信息卡（人口/层级/需求/设施）
                                 → 显示操作栏：
                                    [建仓库 ¥600,000]  → hub_sys.build
                                    [升级仓库 ¥N]      → hub_sys.upgrade
                                    [建站点 ¥200,000]  → station_sys.build
                                    [宣传升级 ¥N]      → station_sys.upgrade_marketing
                                    [关闭]
滚轮                            → 缩放（0.5x ~ 8x）
左键拖拽                         → 平移
悬停                            → 蓝色虚线高亮 + Tooltip
```

## 六、真实路网（v0.12）

- 删除旧的"最近邻 + 贝塞尔假路网"，`_build_routes()` 直接读 `region.route_between()` 的 OSRM 折线：
  每个城市连接最近的 2 个城市（`max_links=2`），绘制其真实公路折线 → 地图上看到的是**真实韩国公路网走向**。
- 订单路线、车辆移动同样沿折线（见[订单与货流](/gameplay/order)、[车辆系统](/gameplay/vehicle)）。
- 海运：港口对无 OSRM 时用直线虚线（如韩国的仁川/釜山港间）。

## 七、未来增强路线图

| 阶段 | 内容 |
|---|---|
| 已完成 | 陆地/海岸线、城市节点、**真实 OSRM 路网**、描边贴合、点击建仓/站、车辆沿折线移动 |
| 下一版 | 更多区域烘焙、道路等级区分（高速/国道配色）、天气对时效影响 |
| 远期 | 区域间切换动画、城市 3D 简化立体效果 |

## 八、调试技巧

- 修改 `tools/bake_land.py` 的 `MARGIN` 字典调整每区域外扩经纬度
- 修改 `tools/bake_terrain.py` 的 `MAX_DIM` 提高贴图分辨率
- 修改 `tools/bake_routes.py` 的简化阈值控制折线点数
- 修改 `MapView._build_routes()` 的 `max_links` 控制路网密度
