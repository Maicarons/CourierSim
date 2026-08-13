class_name TechNode
extends RefCounted

## 科技树节点：一次性投入，永久提升某项能力。

enum Category {
	VEHICLE,   # 车辆相关
	NETWORK,   # 网络/仓库
	MARKET,    # 市场/客户
	STAFF,     # 员工
}

var id: String = ""
var tech_name: String = ""
var tech_name_en: String = ""
var category: int = Category.VEHICLE
var cost: int = 0
var prerequisite: Array = []
var description: String = ""
var description_en: String = ""
var unlocked: bool = false
# 效果参数（由 TechSystem 解释）
var effect_code: String = ""
var effect_value: float = 0.0

func _init(p_id := "", p_name := "", p_cat := Category.VEHICLE, p_cost := 0, p_desc := "", p_pre: Array = [], p_code := "", p_val := 0.0, p_name_en := "", p_desc_en := ""):
	id = p_id
	tech_name = p_name
	tech_name_en = p_name_en
	category = p_cat
	cost = p_cost
	description = p_desc
	description_en = p_desc_en
	prerequisite = p_pre
	effect_code = p_code
	effect_value = p_val

func can_unlock(unlocked_ids: Array) -> bool:
	for pre in prerequisite:
		if not unlocked_ids.has(pre):
			return false
	return not unlocked

## 按当前语言返回科技名（英文模式取 tech_name_en，缺省回退中文）。
func display_name() -> String:
	if Localization.is_en() and tech_name_en != "":
		return tech_name_en
	return tech_name

## 按当前语言返回科技描述（英文模式取 description_en，缺省回退中文）。
func display_desc() -> String:
	if Localization.is_en() and description_en != "":
		return description_en
	return description
