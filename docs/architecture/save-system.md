# 存档系统（GameSave）

> 适用版本：v0.12 · JSON + 版本迁移 + 原子写 · 多槽位

存档采用 **JSON + 版本迁移 + 原子写**，实现于 `src/save/GameSave.gd` 与 `src/autoload/SaveManager.gd`。

## 一、格式选择

| 方案 | 优劣 | 结论 |
|------|------|------|
| JSON + FileAccess | 可读、可 diff、易迁移 | ✅ 主选 |
| ResourceSaver (.tres) | 类型安全，但重构易坏档 | 不用于存档 |
| 二进制 store_var | 紧凑，但难迁移/调试 | 不用于存档 |
| ConfigFile | 仅适合小配置 | 只存设置（`user://settings.cfg`） |

## 二、存档结构（GameSave.to_dict / from_dict）

```json
{
  "version": 1,
  "mode": "career",
  "day": 12,
  "hour_of_day": 7,
  "money": 842000,
  "reputation": 62.0,
  "company_name": "我的快递",
  "region_id": "korea",
  "unlocked_regions": ["korea"],
  "modifiers": { "demand_mult": 1.0, "speed_mult": 1.0 },
  "id_counter": 42,
  "objective_done": { "obj.build_hub": true },
  "tutorial_step": 3,
  "achievements": ["ach.first_order"],
  "debt": 0,
  "vehicles": [
    { "id": "veh_1", "name": "面包车 1", "type": 0, "capacity_kg": 500,
      "speed_kmh": 70, "km_per_day": 620, "cost": 60000,
      "fuel_per_km": 0.6, "maintenance_per_day": 80,
      "capabilities": 0, "owned": true, "lease_daily": 1200,
      "assigned_hub_id": "", "home_city_id": "seoul",
      "status": 1, "current_order_id": "ord_1",
      "route_from": [0, 0], "route_to": [0, 0],
      "route_path": [[x, y], "..."],
      "travel_progress": 0.3, "travel_total_days": 0.4, "travel_elapsed_days": 0.12 }
  ],
  "hubs": [{ "id": "hub_1", "name": "首尔中转仓", "city_id": "seoul", "level": 1 }],
  "stations": [{ "id": "st_1", "city_id": "busan", "marketing_level": 0 }],
  "orders": [{ "id": "ord_1", "origin_id": "seoul", "dest_id": "busan", "..." }],
  "staff": [ "..." ],
  "techs": [true, false, "..."],
  "sandbox_cfg": { "funds_mult": 1.0, "events": true, "competition": 1 }
}
```

v0.12 新增字段：`hour_of_day`（小时制）、`debt`（负债）、车辆 `owned` / `lease_daily` / `route_path`（折线行程）。

## 三、SaveManager 实现

```gdscript
# src/autoload/SaveManager.gd（摘录）
const SAVE_DIR := "user://saves/"
const MAX_SLOTS := 9

func next_free_slot() -> String   # slot_1..slot_9 中第一个空槽
func has_slot(slot: String) -> bool
func save_game(slot: String, data: Dictionary) -> bool   # 原子写
func load_game(slot: String) -> Dictionary               # 读 + 版本迁移 + 容错
func slot_label(slot: String) -> String                  # 槽位显示名
func delete_slot(slot: String) -> void
```

- 存档文件：`user://saves/<slot>.json`（`GameSave.to_dict/from_dict` 序列化）。
- 读取后 `GameSave.from_dict` 回填 GameManager，`game_over_emitted` 重置允许重新判定胜负。

## 四、原子写（防崩溃损坏）

先写临时文件，成功后原子替换，失败保留旧档：

```gdscript
func _atomic_write(path: String, text: String) -> bool:
    var tmp := path + ".tmp"
    var f := FileAccess.open(tmp, FileAccess.WRITE)
    if f == null: return false
    f.store_string(text)
    f = null
    var check := FileAccess.open(tmp, FileAccess.READ)
    if check == null or JSON.parse_string(check.get_as_text()) == null:
        DirAccess.remove_absolute(tmp)   # 临时文件坏，丢弃
        return false
    # 替换正式文件
    DirAccess.rename_absolute(tmp, path)
    return true
```

## 五、版本迁移

- `version` 字段用于迁移；`from_dict` 对缺失字段用 `d.get(key, 默认值)` 兜底，旧档自动补新字段默认值（如 `debt=0`、`owned=true`、`hour_of_day=0`）。
- **字段增删策略**：新增字段给默认值，删除字段忽略，无需破坏旧档。

## 六、多槽位与交互

| 槽位 | 用途 |
|---|---|
| `slot_1` ~ `slot_9` | 手动/新建存档 |
| `autosave` | 兼容旧版本保留 |

- **主菜单 → 继续游戏**：槽位面板列出所有槽位（公司名 / Day / 区域 / 保存时间），可读取或删除。
- **主菜单 → 新游戏**：写入 `next_free_slot()`（不覆盖已有存档），绑定为活跃槽位。
- **游戏内保存**（顶栏 💾）：保存到当前活跃槽位；**自动存档**：每日结算后写 autosave。

## 七、序列化注意事项

1. **Vector2 → [x, y]**：JSON 不支持 Vector2，手动转数组（`route_from`/`route_to`/`route_path` 均如此）。
2. **枚举 → int**：存 int，加载 `int()` 强转回。
3. **引用 → id**：对象间只存 id（字符串），不存对象引用，避免循环。
4. **int 类型**：JSON 解析后数字变 float，加载时 `int()` 强转。

## 八、设置存档（ConfigFile）

音量（Master/BGM/SFX）等设置用内置 `ConfigFile` 存 `user://settings.cfg`（`AudioManager`），与进度存档分离。

## 九、加密（可选）

若需防轻度改档，用 `FileAccess.open_encrypted_with_pass`；仅防"文本编辑器手改"，单机游戏无需强加密。
