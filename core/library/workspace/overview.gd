extends "res://core/library/workspace/workspace.gd"

# XX claude-library (новый файл)
########################
## Осмотр: сведения об объекте (ATTN_22 §22.7.1). Шаг L1: только состояние показа; паспорт и справка в L2
########################

var _head: Label
var _info: Label


func _init() -> void:
	id = &"overview"
	title = "Осмотр"


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_head = Label.new()
	_head.text = "Осмотр"
	add_child(_head)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.text = "Выберите объект в каталоге слева."
	add_child(_info)


func on_loading(setting: EntitySetting) -> void:
	_info.text = "Загрузка: %s ..." % setting.name


func on_subject(setting: EntitySetting, info: Dictionary, ms: int) -> void:
	var lines: Array[String] = []
	var passport := ModelInfo.find(setting.get_key())
	var heading := setting.name
	if passport != null and passport.title != "":
		heading = passport.title
	lines.append("%s (id %d)" % [heading, setting.id])
	lines.append("key: %s" % setting.get_key())
	lines.append("%s / %s" % [setting.category, setting.tag])
	if passport != null and passport.prototype_line() != "":
		lines.append("Прототип: %s" % passport.prototype_line())
	lines.append("Источник: %s, %d мс" % [info.get("via", ""), ms])
	if info.get("ok", false):
		var a: AABB = info.aabb
		lines.append("Мешей: %d" % info.meshes)
		lines.append("Размер (ю): %.2f × %.2f × %.2f" % [a.size.x, a.size.y, a.size.z])
	if info.get("warn", "") != "":
		lines.append("Внимание: " + str(info.warn))
	if info.get("error", "") != "":
		lines.append("Ошибка: " + str(info.error))
	_info.text = "\n".join(lines)
