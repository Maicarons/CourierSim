# 订单与货流（Order & Cargo Flow）

订单系统是"血液"，连接站点、仓库、车辆三者的货流，是经营成果的直接体现。

## 一、货单（Shipment）生命周期

```
生成 → 收件 → 集货 → 干线 → 分拣 → 干线 → 派送 → 签收
(生成) (站点) (站点) (车辆) (Hub)  (车辆) (站点) (完成)
```

```
Shipment {
  id: String
  origin_station: String
  dest_station: String
  cargo_type: Enum      // 普通/生鲜/医药/危险品/加急
  weight_kg: float
  volume_m3: float
  price: float          // 运费
  deadline: Time        // 时效要求
  status: Enum          // 状态机
  created_day: int
  priority: int         // 优先级（加急 > 普通）
}
```

## 二、货量生成（Demand Generation）

货量由**需求模型**驱动，每日 tick 生成：

```
OD货量 = 区域需求密度(起点) × 区域需求密度(终点) × 距离衰减
       × 公司知名度系数 × 公司评分份额 × 随机波动
```

- **需求密度**：来自真实地理数据（人口/商业/工业 POI 密度）。
- **距离衰减**：长途单比短途单少（符合真实）。
- **公司评分份额**：多公司竞争时按评分分配（见 [竞争](/gameplay/events)）；沙盒无对手则全额。

## 三、货种（Cargo Types）

| 货种 | 利润 | 时效要求 | 特殊要求 |
|------|------|---------|----------|
| 普通件 | 低 | 宽松 | 无 |
| 加急件 | 高 | 极严 | 违约重罚 |
| 生鲜冷链 | 高 | 严 | 需冷藏车/冷链仓 |
| 医药 | 高 | 严 | 需资质+冷链 |
| 危险品 | 极高 | 中 | 需特种车+许可 |
| 大件/重货 | 中 | 宽松 | 需重卡 |

货种解锁与车辆/仓库/科技绑定，形成"解锁新货种 → 新利润增长点"的推进节奏。

## 四、路由（Routing）

货物从起点到终点的路径由**网络拓扑**决定：

- **单 Hub**：`站点A → Hub → 站点B`。
- **多级 Hub**：`站点A → 区域Hub → 全国Hub → 区域Hub → 站点B`。
- **直达**：同城或短途可直接 `站点A → 站点B`。
- 路由由 `RoutePlanner` 基于当前网络图（AStar2D 加权图）计算，权重=距离/成本/时效混合。

## 五、时效与违约

- **承诺时效**：根据车型/距离/中转次数估算。
- **实际时效**：运输 + 中转等待时间累加。
- **违约惩罚**：超时 → 罚款 + 满意度下降；严重违约 → 丢客户。

## 六、技术实现要点

- 货单是**纯数据对象（RefCounted/Resource）**，不渲染为物理实体，仅在地图车辆上显示"载货 N 件"标签。
- `DemandSystem` 每日生成货单，`FlowSystem` 推进状态机，二者均为 Autoload。
- 货流可视化：车辆上气泡显示货量，Hub 显示积压队列，站点显示待收/待派。

```gdscript
# 货单状态机（示意）
enum ShipmentStatus { CREATED, PICKED, INBOUND, SORTING, OUTBOUND, DELIVERING, SIGNED, FAILED }

func advance(shipment: Shipment):
    match shipment.status:
        ShipmentStatus.PICKED:
            ship_to_hub(shipment)
        ShipmentStatus.SORTING:
            sort_and_forward(shipment)
        ShipmentStatus.OUTBOUND:
            deliver(shipment)
```
