# 真实地图系统

> 适用版本：v0.4.0+
> 数据许可：Natural Earth — Public Domain；OpenStreetMap — ODbL

## 一、数据来源

| 数据 | 用途 | 来源 | 许可 |
|---|---|---|---|
| 陆地/海岸线 | 地图底图 | [Natural Earth 1:50m](https://www.naturalearthdata.com/) via jsDelivr CDN | Public Domain |
| 城市经纬度 | 城市节点 | OSM / Geofabrik / Overpass | ODbL |
| 距离/时间 | 配送耗时 | 球面 Haversine 兜底；OSRM 备选 | — |

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
        ▼
res://src/map/data/regions/
  ├── korea.json          (城市定义)
  ├── korea_land.json     (陆地多边形)
  ├── korea_terrain.png   (地形贴图)
  ├── hainan.json/.json/.png
  ├── vietnam.json/.json/.png
  └── malaysia.json/.json/.png
```

刷新一次约 1-2 秒。

## 三、运行时渲染（MapView.gd）

```gdscript
# 加载（区域切换时一次性）
_load_land()        # 读取 _land.json + _terrain.png
_build_routes()     # 计算陆路/海运路线网络

# 每帧绘制 _draw()：
# 1. 海底色（天空蓝）
# 2. 陆地贴图（按 bbox 拉伸）
# 3. 海运虚线
# 4. 陆路曲线（最近邻 + 控制点贝塞尔）
# 5. 海岸描边（深色）
# 6. 城市节点 + 名称
# 7. 仓库/站点
# 8. 订单流光线
# 9. 车辆精灵
# 10. 悬停/选中高亮
# 11. 图例
```

## 四、玩法整合（地图即玩法）

```
玩家操作                          系统反馈
─────────                          ────────
点击城市 → 选中                  → 显示信息卡（人口/层级/需求/设施）
                                 → 显示操作栏：
                                    [建仓库 ¥8000]   → hub_sys.build
                                    [升级仓库 ¥N]    → hub_sys.upgrade
                                    [建站点 ¥3000]   → station_sys.build
                                    [宣传升级 ¥N]    → station_sys.upgrade_marketing
                                    [关闭]
滚轮                            → 缩放（0.5x ~ 8x）
左键拖拽                         → 平移
悬停                            → 蓝色虚线高亮 + Tooltip
```

## 五、路线网络启发式

- **陆路**：每城市连接最近 2 个距离 < 320 km 的城市（构成链状网络）
- **海运**：所有港口（has_port=true）之间距离 < 520 km 用虚线连接
- **绘制**：陆路带控制点的二次贝塞尔（垂直偏移 = 距离 × 0.08），深色描边 + 浅色路面
- 真实 OSRM 道路接入是未来工作（见 [docs/map/distance-time.md](../../map/distance-time.md)）

## 六、未来增强路线图

| 阶段 | 内容 |
|---|---|
| 已完成 | 陆地/海岸线、城市节点、风格化陆路/海运、点击建仓/站 |
| 下一版 | OSRM 真实路网距离/路径、订单按最短路径自动规划 |
| 远期 | 区域间切换动画、城市 3D 简化立体效果、天气系统 |

## 七、调试技巧

- 修改 `tools/bake_land.py` 的 `MARGIN` 字典调整每区域外扩经纬度
- 修改 `tools/bake_terrain.py` 的 `MAX_DIM` 提高贴图分辨率
- 修改 `MapView._build_routes()` 的 `max_road_km`/`max_sea_km` 控制路网密度