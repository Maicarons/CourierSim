extends Node
## 时间系统：把真实时间累积为游戏内"天"，并以倍率推进模拟。
## 1x 速度下 1 游戏日 = SECONDS_PER_DAY 真实秒。

const SECONDS_PER_DAY := 2.5
const SPEEDS := [0, 1, 2, 4]   # 0=暂停

var speed_index: int = 1       # 默认 1x
var current_day_fraction: float = 0.0
var total_days: float = 0.0
var paused: bool = false

func _process(delta: float) -> void:
	if GameManager.company_name == "" or paused or SPEEDS[speed_index] == 0:
		return
	var mult := float(SPEEDS[speed_index])
	var amt := delta * mult / SECONDS_PER_DAY
	current_day_fraction += amt
	total_days += amt
	GameManager.tick_frame(amt)   # 每帧平滑推进车辆移动
	while current_day_fraction >= 1.0:
		current_day_fraction -= 1.0
		GameManager.advance_day()

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
