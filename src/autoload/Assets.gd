extends Node
## 资源仓库：集中预加载所有生成的美术素材，避免运行时反复 load。

var _images: Dictionary = {}
var _has := {}

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	var ids := [
		# 车辆
		"veh_van", "veh_truck", "veh_refrigerated", "veh_drone", "veh_plane", "veh_ship",
		# 建筑
		"bld_hq", "bld_hub", "bld_station",
		# 角色
		"char_courier",
		# 货种
		"cargo_standard", "cargo_coldchain", "cargo_pharma", "cargo_hazmat", "cargo_international",
		# 界面
		"logo", "title_bg",
		# UI 图标（图标 + 文字界面元素）
		"ui_coin", "ui_star", "ui_calendar", "ui_play", "ui_pause", "ui_save",
		"ui_home", "ui_globe", "ui_marketing", "ui_tech", "ui_finance", "ui_order",
		# UI 图标（v2：设置/关于/帮助/目标等，图标驱动交互）
		"ui_settings", "ui_about", "ui_help", "ui_objective", "ui_back", "ui_quit",
		"ui_trash", "ui_sound", "ui_plus", "ui_lock", "ui_arrow_right", "ui_bell",
		"ui_chart", "ui_clock", "ui_flag",
		# 成就专属图标（v0.9，ComfyUI 批量生成）
		"ach_first_vehicle", "ach_fleet_five", "ach_first_delivery", "ach_deliver_50",
		"ach_network_hubs", "ach_network_stations", "ach_staff_team", "ach_tech_research",
		"ach_millionaire", "ach_share_30", "ach_day_30", "ach_world_traveler",
	]
	for id in ids:
		var path := "res://assets/images/%s.png" % id
		if ResourceLoader.exists(path):
			_images[id] = load(path) as Texture2D
			_has[id] = true

## 获取图片；若尚未生成返回 null，调用方需自行兜底。
func get_image(id: String) -> Texture2D:
	return _images.get(id) as Texture2D

func has_image(id: String) -> bool:
	return _has.get(id, false)
