extends CanvasLayer

## 全局悬浮提示（Tooltip）管理器。
## 为任意 Control 注册提示文本后，鼠标悬停一小段延迟即在光标旁显示
## 卡通风格提示气泡，移出即隐藏。图标驱动的 UI 全靠它解释功能，
## 保证新玩家无需文字按钮也能理解每个图标的含义。

const DELAY := 0.32        # 悬停多久后显示（秒）
const OFFSET := Vector2(14, 18)

var _panel: PanelContainer
var _label: Label
var _current: Control = null
var _text := ""
var _pending := false


func _ready() -> void:
	layer = 200
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _style())
	_label = Label.new()
	_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))
	_label.add_theme_font_size_override("font_size", 13)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_label)
	add_child(_panel)


func _style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.10, 0.08, 0.97)
	sb.border_color = Color(1.0, 0.62, 0.20)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	return sb


## 注册悬浮提示：悬停在 control 上时显示 text。
func register(control: Control, text: String) -> void:
	if control == null or text.strip_edges() == "":
		return
	control.mouse_entered.connect(_on_enter.bind(control, text))
	control.mouse_exited.connect(_on_exit.bind(control))


func _on_enter(control: Control, text: String) -> void:
	_current = control
	_text = text
	_pending = true
	var tw := get_tree().create_timer(DELAY)
	tw.timeout.connect(_on_delay)


func _on_delay() -> void:
	if _pending and _current != null and _current.is_visible_in_tree():
		_show()


func _show() -> void:
	_pending = false
	_label.text = _text
	_panel.visible = true
	_follow()


func _follow() -> void:
	var mpos := get_viewport().get_mouse_position()
	var vs := get_viewport().get_visible_rect().size
	var psz := _panel.get_combined_minimum_size()
	var pos := mpos + OFFSET
	if pos.x + psz.x > vs.x - 4:
		pos.x = mpos.x - psz.x - 8
	if pos.y + psz.y > vs.y - 4:
		pos.y = mpos.y - psz.y - 8
	_panel.position = pos.max(Vector2(4, 4))


func _process(_delta: float) -> void:
	if _panel.visible:
		_follow()
	elif _current != null and not _current.is_visible_in_tree():
		_current = null
		_pending = false


func _on_exit(control: Control) -> void:
	if _current == control:
		_current = null
		_pending = false
		_panel.visible = false
