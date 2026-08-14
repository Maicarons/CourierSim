# 站点建设（Station）

> 适用版本：v0.12+ · 造价 ¥200,000 · 订单门控端点 · 营销升级

站点是货量的**入口与出口**，直接面对客户。v0.12 起站点造价大幅上调（3 千 → **20 万**），同时成为**订单生成的必要条件**：一个城市只有建了站点或中转仓，才会被接入货流。

## 一、站点属性（src/core/Station.gd）

```gdscript
class_name Station
var id: String
var city_id: String        # 所在城市
var marketing_level: int   # 营销等级 0~N（影响订单权重与营收）
```

- 站点绑定城市（一个城市一个站点），不独立选址——简化操作，让玩家把精力放在"在哪个城市建点"。
- 站点通过 `StationSystem.build(game, city_id)` 建造，造价 **¥200,000**（`StationSystem.STATION_COST`）。

## 二、建造与升级

| 操作 | 价格 | 效果 |
|---|---|---|
| 建站 | ¥200,000 | 该城市接入货流（可收发订单） |
| 营销升级 | ¥5,000 × (level+1) | `marketing_level` +1 → 该城市订单权重提升，营收加成 |

- 建站入口：地图点击城市 → 操作栏「建站点」；或站点面板。
- 营销升级通过 `StationSystem.upgrade_marketing(game, city_id)` 完成。

## 三、站点在订单链路中的角色

- **门控**：`OrderSystem.served_cities()` 只返回"建了站或仓"的城市；两端都未建点 → 该城市对无订单。
- **权重**：`weighted_city()` 中站点城市权重 += `8 × (marketing_level + 1)`，营销等级越高越易成为发货端。
- **订单量**：`compute_spawn = max(1, 站点数 × 0.8) × ...`——站点越多，每天生成的订单越多。

## 四、选址策略要点（城市维度）

1. **高需求城市优先**：城市 `base_demand` 决定订单权重，首尔/釜山等大城市优先建点。
2. **配对成网**：至少 2 个建点城市才能产生订单——早期"首府仓 + 1 站点"即可起步。
3. **覆盖地理跨度**：站点分布越广，可承接的长距离高收益订单越多。
4. **营销拉动**：主发货城市把营销等级叠高，形成稳定的订单来源。

## 五、经济关联

- 站点造价 ¥200,000，但**不产生维护费**（维护仅车辆与中转仓产生），一次投入长期受益。
- 每单运费按吨·公里计价，站点越多 → 订单越多 → 收入越高，形成网络规模效应。
- 现金不足时可先**借贷**（见[经济与财务](/gameplay/finance)）或**租赁车辆**周转，站点投入回报周期约数天。

## 六、技术实现要点

```gdscript
# src/systems/StationSystem.gd（摘录）
const STATION_COST := 200000    # 末端站点基础造价（参考 TransRoute 20 万级）

func build(game: GameManager, city_id: String) -> bool   # 校验资金/是否已建 → 创建 Station
func upgrade_marketing(game: GameManager, city_id: String) -> bool
```

- 站点是纯数据对象，地图上由 `MapView` 绘制建筑图标。
- 建站/升级后 `EventBus.stations_changed` / `map_updated` 通知刷新。
