extends Node
class_name FinanceSystem

## 财务系统：每日计收车辆维护、仓库运营等固定成本；
## 资金为负时自动计息（模拟贷款）。

func process_day(game: GameManager) -> void:
	var upkeep := 0.0
	var lease_total := 0
	for v in game.vehicles:
		upkeep += v.maintenance_per_day
		if not v.owned and v.lease_daily > 0:
			lease_total += v.lease_daily
	for h in game.hubs:
		upkeep += h.level * 300.0
	if upkeep > 0.0:
		game.add_money(-int(upkeep), "upkeep", "维护与仓库运营")
	if lease_total > 0:
		game.add_money(-lease_total, "lease", "车辆租赁费")
	# 主动借贷的日息（参考 TransRoute：日息 0.2%）
	if game.debt > 0:
		var interest: int = maxi(1, int(game.debt * GameManager.LOAN_DAILY_RATE))
		game.add_money(-interest, "interest", "贷款利息")
		EventBus.debt_changed.emit(game.debt)
	# 兜底：现金为负时按旧费率计息（防无限负现金流）
	if game.money < 0:
		var interest := int(-game.money * GameManager.LOAN_RATE)
		if interest > 0:
			game.add_money(-interest, "interest", "透支利息")
