# 测试与发布

## 一、测试策略

| 层级 | 工具 | 覆盖 |
|------|------|------|
| 无头回归 | `tools/smoke_test.tscn` | 新游戏/资产/多对手/评级/槽位/破产/结算 + 面板构建 |
| 长局平衡 | `tools/balance_sim.tscn` | AI 自动经营 120 天，多策略对比，经济健康验证 |
| 数据校验 | Python 脚本 | 配置/地理数据合法性、烘焙产物完整性 |
| 手动测试 | 人工 + 截图脚本 | 玩法体验、UI、真实渲染效果 |
| 性能测试 | Profiler | 帧率、内存 |

## 二、无头回归（smoke_test）

```bash
godot --headless --path . res://tools/smoke_test.tscn --quit-after 300
```

覆盖断言（v0.10 起 26+ 项）：
- 新游戏资金 / 活跃槽位 / 胜负标志
- 车队与建筑资产计算（车辆 ×0.8 + 仓 ×5000 + 站 ×3000）
- 多对手出现与份额区间、市占蚕食
- 评级合法性（B → 高指标 S）
- 存档槽位 save/load/next_free/slot_label 往返
- 破产触发与结算 summary
- 10 个面板全部构建 OK（v0.9）
- 手动派单：`auto_assign_enabled` 开关 + `assignable_vehicles` 候选（v0.11）
- 借贷：borrow/repay/max_loan（v0.12）
- 租赁：lease/return_lease 与日租扣费（v0.12）

## 三、长局平衡模拟（balance_sim）

```bash
godot --headless --path . res://tools/balance_sim.tscn --quit-after 900
godot --headless --path . res://tools/balance_sim.tscn --quit-after 900 -- --strategy=truck
godot --headless --path . res://tools/balance_sim.tscn --quit-after 900 -- --strategy=mix
```

- AI 策略（v0.12）：先建站点（¥20 万）→ 扩仓 → 买车（现金充裕时）→ 租赁兜底 → 现金紧张借款。
- **多策略**（`OS.get_cmdline_user_args()` 读取 `--strategy=van|truck|mix`）：每种车型都要有独立策略可玩性。
- 输出资金/交付/市占/声誉/评级曲线；**120 天基准：van/mix A 级不破产，truck A 级通关**。

## 四、真实渲染验证（截图脚本）

headless 看不到渲染效果，v0.12 起采用**真实窗口跑临时场景 + viewport 截图**：

```gdscript
await get_tree().create_timer(1.5).timeout
get_viewport().get_texture().get_image().save_png("res://tools/shot.png")
```

- 用于验证：地图路网折线、描边贴合、UI 层级（对白不被遮挡）、底栏文字可见性。
- 用完即删，不进入 git 历史。

## 五、CI 流水线（.github/workflows/test.yml）

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Godot headless 启动 + smoke_test + balance_sim
        run: godot --headless --path . res://tools/smoke_test.tscn --quit-after 300
      - name: VitePress 文档构建
        run: npm run build
```

- push / PR 自动执行；文档站构建失败会阻断合入。

## 六、发布流程

1. **构建**：Godot 导出 Windows/Linux（`export_presets.cfg`：Windows Desktop + Linux x86_64，AGPL 版权信息）。
2. **版本标记**：Git tag（`v1.0.0`）。
3. **Release 发布**：GitHub Release 附带平台安装包 + 校验和。
4. **文档同步**：VitePress 构建部署到 GitHub Pages（`base: '/CourierSim/'`）。

## 七、验收标准

| 项 | 标准 |
|----|------|
| 功能 | 两模式完整可玩，核心闭环无阻塞 Bug |
| 性能 | 桌面 60 FPS，内存合理 |
| 存档 | 跨版本兼容，崩溃不损坏 |
| 数据 | 配置合法、路网连通、矩阵对称 |
| 文档 | 规划/架构/玩法文档完整 |
| 合规 | AGPL 许可证 + 数据署名齐全 |

## 八、发布检查清单

- [ ] Windows/Linux 导出成功并可启动
- [ ] 存档迁移测试通过（旧档→新档）
- [ ] 性能 Profiler 无热点超标
- [ ] 中英文案无乱码/缺失
- [ ] 素材许可记录完整
- [ ] LICENSE + CREDITS 齐全
- [ ] README 指向文档站
