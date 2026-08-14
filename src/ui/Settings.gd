extends Control
class_name Settings

## 独立全屏设置页（非弹窗）：左侧 Tab 切换（音频/显示/语言/存档/游戏），
## 右侧显示对应内容。从游戏进入时自动暂停；返回时由 GameScene 决定恢复。

var _current_section := "audio"
var _section_buttons: Array[Button] = []
var _content: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Localization.locale_changed.connect(_on_locale_changed, CONNECT_DEFERRED)
	_build()


func _build() -> void:
	for ch in get_children():
		ch.free()
	# 整屏背景（卡其色）
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.95, 0.91, 0.79)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 顶栏
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 0
	top.offset_top = 0
	top.offset_right = 0
	top.offset_bottom = 56
	top.add_theme_stylebox_override("panel", UI._cartoon_style(UI.CREAM, UI.INK, 0, 12))
	add_child(top)
	var thb := HBoxContainer.new()
	thb.add_theme_constant_override("separation", 12)
	top.add_child(thb)
	thb.add_child(UI.icon_only_button(
		Assets.get_image("ui_back"), Localization.t("tip.back"), _on_back, 40))
	var t := Label.new()
	t.text = Localization.t("set.title")
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", UI.ORANGE)
	thb.add_child(t)
	thb.add_child(UI.spacer())
	var ver := Label.new()
	ver.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.4.0")
	ver.add_theme_font_size_override("font_size", 12)
	ver.add_theme_color_override("font_color", UI.INK)
	thb.add_child(ver)

	# 主体（Tab 栏 + 内容）
	var body := HBoxContainer.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_top = 56
	body.offset_bottom = 0
	body.add_theme_constant_override("separation", 12)
	add_child(body)
	body.add_child(UI.spacer())
	var inner := HBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 12)
	body.add_child(inner)
	body.add_child(UI.spacer())

	# 左侧 Tab 卡片
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(180, 0)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_theme_stylebox_override("panel", UI._cartoon_style(UI.CREAM, UI.INK, 12, 8))
	inner.add_child(left)
	var lvb := VBoxContainer.new()
	lvb.add_theme_constant_override("separation", 6)
	left.add_child(lvb)
	_section_buttons.clear()
	for section in [["audio", "ui_sound", "set.tab.audio"], ["display", "ui_globe", "set.tab.display"],
			["language", "ui_globe", "set.tab.language"], ["saves", "ui_save", "set.tab.saves"],
			["achievements", "ui_flag", "set.tab.achievements"]]:
		var b := _tab_button(section[0], section[1], section[2])
		_section_buttons.append(b)
		lvb.add_child(b)

	# 右侧内容卡片
	_content = PanelContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_stylebox_override("panel", UI._cartoon_style(UI.CREAM_2, UI.INK, 14, 18))
	inner.add_child(_content)
	_show_section(_current_section)


func _tab_button(section: String, icon: String, title_key: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 48)
	b.set_meta("section", section)
	if Assets.get_image(icon) != null:
		b.icon = UI._scaled_icon(Assets.get_image(icon), 22)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = Localization.t(title_key)
	b.add_theme_color_override("font_color", UI.INK)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_stylebox_override("normal", UI._cartoon_style(UI.CREAM_2, UI.INK, 8, 10))
	b.add_theme_stylebox_override("hover", UI._cartoon_style(UI.CREAM, UI.INK, 8, 10))
	b.add_theme_stylebox_override("pressed", UI._cartoon_style(UI.YELLOW, UI.INK, 8, 10))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_select_section.bind(section))
	AudioManager.attach_click(b)
	Tooltips.register(b, Localization.t(title_key))
	return b


func _select_section(section: String) -> void:
	_current_section = section
	for b in _section_buttons:
		var sel: bool = (b.get_meta("section") == section)
		b.button_pressed = sel
		if sel:
			b.add_theme_stylebox_override("normal", UI._cartoon_style(UI.YELLOW, UI.INK, 8, 10))
	_show_section(section)


func _show_section(section: String) -> void:
	for ch in _content.get_children():
		ch.queue_free()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_content.add_child(vb)
	var h := Label.new()
	h.text = Localization.t("set." + section + ".title")
	h.add_theme_font_size_override("font_size", 20)
	h.add_theme_color_override("font_color", UI.ORANGE)
	vb.add_child(h)
	match section:
		"audio": _fill_audio(vb)
		"display": _fill_display(vb)
		"language": _fill_language(vb)
		"saves": _fill_saves(vb)
		"achievements": _fill_achievements(vb)
	vb.add_child(UI.spacer())


func _fill_achievements(container: Control) -> void:
	var progress := Label.new()
	var total := GameManager.ach_sys.defs.size() if GameManager.ach_sys != null else 0
	var unlocked := GameManager.achievements.size()
	progress.text = Localization.t("ach.progress") % [unlocked, total]
	progress.add_theme_color_override("font_color", UI.GREEN)
	progress.add_theme_font_size_override("font_size", 15)
	container.add_child(progress)

	if GameManager.ach_sys == null:
		return
	for d in GameManager.ach_sys.defs:
		var id: String = d.get("id", "")
		var done: bool = GameManager.achievements.has(id)
		var name := GameManager.ach_sys.display_name(d)
		var desc: String = d.get("desc_en", d.get("desc", "")) if Localization.is_en() else d.get("desc", "")
		var icon := Assets.get_image(d.get("icon", ""))
		var actions: Array = []
		var tag := UI.status_chip(
			Localization.t("ach.unlocked") if done else Localization.t("ach.locked"),
			UI.GREEN if done else UI.CREAM_2)
		tag.find_child("lbl", true, false).add_theme_color_override(
			"font_color", Color(1, 1, 1) if done else UI.INK)
		var row := UI.info_row(icon, name, desc, actions)
		var hb := HBoxContainer.new()
		hb.add_child(tag)
		row.find_child("HBoxContainer", true, false).add_child(hb)
		container.add_child(row)


func _fill_audio(container: Control) -> void:
	for bus in ["Master", AudioManager.BUS_BGM, AudioManager.BUS_SFX]:
		container.add_child(_slider_row(bus))


func _slider_row(bus: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = bus
	lbl.custom_minimum_size = Vector2(120, 0)
	lbl.add_theme_color_override("font_color", UI.INK)
	lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(lbl)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.01
	sl.value = AudioManager.get_bus_volume(bus)
	sl.custom_minimum_size = Vector2(260, 0)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sl)
	var num := Label.new()
	num.text = "%d%%" % int(sl.value * 100)
	num.custom_minimum_size = Vector2(50, 0)
	num.add_theme_color_override("font_color", UI.INK)
	num.add_theme_font_size_override("font_size", 14)
	row.add_child(num)
	sl.value_changed.connect(func(v): AudioManager.set_bus_volume(bus, v); num.text = "%d%%" % int(v * 100))
	Tooltips.register(row, "%s %s" % [bus, Localization.t("set.audio.vol_tip")])
	return row


func _fill_display(container: Control) -> void:
	var fs_btn := Button.new()
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs_btn.text = Localization.t("set.display.fullscreen_on" if is_fullscreen else "set.display.fullscreen_off")
	fs_btn.add_theme_color_override("font_color", UI.INK)
	fs_btn.add_theme_font_size_override("font_size", 14)
	fs_btn.custom_minimum_size = Vector2(220, 40)
	fs_btn.add_theme_stylebox_override("normal", UI._cartoon_style(UI.CREAM, UI.INK, 10, 14))
	fs_btn.add_theme_stylebox_override("hover", UI._cartoon_style(UI.YELLOW, UI.INK, 10, 14))
	fs_btn.add_theme_stylebox_override("pressed", UI._cartoon_style(UI.YELLOW.darkened(0.15), UI.INK, 10, 14))
	fs_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	fs_btn.pressed.connect(_toggle_fullscreen.bind(fs_btn))
	AudioManager.attach_click(fs_btn)
	Tooltips.register(fs_btn, Localization.t("set.display.fullscreen_tip"))
	container.add_child(fs_btn)

	container.add_child(UI.label(Localization.t("set.display.note"), 400))


func _toggle_fullscreen(btn: Button) -> void:
	var cur := DisplayServer.window_get_mode()
	var target := DisplayServer.WINDOW_MODE_WINDOWED if cur == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(target)
	btn.text = Localization.t("set.display.fullscreen_on" if target == DisplayServer.WINDOW_MODE_FULLSCREEN else "set.display.fullscreen_off")


func _fill_language(container: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	container.add_child(row)
	for code in [["zh_CN", "中文", "cn"], ["en_US", "English", "en"]]:
		var btn := Button.new()
		btn.text = code[1]
		btn.custom_minimum_size = Vector2(140, 42)
		var sel: bool = Localization.get_locale() == code[0]
		var color := UI.GREEN if sel else UI.CREAM
		btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0) if sel else UI.INK)
		btn.add_theme_stylebox_override("normal", UI._cartoon_style(color, UI.INK, 10, 14))
		btn.add_theme_stylebox_override("hover", UI._cartoon_style(color.lightened(0.1), UI.INK, 10, 14))
		btn.add_theme_stylebox_override("pressed", UI._cartoon_style(color, UI.INK, 10, 14))
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.pressed.connect(_on_lang_choose.bind(code[0]))
		AudioManager.attach_click(btn)
		Tooltips.register(btn, code[1])
		row.add_child(btn)


func _on_lang_choose(code: String) -> void:
	Localization.set_locale(code)
	_build()


func _fill_saves(container: Control) -> void:
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	container.add_child(top_row)
	var refresh_btn := UI.icon_button(Localization.t("set.saves.refresh"),
		Assets.get_image("ui_arrow_right"), _show_section.bind("saves"),
		Localization.t("set.saves.refresh"))
	refresh_btn.custom_minimum_size = Vector2(120, 38)
	top_row.add_child(refresh_btn)
	var save_now_btn := UI.primary_button(Localization.t("set.saves.save_now"), UI.GREEN, _save_now)
	save_now_btn.custom_minimum_size = Vector2(140, 38)
	top_row.add_child(save_now_btn)

	var slots := SaveManager.list_slots()
	if slots.is_empty():
		container.add_child(UI.label(Localization.t("set.saves.empty"), 400))
		return
	for s in slots:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UI._cartoon_style(UI.CREAM, UI.INK, 8, 10))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		row.add_child(hb)
		hb.add_child(UI.tex_rect(Assets.get_image("ui_save"), 24))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(info)
		var t := Label.new()
		t.text = "%s · Day %d · %s" % [s.get("company", ""), s.get("day", 0), s.get("region", "")]
		t.add_theme_color_override("font_color", UI.INK)
		t.add_theme_font_size_override("font_size", 13)
		info.add_child(t)
		var t2 := Label.new()
		t2.text = "%s · %s" % [s.get("slot", ""), s.get("saved_at", "")]
		t2.add_theme_color_override("font_color", Color(0.45, 0.40, 0.32))
		t2.add_theme_font_size_override("font_size", 11)
		info.add_child(t2)
		var slot_name: String = s["slot"]
		hb.add_child(UI.icon_button(Localization.t("set.saves.load"),
			Assets.get_image("ui_play"), _on_load_slot.bind(slot_name),
			Localization.t("set.saves.load")))
		hb.add_child(UI.icon_button(Localization.t("set.saves.delete"),
			Assets.get_image("ui_trash"), _on_delete_slot.bind(slot_name),
			Localization.t("set.saves.delete")))
		container.add_child(row)


func _save_now() -> void:
	if GameManager.company_name == "":
		EventBus.toast.emit(Localization.t("toast.no_save"))
		return
	SaveManager.save_slot(GameManager.active_slot)
	_show_section("saves")


func _on_load_slot(slot: String) -> void:
	if SaveManager.load_slot(slot):
		get_tree().change_scene_to_file("res://src/scenes/GameScene.tscn")


func _on_delete_slot(slot: String) -> void:
	SaveManager.delete_slot(slot)
	_show_section("saves")


func _on_back() -> void:
	if GameManager.company_name != "":
		get_tree().change_scene_to_file("res://src/scenes/GameScene.tscn")
	else:
		get_tree().change_scene_to_file("res://src/scenes/MainMenu.tscn")


func _on_locale_changed(_l: String) -> void:
	_build()