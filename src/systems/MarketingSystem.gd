extends Node
class_name MarketingSystem

## 市场宣传系统：维护区域知名度(awareness)，影响订单生单率。
## 知名度随每日小幅自然衰减，投放宣传活动可快速提升。

var awareness: float = 0.05

func process_day(game: GameManager) -> void:
	# 自然衰减
	awareness = GeoMath.clampf(awareness * 0.97, 0.0, 1.0)
	var mult: float = game.base_modifiers.get("demand_mult", 1.0) * (1.0 + awareness * 0.8)
	game.modifiers["demand_mult"] = mult

## 投放一次宣传活动
func run_campaign(game: GameManager, budget: int) -> void:
	if budget < 1000:
		EventBus.toast.emit(Localization.t("toast.marketing_min"))
		return
	if not game.spend(budget, "marketing", "区域宣传活动"):
		return
	awareness = GeoMath.clampf(awareness + float(budget) / 120000.0, 0.0, 1.0)
	EventBus.toast.emit(Localization.t("toast.marketing_done") % (awareness * 100.0))
