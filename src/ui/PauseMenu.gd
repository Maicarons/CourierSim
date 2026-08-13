extends Control
class_name PauseMenu

## 游戏内暂停菜单（ESC）：半透明遮罩 + 居中卡片 + 图标化按钮。
## 打开时自动暂停时间，关闭时恢复之前的倍速。管理模拟标配菜单。

signal settings_requested
signal about_requested
signal menu_requested

var _prev_speed := 1
var _panel: PanelContainer
var _confirm: ConfirmDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	Localization.locale_changed.connect(_on_locale_changed, CONNECT_DEFERRED)
	_build()


func _on_locale_changed(_l: String) -> void:
	_build()


func _build() -> void:
	for ch in get_children():
		ch.queue_free()

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.04, 0.03, 0.65)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(380, 0)
	_panel.add_theme_stylebox_override("panel", UI._cartoon_style(UI.CREAM, UI.INK, 18, 26))
	center.add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_panel.add_child(vb)

	var title := Label.new()
	title.text = Localization.t("pause.title")
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UI.ORANGE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var sub := Label.new()
	sub.text = Localization.t("pause.hint")
	sub.add_theme_color_override("font_color", Color(0.5, 0.45, 0.38))
	sub.add_theme_font_size_override("font_size", 12)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)

	var sep := HSeparator.new()
	vb.add_child(sep)

	vb.add_child(_menu_btn(Localization.t("pause.resume"), "ui_play", UI.GREEN,
		Localization.t("pause.resume"), close))
	vb.add_child(_menu_btn(Localization.t("pause.save"), "ui_save", UI.BLUE,
		Localization.t("tip.save"), _on_save))
	vb.add_child(_menu_btn(Localization.t("menu.settings"), "ui_settings", UI.PURPLE,
		Localization.t("tip.settings"), func(): settings_requested.emit()))
	vb.add_child(_menu_btn(Localization.t("menu.about"), "ui_about", UI.YELLOW,
		Localization.t("tip.about"), func(): about_requested.emit()))
	vb.add_child(_menu_btn(Localization.t("menu.menu"), "ui_home", UI.RED,
		Localization.t("tip.menu"), _on_menu))

	_confirm = ConfirmDialog.new()
	add_child(_confirm)


func _menu_btn(text: String, icon: String, color: Color, tooltip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	b.add_theme_font_size_override("font_size", 17)
	if Assets.get_image(icon) != null:
		b.icon = UI._scaled_icon(Assets.get_image(icon), 26)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_stylebox_override("normal", UI._cartoon_style(color, UI.INK, 12, 14))
	b.add_theme_stylebox_override("hover", UI._cartoon_style(color.lightened(0.12), UI.INK, 12, 14))
	b.add_theme_stylebox_override("pressed", UI._cartoon_style(color.darkened(0.18), UI.INK, 12, 14))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	AudioManager.attach_click(b)
	Tooltips.register(b, tooltip)
	return b


## 打开菜单并暂停（记录原倍速）
func open() -> void:
	if visible:
		return
	_prev_speed = TimeSystem.speed_index
	TimeSystem.set_speed(0)
	visible = true
	_panel.grab_focus()


## 关闭菜单并恢复原倍速
func close() -> void:
	if not visible:
		return
	visible = false
	if GameManager.company_name != "" and not GameManager.game_over_emitted:
		TimeSystem.set_speed(_prev_speed)


func is_open() -> bool:
	return visible


func _on_save() -> void:
	SaveManager.save_slot(GameManager.active_slot)


func _on_menu() -> void:
	if not _confirm.is_open():
		_confirm.ask(Localization.t("confirm.quit_title"), Localization.t("confirm.quit_msg"),
			func(): menu_requested.emit())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		if _confirm.is_open():
			return
		if is_open():
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
