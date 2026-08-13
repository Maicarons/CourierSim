extends Control
class_name AchievementBanner

## 成就解锁横幅：屏幕顶部滑入横幅（图标 + 「成就解锁」+ 名称），2.8 秒后滑出。
## 挂载在 GameScene，监听 EventBus.achievement_unlocked。

var _panel: PanelContainer
var _icon: TextureRect
var _title: Label
var _name: Label
var _tween: Tween
var _queue: Array[String] = []
var _busy := false

const SHOW_TIME := 2.8


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.achievement_unlocked.connect(_on_unlocked)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panel.offset_left = 0
	_panel.offset_top = -120
	_panel.offset_right = 0
	_panel.offset_bottom = -64
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _style())
	add_child(_panel)

	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	_panel.add_child(hb)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(40, 40)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(_icon)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(col)
	_title = Label.new()
	_title.text = Localization.t("toast.ach_banner")
	_title.add_theme_font_size_override("font_size", 12)
	_title.add_theme_color_override("font_color", UI.YELLOW)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 20)
	_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_name)


func _style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.10, 0.08, 0.97)
	sb.border_color = UI.YELLOW
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	return sb


func _on_unlocked(id: String) -> void:
	_queue.append(id)
	if not _busy:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var id: String = _queue.pop_front()
	# 从成就定义找图标与名称
	var icon := Assets.get_image("ui_flag")
	var nm := id
	if GameManager.ach_sys != null:
		for d in GameManager.ach_sys.defs:
			if d.get("id", "") == id:
				icon = Assets.get_image(d.get("icon", "ui_flag"))
				nm = GameManager.ach_sys.display_name(d)
				break
	_icon.texture = icon
	_name.text = nm
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "position:y", 120.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(SHOW_TIME)
	_tween.tween_property(_panel, "position:y", -120.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_show_next)
