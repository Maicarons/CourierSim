extends Node
## 时间系统：把真实时间累积为游戏内"小时"，并以倍率推进模拟。
## 1x 速度下 1 游戏小时 = SECONDS_PER_HOUR 真实秒；车辆 24 小时不间断运行。

const SECONDS_PER_HOUR := 6.0        # 1 游戏小时 = 6 真实秒（用户确认）
const SECONDS_PER_DAY := SECONDS_PER_HOUR * 24.0
const SPEEDS := [0, 1, 2, 4]         # 0=暂停

var speed_index: int = 1             # 默认 1x
var current_hour_fraction: float = 0.0
var total_hours: float = 0.0
var paused: bool = false

func _process(delta: float) -> void:
	if GameManager.company_name == "" or paused or SPEEDS[speed_index] == 0:
		return
	var mult := float(SPEEDS[speed_index])
	var amt := delta * mult / SECONDS_PER_HOUR
	current_hour_fraction += amt
	total_hours += amt
	GameManager.tick_frame(amt)       # 每帧平滑推进车辆移动（单位：游戏小时）
	while current_hour_fraction >= 1.0:
		current_hour_fraction -= 1.0
		GameManager.advance_hour()
		# 跨天
		if GameManager.hour_of_day >= 24:
			GameManager.hour_of_day = 0
			GameManager.advance_day()

## 当前游戏内时刻（小时 0-23）
func hour_of_day() -> int:
	return GameManager.hour_of_day

func set_speed(idx: int) -> void:
	speed_index = clampi(idx, 0, SPEEDS.size() - 1)
	paused = (SPEEDS[speed_index] == 0)
	EventBus.toast.emit((Localization.t("toast.speed") % SPEEDS[speed_index]) if not paused else Localization.t("toast.paused"))

func toggle_pause() -> void:
	if paused:
		paused = false
		speed_index = max(speed_index, 1)
	else:
		paused = true
	EventBus.toast.emit(Localization.t("toast.paused") if paused else Localization.t("toast.resume"))
