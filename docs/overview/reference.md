# 参考项目：TransRoute（物流大亨）

前作 TransRoute 是本次《CourierSim · 快递王国》的**地理数据与技术方案的直接来源**，位于 `G:\workspace\transroute`。本章梳理其可复用的资产，避免重复踩坑。

## 一、TransRoute 是什么

一款受 AirlineSim 启发的物流大亨游戏：玩家在城市间开设运输线路、调度车队、竞标共享货池、结盟联运、玩家间交易，并面对银行贷款、信用评级与破产清算。

技术栈为 **Monorepo**：

| 目录 | 说明 | 技术栈 |
|------|------|--------|
| 根目录 `src/` | 单机版前端 | Vite + React 18 + TypeScript + MapLibre + Tailwind + Zustand |
| `game/` | 单机版独立构建产物 | 同单机版 |
| `server/` | 多人版后端（权威模拟） | Go 1.22 + Fiber + WebSocket + GORM(SQLite) |
| `client/` | 多人版前端 | Vite + React + TypeScript + Zustand |
| `docs/` | 系统设计文档 | VitePress + Mermaid |

## 二、可直接复用的地理资产

### 1. 城市静态目录（WGS84 真实坐标）

`server/internal/geo/cities.go` 内含 40 个真实中国城市的经纬度、城市等级（Tier）、沿海标记：

```go
type City struct {
    ID      string  // 城市名
    Name    string
    Lng     float64 // 经度 WGS84
    Lat     float64 // 纬度 WGS84
    Tier    int     // 1=一线枢纽 2=省会 3=其他
    Coastal bool
}
```

- 城市等级系数 `TierMult`：一线 1.0 / 省会 0.8 / 其他 0.6。
- 前端 `src/data/cities.ts` 维护一份完全一致的快照。

**对本作的意义**：韩国首发时，我们只需用同样的结构采集韩国城市（首尔、釜山、仁川、大邱、光州、大田、蔚山等），即可复用 Tier 分级与货量系数逻辑。

### 2. Haversine 大圆距离

`cities.go` 中的 `HaversineKm(lng1, lat1, lng2, lat2)` 使用 `R=6371.0` 计算两点大圆距离，作为 OSRM 不可用时的**降级兜底**（直线距离 × 绕路系数）。

### 3. OSRM 真实路网路由

`src/lib/osrm.ts` 封装了两个数据源：

- **OSRM 公共演示服务器** `https://router.project-osrm.org/route/v1/driving`（免 Key、CORS 开放、限速，适合开发期）。
- **本地自部署 OSRM** `http://localhost:5000/route/v1/driving`（可离线、可控、无速率限制，生产/打包时用）。

返回结构 `{ distanceKm, durationHours, path }`，其中 `path` 是道路折线 `[经度, 纬度][]`。

### 4. Nominatim 地理编码

`src/lib/geocode.ts` 封装了 OSM Nominatim（`https://nominatim.openstreetmap.org/search`，限速 1 次/秒）与高德（GCJ-02，需 Key），统一接口把"地名"解析为真实经纬度。

### 5. Geofabrik PBF 下载 + OSRM 构建脚本

`scripts/setup-osrm.sh` 从 Geofabrik 下载 `.osm.pbf` 并构建本地 OSRM 路网：

```bash
# 中国全国（约 1.5GB）
bash scripts/setup-osrm.sh china
# 单个省（如广东省，几百 MB）
bash scripts/setup-osrm.sh guangdong
```

`docker-compose.yml` 提供 OSRM 后端 + nginx CORS 网关（宿主 localhost:5000）。

## 三、可复用的玩法模型

`docs/system_design.md`（531 行）定义了完整的多人物流玩法，本作单机化后可提炼：

- **共享货池评分模型**：每个 OD 对按公司评分（价格/时效/覆盖/联运权重）比例分配货运需求。
- **Tick 结算顺序**：`advanceDay` 的 11 步结算（货量生成 → 分配 → 运输 → 收益…）。
- **金融系统**：银行贷款、信用评分、破产清算。
- **实体定义**：车辆、线路、站点、仓库、订单、公司资产。

## 四、复用到本作的关键结论

| TransRoute 资产 | 本作复用方式 |
|-----------------|--------------|
| 城市目录 + Tier 分级 | 采集韩国/越南/马来西亚城市，同构建模 |
| Haversine 距离 | 作为离线兜底距离计算 |
| OSRM 路网 | 开发期在线，发布时预烘焙距离矩阵到本地资源 |
| Nominatim | 开发期工具链，运行时不需要 |
| Geofabrik 数据源 | 韩国 `asia/south-korea-latest.osm.pbf` 等 |
| 货池评分 / Tick | 移植为单机 GDScript 版本 |
| VitePress 文档 | 直接沿用当前文档站方案 |
