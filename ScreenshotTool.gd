extends Control

## 遍历目标场景整棵控件树，揪出“最小高度异常”的节点（图标未限制导致被撑爆的典型 >120px）。
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var target := OS.get_environment("SHOT_TARGET")
	if target == "":
		target = "res://src/scenes/MainMenu.tscn"
	var packed := load(target)
	var inst = packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	print("=== TREE SCAN (min.y>120) ===")
	_scan(inst, 0)
	get_tree().quit()

func _scan(n: Node, depth: int) -> void:
	if n is Control:
		var c := n as Control
		var my := c.get_combined_minimum_size().y
		if my > 120.0:
			var txt := ""
			if c is Label:
				txt = " text='%s'" % c.text
			print("  %s[%s] min.y=%.1f name=%s%s" % ["  ".repeat(depth), c.get_class(), my, c.name, txt])
	# 避免无限递归到 MapView 的绘制节点（无子控件），正常遍历
	for i in n.get_child_count():
		_scan(n.get_child(i), depth + 1)
