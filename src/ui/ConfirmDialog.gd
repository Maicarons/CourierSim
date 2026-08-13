extends Control
class_name ConfirmDialog

## 通用模态确认弹窗：半透明遮罩拦截点击 + 居中卡片（标题/消息/取消/确认）。
## 用于返回主菜单、退出游戏、删除存档等误触风险操作。
## 用法：
##   confirm = ConfirmDialog.new(); add_child(confirm)
##   confirm.ask("返回主菜单？", "未保存的进度将丢失", func(): get_tree().change_scene_to_file(...))

var _title_label: Label
var _msg_label: Label
var _confirm_btn: Button
var _cancel_btn: Button
var _on_confirm: Callable = Callable()
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.04, 0.03, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(420, 0)
	card.add_theme_stylebox_override("panel", UI._cartoon_style(UI.CREAM, UI.INK, 16, 22))
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	card.add_child(vb)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", UI.ORANGE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title_label)

	_msg_label = Label.new()
	_msg_label.add_theme_color_override("font_color", UI.INK)
	_msg_label.add_theme_font_size_override("font_size", 14)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg_label.custom_minimum_size = Vector2(0, 40)
	vb.add_child(_msg_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)

	_cancel_btn = UI.icon_button(Localization.t("dlg.cancel"),
		Assets.get_image("ui_back"), _close, Localization.t("dlg.cancel"))
	_cancel_btn.custom_minimum_size = Vector2(130, 40)
	row.add_child(_cancel_btn)

	_confirm_btn = UI.primary_button(Localization.t("dlg.confirm"), UI.RED, _on_confirm_pressed)
	_confirm_btn.custom_minimum_size = Vector2(130, 40)
	row.add_child(_confirm_btn)


## 弹出确认框。on_confirm 在点击「确认」后回调一次。
func ask(title: String, message: String, on_confirm: Callable = Callable()) -> void:
	_title_label.text = title
	_msg_label.text = message
	_on_confirm = on_confirm
	visible = true
	modulate.a = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)


func _close() -> void:
	visible = false
	_on_confirm = Callable()


func _on_confirm_pressed() -> void:
	var cb := _on_confirm
	visible = false
	_on_confirm = Callable()
	if cb.is_valid():
		cb.call()


func is_open() -> bool:
	return visible
