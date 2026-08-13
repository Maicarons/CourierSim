extends Control
class_name DialogueBox

## 剧情对白框：底部分隔面板 + 发言者 + 立绘图标 + 逐行打字机文本 + 继续按钮。
## 支持多行文本逐句推进（按 \n 分段），结束后回调 on_closed。
## 半透明遮罩拦截点击，避免对白期间误触地图/按钮。

var _dim: ColorRect
var _panel: PanelContainer
var _portrait: TextureRect
var _speaker: Label
var _text: Label
var _next_btn: Button
var _lines: Array[String] = []
var _line_index := 0
var _chars_shown := 0
var _typing := false
var _on_closed: Callable = Callable()
var _tween: Tween

const TYPE_SPEED := 28.0   # 每秒显示的字符数


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.05, 0.04, 0.03, 0.55)
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -190
	_panel.offset_bottom = -16
	_panel.offset_left = 90
	_panel.offset_right = -90
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	_panel.add_child(hb)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(64, 64)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(_portrait)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	hb.add_child(col)

	_speaker = Label.new()
	_speaker.add_theme_color_override("font_color", UI.YELLOW)
	_speaker.add_theme_font_size_override("font_size", 17)
	col.add_child(_speaker)

	_text = Label.new()
	_text.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90))
	_text.add_theme_font_size_override("font_size", 15)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 76)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_text)

	var foot := HBoxContainer.new()
	col.add_child(foot)
	foot.add_child(UI.spacer())
	_next_btn = UI.primary_button(Localization.t("dlg.continue"), UI.ORANGE, _on_next)
	_next_btn.custom_minimum_size = Vector2(140, 38)
	foot.add_child(_next_btn)


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.13, 0.10, 0.97)
	sb.border_color = UI.ORANGE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	return sb


## 打开对白。lines 按 \n 分段逐句推进；on_closed 在全部说完后回调。
func show_dialogue(speaker: String, icon: Texture2D, lines: Array[String], on_closed: Callable = Callable()) -> void:
	_lines = []
	for l in lines:
		_lines.append_array(l.split("\n"))
	_line_index = 0
	_on_closed = on_closed
	_speaker.text = speaker
	_portrait.texture = icon
	if icon == null:
		_portrait.visible = false
	else:
		_portrait.visible = true
	visible = true
	modulate.a = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.22)
	_start_line()


func _start_line() -> void:
	_chars_shown = 0
	_typing = true
	_next_btn.text = Localization.t("dlg.continue")


func _process(delta: float) -> void:
	if not visible or not _typing:
		return
	var line: String = _lines[_line_index] if _line_index < _lines.size() else ""
	_chars_shown = mini(_chars_shown + int(TYPE_SPEED * delta * 60.0 / 60.0) + 1, line.length())
	_text.text = line.substr(0, _chars_shown)
	if _chars_shown >= line.length():
		_typing = false
		_next_btn.text = Localization.t("dlg.continue")


func _on_next() -> void:
	if _typing:
		# 打字中：直接显示整句
		var line: String = _lines[_line_index] if _line_index < _lines.size() else ""
		_chars_shown = line.length()
		_text.text = line
		_typing = false
		_next_btn.text = Localization.t("dlg.continue")
		return
	_line_index += 1
	if _line_index < _lines.size():
		_start_line()
	else:
		_close()


func _close() -> void:
	visible = false
	_text.text = ""
	if _on_closed.is_valid():
		var cb := _on_closed
		_on_closed = Callable()
		cb.call()


## 是否正在显示对白。
func is_open() -> bool:
	return visible
