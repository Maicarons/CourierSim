# 地图数据获取

本章说明如何从公开数据源获取真实地理数据，并离线烘焙为游戏资源。方案直接复用并扩展 TransRoute 的成熟实践。

## 一、数据源清单

| 数据源 | 用途 | 获取方式 | 许可 |
|--------|------|----------|------|
| Geofabrik | 区域路网 PBF | 直接下载 `.osm.pbf` | ODbL |
| OpenStreetMap (OSM) | 矢量要素（道路/水系/边界/POI） | Overpass API / PBF 解析 | ODbL |
| Nominatim | 地理编码（地名→坐标） | HTTP API（限速） | ODbL |
| OSRM | 真实路网距离/用时/折线 | 公共 API 或自部署 | 开源 |
| Natural Earth | 低精度边界/城市 | 下载 GeoJSON/Shapefile | Public Domain |
| Overpass API | 按需查询 POI/城市 | HTTP 查询 | ODbL |

## 二、Geofabrik 区域 PBF

Geofabrik 提供按国家/地区切片的 OSM 数据，直接下载：

```
韩国：  https://download.geofabrik.de/asia/south-korea-latest.osm.pbf
越南：  https://download.geofabrik.de/asia/vietnam-latest.osm.pbf
马来：  https://download.geofabrik.de/asia/malaysia-singapore-brunei-latest.osm.pbf
中国：  https://download.geofabrik.de/asia/china-latest.osm.pbf   （海南需从中国提取）
```

> 海南是中国的一部分，需从 `china-latest.osm.pbf` 中用 `osmium` 或 `osmium-extract` 按省界裁剪（见下文）。

## 三、数据提取工具链

| 工具 | 用途 |
|------|------|
| `osmium` | PBF 裁剪、过滤、统计（C++ 命令行） |
| `osmconvert` / `osmfilter` | PBF 转换与标签过滤 |
| `osmium-tool` Python 绑定 | 脚本化处理 |
| `ogr2ogr` (GDAL) | 矢量格式转换（PBF → GeoJSON/Shapefile） |
| `tippecanoe` | 生成矢量瓦片（MBTiles） |

### 海南提取示例

```bash
# 用 osmium 按边界 polygon 提取海南
osmium extract -p hainan.poly asia/china-latest.osm.pbf -o hainan-latest.osm.pbf
```

## 四、所需要素类型

| 要素 | OSM 标签 | 游戏用途 |
|------|----------|----------|
| 道路 | `highway=motorway/trunk/primary/secondary` | 路网（车辆行驶） |
| 城市 | `place=city/town` | 城市节点 |
| 行政区边界 | `boundary=administrative` + `admin_level` | 区域边界、覆盖规划 |
| 水系 | `waterway=river`、`natural=water` | 地图渲染（像素化） |
| 绿地 | `landuse=forest/park` | 地图渲染 |
| 物流 POI | `industrial`、`landuse=industrial` | 仓库候选点 |
| 商业区 | `landuse=commercial/retail` | 站点需求密度 |
| 居民区 | `landuse=residential` | 站点需求密度 |

## 五、城市目录采集

复用 TransRoute 的城市结构，用 Overpass 采集城市：

```overpass
[out:json][timeout:60];
(
  nwr["place"="city"]["name"="首尔"];
  nwr["place"="city"]["name"="釜山"];
  // ... 韩国主要城市
);
out center tags;
```

产出 `korea_cities.json`，字段对齐 TransRoute：

```json
{
  "id": "首尔",
  "name": "首尔",
  "lng": 126.978,
  "lat": 37.5665,
  "tier": 1,
  "coastal": false
}
```

## 六、离线烘焙流程

真实数据不能在运行时实时请求（慢、限速、需联网），应**离线预烘焙**为游戏资源：

```
原始数据(PBF/GeoJSON)
   │
   ├─ 道路 → 简化 → 路网图(节点/边/权重) → road_graph.json
   ├─ 城市 → 城市目录 → cities.json
   ├─ 边界/水系/绿地 → 像素化 → tileset 数据
   ├─ POI → 需求密度栅格 → demand_grid.json
   └─ 距离矩阵(OSRM批量) → distance_matrix.json
```

烘焙产物打包进 Godot 资源目录（`res://data/regions/`），运行时零网络依赖。

> 详见 [数据管线](/architecture/data-pipeline)。
