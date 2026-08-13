extends Node

## 明亮卡通像素风格 UI 构件工厂与状态名翻译助手。
## 配色：奶油白卡片 + 深棕像素描边 + 橙/蓝/绿/黄/红强调色。
## 供 MainMenu、GameScene 与各标签页面板（src/ui/panels/*）复用。

# ===== 卡通配色常量 =====
const INK := Color(0.22, 0.17, 0.13)        # 深棕：像素描边 / 主文字
const CREAM := Color(1.0, 0.97, 0.87)       # 奶油白：主卡片
const CREAM_2 := Color(0.93, 0.88, 0.76)    # 次级奶油：分区背景
const ORANGE := Color(1.0, 0.62, 0.20)
const BLUE := Color(0.27, 0.65, 0.95)
const GREEN := Color(0.42, 0.78, 0.36)
const RED := Color(0.93, 0.33, 0.33)
const YELLOW := Color(1.0, 0.83, 0.25)
const PURPLE := Color(0.66, 0.45, 0.85)
const SKY := Color(0.62, 0.85, 0.98)        # 地图天空蓝

## 生成卡通按钮/卡片样式：粗描边 + 圆角 + 柔和投影。
func _cartoon_style(fill: Color, border: Color, radius: int, pad: int, hover_fill: Color = Color()) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0.0, 3.0)
	if not hover_fill.is_equal_approx(Color()):
		var h := StyleBoxFlat.new()
		h.bg_color = hover_fill
		h.border_color = border
		h.set_border_width_all(3)
		h.set_corner_radius_all(radius)
		h.content_margin_left = pad
		h.content_margin_right = pad
		h.content_margin_top = pad
		h.content_margin_bottom = pad
		h.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
		h.shadow_size = 6
		h.shadow_offset = Vector2(0.0, 4.0)
		return h  # 调用方用它覆盖 hover
	return sb

## 小图标贴图控件（按目标尺寸等比居中）。
func tex_rect(tex: Texture2D, size: int = 24) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = Vector2(size, size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return tr

## 文字标签（INK 主色，供面板复用）。
func label(text: String, min_w := 200) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", INK)
	l.add_theme_font_size_override("font_size", 14)
	l.custom_minimum_size = Vector2(min_w, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

## 图标 + 文字按钮（奶油底 + 深棕描边 + 左图标），标准工具栏风格。
## 注意：图标纹理是 512x512，必须缩放成小图再赋给 Button.icon，
## 否则 Button 会把整张原图算进最小高度（撑成 500+ px 把布局撑爆）。
## tooltip 非空时为该按钮注册悬浮提示。
func icon_button(text: String, icon: Texture2D, cb: Callable, tooltip := "") -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_color_override("font_color", INK)
	b.add_theme_font_size_override("font_size", 14)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if icon != null:
		b.icon = _scaled_icon(icon, 22)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var n := _cartoon_style(CREAM, INK, 10, 8, Color(0.98, 0.94, 0.82))
	b.add_theme_stylebox_override("normal", _cartoon_style(CREAM, INK, 10, 8))
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("pressed", _cartoon_style(CREAM_2, INK, 10, 8))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	AudioManager.attach_click(b)
	if tooltip != "":
		Tooltips.register(b, tooltip)
	return b

## 纯图标按钮（无文字，仅图标 + 悬浮提示）——图标驱动交互的核心组件。
## 用于顶栏工具栏与左侧分组 Tab 栏；tooltip 承担全部文字说明职责。
func icon_only_button(icon: Texture2D, tooltip: String, cb: Callable, size := 40) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if icon != null:
		b.icon = _scaled_icon(icon, int(size * 0.62))
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_stylebox_override("normal", _cartoon_style(CREAM, INK, 10, 4))
	b.add_theme_stylebox_override("hover", _cartoon_style(Color(0.99, 0.95, 0.84), INK, 10, 4))
	b.add_theme_stylebox_override("pressed", _cartoon_style(CREAM_2, INK, 10, 4))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	AudioManager.attach_click(b)
	if tooltip != "":
		Tooltips.register(b, tooltip)
	return b

## 为任意控件注册悬浮提示（图例、信息块等非按钮控件也可用）。
func attach_tooltip(c: Control, text: String) -> void:
	Tooltips.register(c, text)

## 把任意纹理缩放为 px×px 的小图（用于按钮图标，避免原图 512 撑爆布局）。
func _scaled_icon(tex: Texture2D, px: int) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return tex
	if img.get_width() <= px and img.get_height() <= px:
		return tex
	img = img.duplicate()
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


## 图标 + 文字标签。直接加入 parent，返回内部 Label 引用方便后续更新文本。
func icon_label(parent: Control, text: String, icon: Texture2D, min_w := 200) -> Label:
	var hb := HBoxContainer.new()
	if icon != null:
		hb.add_child(tex_rect(icon, 22))
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", INK)
	l.add_theme_font_size_override("font_size", 14)
	l.custom_minimum_size = Vector2(min_w, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	parent.add_child(hb)
	return l

## 卡片式面板容器（奶油白 + 深棕描边 + 柔和投影），调用方往里放内容即可。
func card(bg: Color = CREAM, border: Color = INK, radius := 14, pad := 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _cartoon_style(bg, border, radius, pad))
	return p

## 主操作按钮（彩色填充 + 白字 + 描边），用于“开始游戏”等强调动作。
func primary_button(text: String, color: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 17)
	var lighter := color.lightened(0.12)
	b.add_theme_stylebox_override("normal", _cartoon_style(color, INK, 12, 12))
	b.add_theme_stylebox_override("hover", _cartoon_style(lighter, INK, 12, 12))
	b.add_theme_stylebox_override("pressed", _cartoon_style(color.darkened(0.15), INK, 12, 12))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	AudioManager.attach_click(b)
	return b

func button(text: String, cb: Callable) -> Button:
	return icon_button(text, null, cb)

## 状态 / 信息小标签（圆角彩色 chip）。
func status_chip(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _cartoon_style(color, INK, 8, 6))
	var l := Label.new()
	l.name = "lbl"
	l.text = text
	l.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0) if _is_dark(color) else INK)
	l.add_theme_font_size_override("font_size", 13)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

## 顶栏状态块：图标 + 彩色圆角 chip（内部 label 名为 "lbl"，便于刷新）。
func stat_tile(icon: Texture2D, color: Color) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)
	hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if icon != null:
		var tr := tex_rect(icon, 20)
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(tr)
	var chip := status_chip("", color)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(chip)
	return hb

## 通用列表卡片行：左侧图标 + 标题/副标题两行 + 右侧操作按钮（可有多个）。
## actions: Array of {text:String, cb:Callable, color:Color}。返回可直接加入容器的卡片。
func info_row(icon: Texture2D, title: String, subtitle: String, actions: Array = []) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _cartoon_style(CREAM, INK, 10, 8))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	card.add_child(hb)
	if icon != null:
		var ic := tex_rect(icon, 30)
		ic.custom_minimum_size = Vector2(30, 30)
		hb.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	var t := Label.new()
	t.text = title
	t.add_theme_color_override("font_color", INK)
	t.add_theme_font_size_override("font_size", 14)
	col.add_child(t)
	if subtitle != "":
		var s := Label.new()
		s.text = subtitle
		s.add_theme_color_override("font_color", Color(0.42, 0.36, 0.30))
		s.add_theme_font_size_override("font_size", 12)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(s)
	hb.add_child(col)
	for a in actions:
		var ab := Button.new()
		ab.text = a.get("text", "")
		var col_btn: Color = a.get("color", ORANGE)
		ab.add_theme_stylebox_override("normal", _cartoon_style(col_btn, INK, 8, 6))
		ab.add_theme_stylebox_override("hover", _cartoon_style(col_btn.lightened(0.1), INK, 8, 6))
		ab.add_theme_stylebox_override("pressed", _cartoon_style(col_btn.darkened(0.15), INK, 8, 6))
		ab.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		ab.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0) if _is_dark(col_btn) else INK)
		ab.add_theme_font_size_override("font_size", 13)
		ab.custom_minimum_size = Vector2(64, 0)
		ab.pressed.connect(a.get("cb"))
		AudioManager.attach_click(ab)
		hb.add_child(ab)
	return card

func _is_dark(c: Color) -> bool:
	return (c.r * 0.299 + c.g * 0.587 + c.b * 0.114) < 0.55

func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

## 在指定父容器下添加小节标题（卡通橙、加粗放大）。
func header(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", ORANGE)
	l.add_theme_font_size_override("outline_size", 0)
	parent.add_child(l)
	# 标题下分隔线
	var sep := HBoxContainer.new()
	var line := PanelContainer.new()
	line.custom_minimum_size = Vector2(0, 3)
	line.add_theme_stylebox_override("panel", _cartoon_style(ORANGE, INK, 2, 0))
	sep.add_child(line)
	sep.add_child(spacer())
	parent.add_child(sep)

## 在指定父容器下追加一行多行文本（用于财务/市场等只读信息）。
func ml(parent: Control, text: String) -> void:
	parent.add_child(label(text, 400))

## 当前区域内城市的下拉选择框（item 元数据存 city id）。
func city_option() -> OptionButton:
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_theme_color_override("font_color", INK)
	if RegionManager.current != null:
		for c in RegionManager.current.cities:
			opt.add_item("%s (T%d)" % [c.display_name(), c.tier])
			opt.set_item_metadata(opt.item_count - 1, c.id)
	return opt

## 模式选择卡片：上方小图 + 标题 + 描述，整体可点击，高亮选中态。
func mode_card(icon: Texture2D, title: String, desc: String, cb: Callable) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(160, 92)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	b.add_theme_stylebox_override("normal", _cartoon_style(CREAM, INK, 14, 10))
	b.add_theme_stylebox_override("hover", _cartoon_style(Color(0.99, 0.95, 0.84), INK, 14, 10))
	b.add_theme_stylebox_override("pressed", _cartoon_style(YELLOW.lightened(0.15), INK, 14, 10))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# 选中态（toggle 按下）用黄色强调
	var sel := _cartoon_style(YELLOW, INK, 14, 10)
	sel.shadow_color = Color(1.0, 0.7, 0.1, 0.5)
	sel.shadow_size = 8
	b.add_theme_stylebox_override("pressed", sel)

	b.pressed.connect(cb)
	AudioManager.attach_click(b)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	b.add_child(vbox)

	if icon != null:
		var tr := tex_rect(icon, 44)
		vbox.add_child(tr)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", INK)
	vbox.add_child(t)

	var d := Label.new()
	d.text = desc
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_color_override("font_color", INK)
	vbox.add_child(d)

	return b

func veh_status_name(s: int) -> String:
	return Localization.t("veh.status." + Vehicle.Status.keys()[s])

func order_status_name(s: int) -> String:
	return Localization.t("order.status." + Order.Status.keys()[s])

func vehicle_type_name(i: int) -> String:
	var key := "vehicle.%s" % Vehicle.Type.keys()[i]
	var s := Localization.t(key)
	return s if s != key else ""
