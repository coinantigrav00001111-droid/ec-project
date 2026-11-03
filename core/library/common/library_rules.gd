class_name LibraryRules extends Resource

# XX claude-library (новый файл)
########################
## LibraryRules. Правила Library: что включено в режиме игры и на уровне сложности (ATTN_22 §22.4, шаг L0)
########################
## Интерфейс не знает про «песочницу» и «кампанию»: он спрашивает ключ (level, allows).
## Пресеты соответствуют точности электрики (ATTN_10 §10.5.11): SIMPLE ~ P0, STANDARD ~ P1, REALISTIC ~ P2.
## Кампания берёт значения пресета, каталог в ней закрыт; главы переопределяют ключи через overrides.
## Позже станет секцией общих правил игры (DCSRules, ControlMode); пока самостоятельный ресурс.
## Ключи это строки: из JSON они приходят строками, StringName в ключах словаря не используем.

enum Source { SANDBOX, CAMPAIGN }
enum Preset { SIMPLE, STANDARD, REALISTIC }

const K_CATALOG_OPEN := "catalog.open"      ## bool: все модели открыты
const K_PAINT := "paint.level"              ## 0 нет, 1 цвет зон, 2 + отделка, 3 + декали, износ, кисть, скотч, стирка
const K_PARTS_SWAP := "parts.swap"          ## bool: замена деталей
const K_FIT := "fit.level"                  ## 0 готовое, 1 включить и выключить, 2 установка и проводка
const K_TEST := "test.level"                ## 0 кнопка «Проверить», 1 стенд с показаниями, 2 ручная подстройка
const K_KIT := "kit.mode"                   ## 0 пропуск, 1 упрощённая, 2 полная сборка
const K_GEN := "gen.level"                  ## 0 готовые здания, 1 модули, 2 + правила прототипа
const K_RESTORE := "restore.enabled"        ## bool: реставрация
const K_INFO := "info.show"                 ## bool: справка о прототипе
const K_DEBUG_ALL := "debug.all"            ## bool: открыть всё (только debug)

const SOURCE_NAMES := ["Песочница", "Кампания"]
const PRESET_NAMES := ["Простая", "Стандарт", "Реалистичная"]

## Значения пресетов (ATTN_22 §22.4). catalog.open зависит от источника, не от пресета
const PRESET_VALUES := {
	Preset.SIMPLE: {
		"paint.level": 1, "parts.swap": false, "fit.level": 0, "test.level": 0,
		"kit.mode": 0, "gen.level": 0, "restore.enabled": false, "info.show": true,
	},
	Preset.STANDARD: {
		"paint.level": 2, "parts.swap": true, "fit.level": 1, "test.level": 1,
		"kit.mode": 1, "gen.level": 1, "restore.enabled": true, "info.show": true,
	},
	Preset.REALISTIC: {
		"paint.level": 3, "parts.swap": true, "fit.level": 2, "test.level": 2,
		"kit.mode": 2, "gen.level": 2, "restore.enabled": true, "info.show": true,
	},
}

@export var source: Source = Source.SANDBOX
@export var preset: Preset = Preset.STANDARD
## Переопределения поверх пресета (главы кампании, отладка): ключ (String) -> значение
@export var overrides: Dictionary = {}


static func make(p_source: Source, p_preset: Preset) -> LibraryRules:
	var r := LibraryRules.new()
	r.source = p_source
	r.preset = p_preset
	return r


## Значение ключа с учётом переопределений. Неизвестный ключ даёт 0
func value(key: String) -> Variant:
	if overrides.has(key):
		return overrides[key]
	if key == K_CATALOG_OPEN:
		return source == Source.SANDBOX
	if key == K_DEBUG_ALL:
		return false
	var table: Dictionary = PRESET_VALUES[preset]
	return table.get(key, 0)


func level(key: String) -> int:
	var v: Variant = value(key)
	if v is bool:
		return 1 if v else 0
	return int(v)


func allows(key: String) -> bool:
	return level(key) > 0


## Каталог открыт целиком: правилом (песочница) или отладочным ключом
func catalog_open() -> bool:
	return allows(K_CATALOG_OPEN) or allows(K_DEBUG_ALL)


func label() -> String:
	return "%s · %s" % [SOURCE_NAMES[int(source)], PRESET_NAMES[int(preset)]]


## Отладка: следующая комбинация источник + пресет (6 штук по кругу)
func cycle_debug() -> void:
	var n := (int(source) * 3 + int(preset) + 1) % 6
	@warning_ignore("integer_division")
	var src := n / 3
	source = src as Source
	preset = (n % 3) as Preset


func to_dict() -> Dictionary:
	return {"source": int(source), "preset": int(preset), "overrides": overrides.duplicate(true)}


static func from_dict(d: Dictionary) -> LibraryRules:
	var r := LibraryRules.new()
	r.source = clampi(int(d.get("source", 0)), 0, 1) as Source
	r.preset = clampi(int(d.get("preset", 1)), 0, 2) as Preset
	var ov: Variant = d.get("overrides", {})
	if ov is Dictionary:
		for k in ov:
			r.overrides[str(k)] = ov[k]
	return r
