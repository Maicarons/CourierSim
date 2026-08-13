extends Node
class_name TutorialSystem

## 生涯模式剧情引导（教程/对白/任务渐进式）。
## 数据驱动 beat 列表：每个 beat 有一个达成条件（Callable），
## 条件满足时立即触发对白（庆祝 + 讲解）并推进到下一目标。
## 沙盒模式自动禁用；进度持久化在 GameManager.tutorial_step。

signal beat_triggered(beat: Dictionary)
signal objective_changed(text_key: String)
signal tutorial_completed

var beats: Array[Dictionary] = []
var _index := 0
var _started := false


func begin() -> void:
	if GameManager.mode != "career":
		_started = true
		return
	if beats.is_empty():
		_build()
	_started = true
	_index = maxi(0, GameManager.tutorial_step)
	# 从头开始：先放开场对白
	if _index == 0 and GameManager.tutorial_step <= 0:
		_index = 1
		GameManager.tutorial_step = _index
		beat_triggered.emit(beats[0])
	_emit_objective()


func check() -> void:
	if not _started or GameManager.mode != "career":
		return
	if beats.is_empty():
		return
	while _index < beats.size():
		var b: Dictionary = beats[_index]
		var cond: Callable = b.get("cond", Callable())
		if not (cond.is_valid() and cond.call()):
			break
		var finished: Dictionary = b
		_index += 1
		GameManager.tutorial_step = _index
		beat_triggered.emit(finished)
		if _index >= beats.size():
			tutorial_completed.emit()
			objective_changed.emit("")
			return
		_emit_objective()


func _emit_objective() -> void:
	if _index < beats.size():
		objective_changed.emit(beats[_index].obj_key)
	else:
		objective_changed.emit("")


func current_objective() -> String:
	if _index < beats.size():
		return Localization.t(beats[_index].obj_key)
	return ""


# ================= 条件 =================

func _has_vehicle() -> bool:
	return GameManager.vehicles.size() > 0

func _has_delivery() -> bool:
	for o in GameManager.orders:
		if o.status == Order.Status.DELIVERED:
			return true
	return false

func _has_second_hub() -> bool:
	return GameManager.hubs.size() > 1

func _has_station() -> bool:
	return GameManager.stations.size() > 0

func _has_staff() -> bool:
	return GameManager.staff.size() > 0

func _has_tech() -> bool:
	for t in GameManager.techs:
		if t.unlocked:
			return true
	return false

func _has_share10() -> bool:
	# 需至少 2 家对手，市占 10% 才有竞争意义
	return GameManager.competitor_sys.competitors.size() >= 2 \
		and GameManager.competitor_sys.player_share() >= 0.10

func _has_share25() -> bool:
	return GameManager.competitor_sys.competitors.size() >= 3 \
		and GameManager.competitor_sys.player_share() >= 0.25


# ================= 数据 =================

func _mk(id: String, speaker_key: String, icon: String,
		text_key: String, obj_key: String, cond: Callable) -> Dictionary:
	return {
		"id": id,
		"speaker_key": speaker_key,
		"icon": icon,
		"text_key": text_key,
		"obj_key": obj_key,
		"cond": cond,
	}


func _build() -> void:
	beats = [
		_mk("intro", "tut.speaker.narrator", "char_courier",
			"tut.intro", "", Callable()),
		_mk("buy_vehicle", "tut.speaker.ceo", "bld_hq",
			"tut.after_vehicle", "tut.obj.buy_vehicle", _has_vehicle),
		_mk("first_delivery", "tut.speaker.ceo", "ui_order",
			"tut.after_delivery", "tut.obj.first_delivery", _has_delivery),
		_mk("build_hub", "tut.speaker.ceo", "bld_hub",
			"tut.after_hub", "tut.obj.build_hub", _has_second_hub),
		_mk("build_station", "tut.speaker.ceo", "bld_station",
			"tut.after_station", "tut.obj.build_station", _has_station),
		_mk("hire_staff", "tut.speaker.ceo", "char_courier",
			"tut.after_staff", "tut.obj.hire_staff", _has_staff),
		_mk("unlock_tech", "tut.speaker.ceo", "ui_tech",
			"tut.after_tech", "tut.obj.unlock_tech", _has_tech),
		_mk("share10", "tut.speaker.ceo", "ui_finance",
			"tut.after_share", "tut.obj.share10", _has_share10),
		_mk("share25", "tut.speaker.ceo", "ui_flag",
			"tut.after_share25", "tut.obj.share25", _has_share25),
	]