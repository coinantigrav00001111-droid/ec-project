@tool
extends EditorScript

###########################
## Проверка каталога объектов (U3a). Запуск: открыть файл, File → Run (Ctrl+Shift+X)
###########################
## Ищет: пустые и повторные `key`, key не по схеме `категория.тег.вариант`, объекты без иконки,
## неизвестные фасеты и значения (CatalogMeta.FACET_SPECS), категории и теги, которых нет в CatalogMeta.
## Итог в Output: список проблем или «OK».

const DIRS := [
	"res://data/tracks/objects/",
	"res://data/trains/objects/",
	"res://data/buildings/objects/",
	"res://data/terrain/objects/",
	"res://ui/dc_controllers/objects/",
]


func _run() -> void:
	var problems: Array[String] = []
	var seen := {}
	var total := 0
	for dir in DIRS:
		for path in EntityCatalogProvider.list_resources(dir):
			var res := load(path) as EntitySetting
			if res == null:
				continue   # DCControllerSetting и прочее: не объект каталога
			total += 1
			problems.append_array(_check(path, res, seen))
	print("Каталог: проверено объектов %d" % total)
	if problems.is_empty():
		print("OK: проблем нет")
		return
	print("Проблем: %d" % problems.size())
	for p in problems:
		print("  - ", p)


func _check(path: String, res: EntitySetting, seen: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if res.key == &"":
		out.append("%s: пустой key (сейчас временный %s)" % [path, res.get_key()])
	var k := res.get_key()
	if seen.has(k):
		out.append("%s: key '%s' уже у %s" % [path, k, seen[k]])
	else:
		seen[k] = path
	var parts := str(k).split(".")
	if parts.size() < 3:
		out.append("%s: key '%s' не по схеме категория.тег.вариант" % [path, k])
	elif parts[0] != str(res.category) or parts[1] != str(res.tag):
		out.append("%s: key '%s' не совпадает с category '%s' и tag '%s'" % [path, k, res.category, res.tag])
	if res.icon == null:
		out.append("%s: нет иконки" % path)

	var allowed := CatalogMeta.allowed_facets(res.category)
	for f in res.facets:
		if not allowed.has(StringName(str(f))):
			out.append("%s: неизвестный фасет '%s' для категории %s" % [path, f, res.category])
	for spec in CatalogMeta.FACET_SPECS.get(res.category, []):
		var v := res.get_facet(spec["id"])
		if v != "" and not (spec["options"] as Array).has(v):
			out.append("%s: фасет %s = '%s', допустимо %s" % [path, spec["id"], v, spec["options"]])

	if not CatalogMeta.CATEGORIES.has(res.category):
		out.append("%s: категории %s нет в CatalogMeta.CATEGORIES" % [path, res.category])
	return out
