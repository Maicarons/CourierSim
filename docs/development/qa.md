# 测试与发布

## 一、测试策略

| 层级 | 工具 | 覆盖 |
|------|------|------|
| 单元测试 | GUT | 核心逻辑（货量公式、距离、状态机、财务） |
| 集成测试 | GUT | 系统间交互（购车→调度→结算） |
| 数据校验 | Python 脚本 | 配置/地理数据合法性 |
| 手动测试 | 人工 | 玩法体验、UI、平衡 |
| 性能测试 | Profiler | 帧率、内存 |

## 二、单元测试重点

```
tests/
├── test_geo_utils.gd        # 坐标转换、Haversine
├── test_distance.gd         # 距离矩阵、兜底
├── test_demand.gd           # 货量公式
├── test_flow.gd             # 货单状态机
├── test_finance.gd          # 收入/成本/贷款
├── test_save.gd             # 存档读写/迁移
├── test_fleet.gd            # 车辆调度
└── test_tech.gd             # 科技树解锁
```

**必测公式**：货量生成、成本计算、时效、评分、破产边界。

## 三、CI 流水线

```yaml
# .github/workflows/ci.yml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: GDScript 静态检查（gdformat / headless 解析）
        run: godot --headless --check-only
      - name: 数据校验
        run: python tools/validate_data.py
      - name: 单元测试（GUT）
        run: godot --headless -s addons/gut/gut_cmdln.gd
```

## 四、发布流程

1. **构建**：Godot 导出 Windows/macOS/Linux（`export_presets.cfg`）。
2. **版本标记**：Git tag（`v1.0.0`）。
3. **Release 发布**：GitHub Release 附带三平台安装包 + 校验和。
4. **文档同步**：VitePress 构建部署到 GitHub Pages。

## 五、构建命令

```bash
# Godot 导出（示例）
godot --headless --export-release "Windows Desktop" build/couriersim.exe
godot --headless --export-release "Linux" build/couriersim.x86_64
godot --headless --export-release "macOS" build/couriersim.zip
```

## 六、验收标准

| 项 | 标准 |
|----|------|
| 功能 | 两模式完整可玩，核心闭环无阻塞 Bug |
| 性能 | 桌面 60 FPS，内存合理 |
| 存档 | 跨版本兼容，崩溃不损坏 |
| 数据 | 配置合法、路网连通、矩阵对称 |
| 文档 | 规划/架构/玩法文档完整 |
| 合规 | AGPL 许可证 + 数据署名齐全 |

## 七、发布检查清单

- [ ] 三平台导出成功并可启动
- [ ] 存档迁移测试通过（旧档→新档）
- [ ] 性能 Profiler 无热点超标
- [ ] 中文文案无乱码/缺失
- [ ] 素材许可记录完整
- [ ] LICENSE + CREDITS 齐全
- [ ] README 指向文档站
