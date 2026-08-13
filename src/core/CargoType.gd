class_name CargoType
extends RefCounted

## 货种定义。不同货种影响运费倍率、所需车辆类型与时效惩罚。
enum Type {
	STANDARD,      # 标准快递
	COLDCHAIN,     # 冷链
	PHARMA,        # 医药
	HAZMAT,        # 危险品
	INTERNATIONAL, # 国际
}

const NAMES := {
	Type.STANDARD: "标准快递",
	Type.COLDCHAIN: "冷链",
	Type.PHARMA: "医药",
	Type.HAZMAT: "危险品",
	Type.INTERNATIONAL: "国际",
}

## 运费倍率（影响订单收益）
const REWARD_MULT := {
	Type.STANDARD: 1.0,
	Type.COLDCHAIN: 1.8,
	Type.PHARMA: 1.6,
	Type.HAZMAT: 2.4,
	Type.INTERNATIONAL: 2.2,
}

## 该货种要求车辆具备的能力（见 Vehicle.Capability）
const REQUIRED_CAP := {
	Type.STANDARD: 0,
	Type.COLDCHAIN: 1, # 需要冷藏
	Type.PHARMA: 2,    # 需要恒温医药
	Type.HAZMAT: 4,    # 需要危险品资质
	Type.INTERNATIONAL: 8, # 需要跨境资质
}

## 延误每日的信誉惩罚倍率
const PENALTY_MULT := {
	Type.STANDARD: 1.0,
	Type.COLDCHAIN: 1.5,
	Type.PHARMA: 1.5,
	Type.HAZMAT: 2.0,
	Type.INTERNATIONAL: 1.8,
}

static func name_of(t: int) -> String:
	var key := "cargo.%s" % Type.keys()[t]
	var s := Localization.t(key)
	if s == key:
		return NAMES.get(t, "未知")
	return s

static func reward_mult(t: int) -> float:
	return REWARD_MULT.get(t, 1.0)

static func required_cap(t: int) -> int:
	return REQUIRED_CAP.get(t, 0)

static func penalty_mult(t: int) -> float:
	return PENALTY_MULT.get(t, 1.0)

## 货种对应的像素图标资源 id（assets/images/cargo_*.png）
static func icon_of(t: int) -> String:
	match t:
		Type.COLDCHAIN: return "cargo_coldchain"
		Type.PHARMA: return "cargo_pharma"
		Type.HAZMAT: return "cargo_hazmat"
		Type.INTERNATIONAL: return "cargo_international"
		_: return "cargo_standard"
