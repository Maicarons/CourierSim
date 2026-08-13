# 存档系统

存档是模拟经营游戏的"生命线"，采用**JSON + 版本迁移 + 原子写**的成熟方案，保证跨版本兼容与崩溃安全。

## 一、格式选择

| 方案 | 优劣 | 结论 |
|------|------|------|
| JSON + FileAccess | 可读、可 diff、易迁移 | ✅ 主选 |
| ResourceSaver (.tres) | 类型安全，但重构易坏档 | 不用于存档 |
| 二进制 store_var | 紧凑，但难迁移/调试 | 不用于存档 |
| ConfigFile | 仅适合小配置 | 只存设置 |

## 二、存档数据结构

```json
{
  "version": 3,
  "meta": {
    "slot": 0,
    "mode": "career",
    "timestamp": 1723456789,
    "playtime_sec": 36000,
    "current_region": "korea",
    "current_day": 128
  },
  "company": {
    "name": "我的快递",
    "cash_cents": 1234567,
    "credit_score": 80,
    "loans": [],
    "tech_unlocked": ["auto_sort_1"],
    "awareness": { "korea": {"首尔": 45, "釜山": 30} }
  },
  "fleet": {
    "vehicle_001": {
      "model": "van", "home_hub": "hub_seoul_1",
      "status": "TRANSIT", "odometer_km": 12000,
      "condition": 0.85, "assigned_route": "..."
    }
  },
  "hubs": {
    "hub_seoul_1": { "level": 2, "position": {"x": 100, "y": 200}, "...": "..." }
  },
  "stations": { "...": "..." },
  "staff": { "...": "..." },
  "regions": {
    "korea": { "...": "..." },
    "vietnam": { "...": "..." }   // 各区域资产独立
  }
}
```

## 三、SaveManager 实现

```gdscript
class_name SaveManager
extends Node

const SAVE_DIR := "user://saves/"
const SAVE_VERSION := 3
const MAX_SLOTS := 8

func save_game(slot: int) -> bool:
    var data := _serialize_all()
    data["version"] = SAVE_VERSION
    var path := _slot_path(slot)
    _atomic_write(path, JSON.stringify(data, "\t"))

func load_game(slot: int) -> Dictionary:
    var path := _slot_path(slot)
    if not FileAccess.file_exists(path):
        return _default_save()
    var text := FileAccess.get_file_as_string(path)
    var data := JSON.parse_string(text)
    if data == null:
        return _default_save()   # 损坏则回退默认
    data = _migrate(data)
    _deserialize_all(data)
    return data
```

## 四、原子写（防崩溃损坏）

先写临时文件，成功后原子替换，失败保留旧档：

```gdscript
func _atomic_write(path: String, text: String):
    var tmp := path + ".tmp"
    var f := FileAccess.open(tmp, FileAccess.WRITE)
    if f == null: return
    f.store_string(text)
    f = null   # 关闭
    # 校验临时文件可读
    var check := FileAccess.open(tmp, FileAccess.READ)
    if check == null or JSON.parse_string(check.get_as_text()) == null:
        return   # 临时文件坏，保留旧档
    DirAccess.open("user://saves").rename(path.get_file() + ".tmp", path.get_file())
```

## 五、版本迁移

```gdscript
func _migrate(data: Dictionary) -> Dictionary:
    var v: int = data.get("version", 0)
    if v < 2:
        data = _migrate_v1_to_v2(data)
    if v < 3:
        data = _migrate_v2_to_v3(data)
    data["version"] = SAVE_VERSION
    return data
```

- 每次更新存档结构，新增迁移函数，旧档逐级升级。
- **字段增删**：新增字段给默认值，删除字段忽略即可，无需破坏旧档。

## 六、多槽位与元信息

- 最多 8 个槽位，`get_slot_info()` 返回各槽是否占用 + 元信息（时间/模式/游戏天数/公司名）。
- 槽位选择界面只读元信息，不加载完整存档（快速）。

## 七、序列化注意事项

1. **Vector2 → `{x,y}`**：JSON 不支持 Vector2，手动转换。
2. **枚举 → int/string**：存字符串或 int，加载时再转回。
3. **引用 → id**：对象间只存 id（字符串），不存对象引用，避免循环。
4. **int 类型**：JSON 解析后数字变 float，加载时 `int()` 强转。

## 八、自动存档

- **自动存档点**：每日 tick 结束、关键操作（购车/建站）、进入/退出区域。
- **定时兜底**：每 5 分钟自动保存到"自动槽"。
- 避免在渲染帧内做大量序列化，放后台线程或 tick 间隙。

## 九、设置存档（ConfigFile）

音量、分辨率、键位等设置用内置 `ConfigFile` 存 `user://settings.cfg`，与进度存档分离。

## 十、加密（可选）

若需防轻度改档，用 `FileAccess.open_encrypted_with_pass`，密钥编译进脚本。**注意**：只能防"文本编辑器手改"，不防逆向，单机游戏无需强加密。
