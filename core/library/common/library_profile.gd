class_name LibraryProfile extends RefCounted

# XX claude-library (новый файл)
########################
## LibraryProfile. Профиль игрока в Library: коллекция, опыт, исполнения, наборы в работе (ATTN_22 §22.6.2, шаг L0)
########################
## Один файл user://library/profile.json (JSON, см. VariantIO). Макет профиль не хранит: макет несёт исполнения у себя.

const VERSION := 1
const KNOWN := ["v", "owned", "xp", "variants", "kits", "rules"]

## key моделей, которые игрок открыл (в песочнице каталог открыт правилом, а не профилем)
var owned: Array = []
var xp := 0
## id исполнений игрока
var variants: Array = []
## наборы «из литников» в работе: key -> {step, parts}
var kits: Dictionary = {}
## правила по умолчанию для Library без макета (LibraryRules.to_dict()), пусто = песочница, Стандарт
var rules: Dictionary = {}

var _extra: Dictionary = {}
var _version := VERSION


func is_owned(model_key: StringName) -> bool:
	return owned.has(String(model_key))


## true, если ключ добавлен впервые
func add_owned(model_key: StringName) -> bool:
	var k := String(model_key)
	if owned.has(k):
		return false
	owned.append(k)
	return true


func to_dict() -> Dictionary:
	var d := _extra.duplicate(true)
	d["v"] = maxi(_version, VERSION)
	d["owned"] = owned.duplicate()
	d["xp"] = xp
	d["variants"] = variants.duplicate()
	d["kits"] = kits.duplicate(true)
	d["rules"] = rules.duplicate(true)
	return d


static func from_dict(d: Dictionary) -> LibraryProfile:
	var p := LibraryProfile.new()
	p._version = int(d.get("v", VERSION))
	var o: Variant = d.get("owned")
	if o is Array:
		for k in o:
			p.owned.append(str(k))
	p.xp = int(d.get("xp", 0))
	var vs: Variant = d.get("variants")
	if vs is Array:
		for k in vs:
			p.variants.append(str(k))
	var ks: Variant = d.get("kits")
	if ks is Dictionary:
		p.kits = (ks as Dictionary).duplicate(true)
	var rs: Variant = d.get("rules")
	if rs is Dictionary:
		p.rules = (rs as Dictionary).duplicate(true)
	for k in d:
		if not KNOWN.has(str(k)):
			p._extra[k] = d[k]
	return p
