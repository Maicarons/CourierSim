extends Node

## 国际化管理器：加载 res://src/i18n/strings.json，提供 t(key) 取当前语言文案，
## set_locale 切换语言并广播 locale_changed，选择持久化到 user://settings.cfg。
## 专有名词（区域/城市/科技名）的翻译就近放在数据 JSON 的 *_en 字段，
## 由对应类的 display_*() 方法按当前语言返回。

signal locale_changed(locale: String)

const SUPPORTED := ["zh_CN", "en_US"]
const DEFAULT_LOCALE := "zh_CN"
const DATA_PATH := "res://src/i18n/strings.json"
const SETTINGS_PATH := "user://settings.cfg"

var current_locale := DEFAULT_LOCALE
var _data: Dictionary = {}
var _loaded := false

func _ready() -> void:
	_load()
	_apply_saved()

func _load() -> void:
	if _loaded:
		return
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("Localization: 无法打开 %s" % DATA_PATH)
		return
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Localization: %s 不是合法 JSON" % DATA_PATH)
		return
	_data = parsed
	_loaded = true

## 取当前语言下 key 的文案；缺失时回退默认语言，再缺失则返回 key 本身（便于排查）。
func t(key: String) -> String:
	_load()
	var table: Variant = _data.get(current_locale, null)
	if typeof(table) == TYPE_DICTIONARY:
		var v: Variant = table.get(key, null)
		if typeof(v) == TYPE_STRING and v != "":
			return v
	var def: Variant = _data.get(DEFAULT_LOCALE, null)
	if typeof(def) == TYPE_DICTIONARY:
		var v2: Variant = def.get(key, null)
		if typeof(v2) == TYPE_STRING and v2 != "":
			return v2
	return key

func set_locale(code: String) -> void:
	if not SUPPORTED.has(code):
		return
	current_locale = code
	TranslationServer.set_locale(code)
	_save(code)
	locale_changed.emit(code)

func get_locale() -> String:
	return current_locale

func is_en() -> bool:
	return current_locale == "en_US"

func _save(code: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("i18n", "locale", code)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Localization: 保存语言设置失败 (%d)" % err)

func _apply_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		var code: Variant = cfg.get_value("i18n", "locale", DEFAULT_LOCALE)
		if typeof(code) == TYPE_STRING and SUPPORTED.has(code):
			current_locale = code
	TranslationServer.set_locale(current_locale)
