extends Node
class_name FinanceSystem

## 财务系统：每日计收车辆维护、仓库运营等固定成本；
## 资金为负时自动计息（模拟贷款）。

func process_day(game: GameManager) -> void:
	var upkeep := 0.0
	for v in game.vehicles:
		upkeep += v.maintenance_per_day
	for h in game.hubs:
		upkeep += h.level * 300.0
	if upkeep > 0.0:
		game.add_money(-int(upkeep), "upkeep", "维护与仓库运营")
	if game.money < 0:
		var interest := int(-game.money * GameManager.LOAN_RATE)
		if interest > 0:
			game.add_money(-interest, "interest", "贷款利息")
