extends Node
## 全局音频管理器：BGM、SFX、按钮点击反馈，以及音量总线（设置页可调）。
## 运行时自动创建 BGM / SFX 两条总线并汇入 Master，音量持久化到
## user://settings.cfg 的 [audio] 段。

const BUS_BGM := "BGM"
const BUS_SFX := "SFX"
const SETTINGS_PATH := "user://settings.cfg"

var _sfx: Dictionary = {}
var _bgm: Dictionary = {}
var _current_bgm := ""

func _ready() -> void:
	_ensure_buses()
	_load_all()
	_apply_volumes()
	EventBus.toast.connect(_on_toast)

# ================= 总线 =================

func _ensure_buses() -> void:
	if not _bus_exists(BUS_BGM):
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_BGM)
		AudioServer.set_bus_send(idx, "Master")
	if not _bus_exists(BUS_SFX):
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_SFX)
		AudioServer.set_bus_send(idx, "Master")

func _bus_exists(name: String) -> bool:
	for i in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) == name:
			return true
	return false

# ================= 加载资源 =================

func _load_all() -> void:
	var sfx_ids := [
		"ui_click", "delivery_done", "new_order", "cash",
		"error", "tech_unlock", "objective_done", "game_over",
	]
	for id in sfx_ids:
		var path := "res://assets/audio/sfx_%s.mp3" % id
		if ResourceLoader.exists(path):
			_sfx[id] = load(path)

	for id in ["menu", "play"]:
		var path := "res://assets/audio/bgm_%s.mp3" % id
		if ResourceLoader.exists(path):
			var s := load(path)
			if s is AudioStreamMP3:
				s.loop = true
			_bgm[id] = s

# ================= 播放 =================

## 播放一次性音效（SFX 总线）。
func play_sfx(id: String) -> void:
	var s := _sfx.get(id) as AudioStream
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = BUS_SFX
	add_child(p)
	p.play()
	p.finished.connect(func(): p.queue_free())

## 切换 BGM（BGM 总线）；同名的重复调用会被忽略。
func play_bgm(id: String) -> void:
	if _current_bgm == id:
		return
	_stop_bgm()
	var s := _bgm.get(id) as AudioStream
	if s == null:
		_current_bgm = ""
		return
	var p := AudioStreamPlayer.new()
	p.name = "BGM_" + id
	p.stream = s
	p.bus = BUS_BGM
	add_child(p)
	p.play()
	_current_bgm = id

func _stop_bgm() -> void:
	for c in get_children():
		if c is AudioStreamPlayer and c.name.begins_with("BGM_"):
			c.stop()
			c.queue_free()
	_current_bgm = ""

# ================= 音量 =================

## 设置某总线音量（0.0 ~ 1.0），并持久化。
func set_bus_volume(bus: String, linear: float) -> void:
	if not _bus_exists(bus):
		return
	linear = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(maxf(linear, 0.0001)))
	_save_volume(bus, linear)

## 读取某总线音量（0.0 ~ 1.0）。
func get_bus_volume(bus: String) -> float:
	if not _bus_exists(bus):
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus)))

func _apply_volumes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for bus in [BUS_BGM, BUS_SFX, "Master"]:
		var v: Variant = cfg.get_value("audio", bus.to_lower() + "_vol", -1.0)
		if typeof(v) == TYPE_FLOAT and v >= 0.0:
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(maxf(v, 0.0001)))

func _save_volume(bus: String, linear: float) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", bus.to_lower() + "_vol", linear)
	cfg.save(SETTINGS_PATH)

# ================= 按钮音效 =================

## 给按钮附加点击音效。
func attach_click(b: Button) -> void:
	if b == null:
		return
	if not b.pressed.is_connected(_play_ui_click):
		b.pressed.connect(_play_ui_click)

func _play_ui_click() -> void:
	play_sfx("ui_click")

# ================= toast 关键词音效 =================

func _on_toast(message: String) -> void:
	var lower := message.to_lower()
	if _has_any(lower, ["送达", "deliver", "完成", "finish"]):
		play_sfx("delivery_done")
	elif _has_any(lower, ["订单", "order"]):
		play_sfx("new_order")
	elif _has_any(lower, ["资金", "现金", "money", "cash", "收入", "盈利"]):
		play_sfx("cash")
	elif _has_any(lower, ["失败", "不足", "error", "fail", "无法"]):
		play_sfx("error")
	elif _has_any(lower, ["科技", "tech", "解锁", "upgrade"]):
		play_sfx("tech_unlock")
	elif _has_any(lower, ["目标", "objective", "成就"]):
		play_sfx("objective_done")
	elif _has_any(lower, ["破产", "bankrupt", "游戏结束", "game over"]):
		play_sfx("game_over")

func _has_any(text: String, keys: Array) -> bool:
	for k in keys:
		if text.find(k) != -1:
			return true
	return false
