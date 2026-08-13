extends Control
class_name About

## 独立全屏关于页（非弹窗）：版本、描述、技术栈、数据来源、致谢、许可。

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Localization.locale_changed.connect(_on_locale_changed, CONNECT_DEFERRED)
	_build()


func _build() -> void:
	for ch in get_children():
		ch.free()
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.93, 0.88, 0.76)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 56
	top.add_theme_stylebox_override("panel", UI._cartoon_style(UI.CREAM, UI.INK, 0, 12))
	add_child(top)
	var thb := HBoxContainer.new()
	thb.add_theme_constant_override("separation", 12)
	top.add_child(thb)
	thb.add_child(UI.icon_only_button(
		Assets.get_image("ui_back"), Localization.t("tip.back"), _on_back, 40))
	var t := Label.new()
	t.text = Localization.t("about.title")
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", UI.ORANGE)
	thb.add_child(t)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 56
	scroll.add_theme_constant_override("v_scroll", 8)
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(640, 0)
	card.add_theme_stylebox_override("panel", UI._cartoon_style(UI.CREAM, UI.INK, 16, 22))
	center.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	card.add_child(vb)

	# Logo + 标题
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	vb.add_child(top_row)
	var logo := Assets.get_image("logo")
	if logo != null:
		var lr := TextureRect.new()
		lr.texture = logo
		lr.custom_minimum_size = Vector2(96, 96)
		lr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		top_row.add_child(lr)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 4)
	top_row.add_child(titles)
	var tn := Label.new()
	tn.text = Localization.t("menu.title")
	tn.add_theme_font_size_override("font_size", 28)
	tn.add_theme_color_override("font_color", UI.YELLOW)
	titles.add_child(tn)
	var ver := Label.new()
	ver.text = "v%s  ·  AGPL-3.0" % ProjectSettings.get_setting("application/config/version", "0.4.0")
	ver.add_theme_font_size_override("font_size", 12)
	ver.add_theme_color_override("font_color", UI.INK)
	titles.add_child(ver)

	# 描述
	var desc := Label.new()
	desc.text = Localization.t("about.desc")
	desc.add_theme_color_override("font_color", UI.INK)
	desc.add_theme_font_size_override("font_size", 14)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)

	# 段落 helper
	vb.add_child(_section(Localization.t("about.tech"), Localization.t("about.tech_text")))
	vb.add_child(_section(Localization.t("about.data"), Localization.t("about.data_text")))
	vb.add_child(_section(Localization.t("about.assets"), Localization.t("about.assets_text")))
	vb.add_child(_section(Localization.t("about.license"), Localization.t("about.license_text")))
	vb.add_child(_section(Localization.t("about.thanks"), Localization.t("about.thanks_text")))


func _section(title: String, body: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var t := Label.new()
	t.text = title
	t.add_theme_color_override("font_color", UI.ORANGE)
	t.add_theme_font_size_override("font_size", 16)
	v.add_child(t)
	var b := Label.new()
	b.text = body
	b.add_theme_color_override("font_color", UI.INK)
	b.add_theme_font_size_override("font_size", 13)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(b)
	return v


func _on_back() -> void:
	if GameManager.company_name != "":
		get_tree().change_scene_to_file("res://src/scenes/GameScene.tscn")
	else:
		get_tree().change_scene_to_file("res://src/scenes/MainMenu.tscn")


func _on_locale_changed(_l: String) -> void:
	_build()