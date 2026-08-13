extends Node
## 存档系统：JSON 序列化 + 版本迁移 + 原子写（.tmp 写入后 rename，防止崩溃损坏）。
## 多槽位，金额与进度完整保存。

const SAVE_DIR := "user://saves"
const EXT := ".json"

func _ready() -> void:
	ensure_dir()

func ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func slot_path(slot: String) -> String:
	return SAVE_DIR + "/" + slot + EXT

func save_slot(slot: String) -> bool:
	ensure_dir()
	var data: Dictionary = GameManager.to_dict()
	data["saved_at"] = Time.get_datetime_string_from_system()
	var text := JSON.stringify(data, "\t")
	var tmp := slot_path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		EventBus.toast.emit(Localization.t("toast.save_fail"))
		return false
	f.store_string(text)
	f.close()
	# 原子替换
	if FileAccess.file_exists(slot_path(slot)):
		DirAccess.remove_absolute(slot_path(slot))
	DirAccess.rename_absolute(tmp, slot_path(slot))
	EventBus.toast.emit(Localization.t("toast.saved") % slot)
	return true

func load_slot(slot: String) -> bool:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		EventBus.toast.emit(Localization.t("toast.save_missing") % slot)
		return false
	var text := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text)
	if not (data is Dictionary):
		EventBus.toast.emit(Localization.t("toast.save_corrupt"))
		return false
	migrate(data)
	GameManager.from_dict(data)
	GameManager.active_slot = slot
	EventBus.toast.emit(Localization.t("toast.loaded") % slot)
	return true

## 版本迁移：未来格式升级时在此兼容旧档
func migrate(data: Dictionary) -> void:
	var v: int = int(data.get("version", 1))
	if v < 1:
		data["version"] = 1
	# 后续版本在此添加 data["version"] == 1 -> 2 的转换

func list_slots() -> Array:
	ensure_dir()
	var out := []
	var dir := DirAccess.open(SAVE_DIR)
	dir.list_dir_begin()
	var fn := dir.get_next()
	while fn != "":
		if fn.ends_with(EXT):
			var slot := fn.substr(0, fn.length() - EXT.length())
			var text := FileAccess.get_file_as_string(slot_path(slot))
			var info = JSON.parse_string(text)
			var meta := {"slot": slot, "saved_at": "", "day": 0, "company": "", "region": ""}
			if info is Dictionary:
				meta["saved_at"] = info.get("saved_at", "")
				meta["day"] = info.get("day", 0)
				meta["company"] = info.get("company_name", "")
				meta["region"] = info.get("region_id", "")
			out.append(meta)
		fn = dir.get_next()
	dir.list_dir_end()
	return out

func delete_slot(slot: String) -> void:
	var p := slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
		EventBus.toast.emit(Localization.t("toast.save_deleted") % slot)

## 下一个空闲槽位（slot_1..slot_9）；全满则返回 "slot_9"（可覆盖）。
func next_free_slot() -> String:
	ensure_dir()
	for i in range(1, 10):
		var s := "slot_%d" % i
		if not FileAccess.file_exists(slot_path(s)):
			return s
	return "slot_9"

## 是否存在某槽位
func has_slot(slot: String) -> bool:
	return FileAccess.file_exists(slot_path(slot))

## 槽位显示名（slot_1 -> "存档 1"）
func slot_label(slot: String) -> String:
	if slot == "autosave":
		return Localization.t("save.autosave")
	if slot.begins_with("slot_"):
		return Localization.t("save.slot") % slot.trim_prefix("slot_")
	return slot
