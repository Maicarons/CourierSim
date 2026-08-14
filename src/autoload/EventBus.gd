extends Node
## 全局信号总线，解耦 UI 与各系统。

signal vehicles_changed
signal hubs_changed
signal stations_changed
signal orders_changed
signal money_changed(amount: int)
signal day_changed(day: int)
signal hour_changed(hour: int)
signal debt_changed(debt: int)
signal reputation_changed(value: float)
signal map_updated
signal toast(message: String)
signal game_over(reason: String)
signal region_changed
signal tab_requested(tab: String)
signal company_ready
signal achievement_unlocked(id: String)

## 统一派发提示
func notify(message: String) -> void:
	toast.emit(message)
	push_warning("[CourierSim] " + message)
