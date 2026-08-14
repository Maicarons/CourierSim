# 中转仓库（Hub）

> 适用版本：v0.12+ · 造价 ¥600,000 · 首府赠送 · 网络中枢

中转仓库是物流网络的**中枢节点**：新游戏在首府免费赠送 1 个（玩家运营的起点），也是订单门控端点之一。v0.12 起中转仓造价 ¥8000 → **¥600,000**。

## 一、仓库属性（src/core/Hub.gd）

```gdscript
class_name Hub
var id: String
var name: String
var city_id: String        # 所在城市
var level: int             # 1..N（升级提升容量）
var base_capacity: int     # 基础容量（HUB_BASE_CAP = 200）
```

- 仓库绑定城市，是"建仓 = 把城市接入货流"的另一种方式（与站点等价，但造价更高、容量更大）。
- 升级通过 `HubSystem.upgrade(game, hub)`：花费随等级上升，提升容量。

## 二、建造与升级

| 操作 | 价格 | 效果 |
|---|---|---|
| 建仓（额外） | ¥600,000 | 该城市接入货流，获得仓储容量 |
| 升级 | 随等级递增 | `level` +1 → 容量提升（每级 `level × 300` 日运营费也随之上升） |
| 首府赠仓 | 免费 | `new_game` 时在 `capital_city()` 自动创建 1 个（`Hub.new(..., 200, 8000)`） |

- 建仓入口：地图点击城市 → 操作栏「建仓库」；或仓库面板。
- `HubSystem.build(game, city_id)` 返回是否成功（资金不足/已建则拒绝）。

## 三、在订单链路中的角色

与站点相同，中转仓所在城市也是**订单门控端点**（`served_cities()` 返回站+仓城市集合）：

- 首府免费赠仓 → 玩家开局即有一个可收发订单的城市。
- 第二城市建站/建仓后，跨城订单产生，运输闭环开启。
- 后续建仓更多是"扩展接入城市"与"容量储备"，站点造价更低，是常规扩张手段。

## 四、经济关联

- **建造**：¥600,000 一次投入；**运营费**：每日 `level × 300`（计入维护与仓库运营成本）。
- 总资产计算中仓库按 `level × 5000` 计入。
- 前期资金 100 万：赠仓后先建 1 站（20 万）+ 租/买车（6 万起），余量用于周转与借贷缓冲。

## 五、技术实现要点

```gdscript
# src/systems/HubSystem.gd（摘录）
const HUB_BASE_COST := 600000   # 中转仓库基础造价（参考 TransRoute 中转枢纽 250 万级，取其下级）
const HUB_BASE_CAP := 200

func build(game: GameManager, city_id: String) -> bool
func upgrade(game: GameManager, hub: Hub) -> bool
```

- 仓库是纯数据对象，地图上由 `MapView` 绘制建筑图标。
- 建仓/升级后 `EventBus.hubs_changed` / `map_updated` 通知刷新。
