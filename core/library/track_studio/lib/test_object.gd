class_name TrackTestObject extends RefCounted

########################
## Тестовый объект каталога для стиля (ATTN_20, шаг T5)
########################
## Клон прямой S239 (`s239_wood_ballast.tres`) со ссылкой на стиль, новым id и ключом. Нужен, чтобы проверить стиль
## в игре до менеджера стилей (ATTN_15, этап 2). Без интерфейса: чистые функции над текстом `.tres` и файлами.

const TEMPLATE := "res://data/tracks/objects/s239_wood_ballast.tres"
const OBJECTS_DIR := "res://data/tracks/objects/"
const TEMPLATE_STYLE := "res://data/tracks/styles/wood_ballast.tres"
const ID_FROM := 1900                 # диапазон 1900-1999 под тестовые объекты студии (треки 1xxx)
const OBJECT_DIRS := ["res://data/tracks/objects/", "res://data/trains/objects/", "res://data/buildings/objects/", "res://data/terrain/objects/"]
const LAST_FILE := "user://track_studio_last_object.txt"   # читает tests/track_style_bench


static func object_path(style_id: String) -> String:
	return OBJECTS_DIR + "s239_" + style_id + ".tres"


## Занятые id объектов во всех каталогах данных
static func used_ids() -> Dictionary:
	var out := {}
	var re := RegEx.new()
	re.compile("(?m)^id = (\\d+)[ \\t\\r]*$")
	for dir in OBJECT_DIRS:
		var da := DirAccess.open(dir)
		if da == null:
			continue
		for f in da.get_files():
			if not f.ends_with(".tres"):
				continue
			var m := re.search(FileAccess.get_file_as_string(dir + f))
			if m:
				out[int(m.get_string(1))] = true
	return out


static func next_id(used: Dictionary = {}) -> int:
	var u := used if not used.is_empty() else used_ids()
	var id := ID_FROM
	while u.has(id):
		id += 1
	return id


## Текст объекта из текста шаблона. Чистая функция (проверяется в tests/track_lib_test)
static func build_text(template: String, style_path: String, style_id: String, ballast: bool, head: float, id: int) -> String:
	var t := template.replace(TEMPLATE_STYLE, style_path)
	t = _sub(t, "(?m)^id = \\d+[ \\t\\r]*$", "id = %d" % id)
	t = _sub(t, "(?m)^key = &\"[^\"]*\"[ \\t\\r]*$", "key = &\"track.straight.s239_%s\"" % style_id)
	t = _sub(t, "(?m)^facets = \\{[^}]*\\}[ \\t\\r]*$", "facets = { \"ballast\": \"%s\", \"shape\": \"straight\" }" % ("yes" if ballast else "no"))
	t = _sub(t, "(?m)^name = \"[^\"]*\"[ \\t\\r]*$", "name = \"S239 %s\"" % style_id)
	t = _sub(t, "(?m)^description = \"[^\"]*\"[ \\t\\r]*$", "description = \"Прямой 23.9см, стиль «%s» (h=%.2f), тестовый объект Track Studio\"" % [style_id, head])
	return t


static func _sub(text: String, pattern: String, repl: String) -> String:
	var re := RegEx.new()
	re.compile(pattern)
	var m := re.search(text)
	if m == null:
		return text
	return text.substr(0, m.get_start()) + repl + text.substr(m.get_end())


## Создаёт или обновляет объект стиля. style_path: сохранённый .tres стиля. Возвращает {ok, path, id, error}
static func create(style: TrackStyle, style_path: String) -> Dictionary:
	if style == null or style_path.is_empty() or not FileAccess.file_exists(style_path):
		return {"ok": false, "error": "Сначала сохраните стиль в файл"}
	if not FileAccess.file_exists(TEMPLATE):
		return {"ok": false, "error": "Нет шаблона %s" % TEMPLATE}
	var sid := String(style.id)
	var path := object_path(sid)
	var id := 0
	if FileAccess.file_exists(path):
		# обновляем существующий: id сохраняем, чтобы не ломать сохранения
		var m := RegEx.new()
		m.compile("(?m)^id = (\\d+)[ \\t\\r]*$")
		var found := m.search(FileAccess.get_file_as_string(path))
		if found:
			id = int(found.get_string(1))
	if id == 0:
		id = next_id()
	var text := build_text(FileAccess.get_file_as_string(TEMPLATE), style_path, sid, style.ballast_enabled, style.head_height(), id)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "Не удалось записать %s (код %d)" % [path, FileAccess.get_open_error()]}
	f.store_string(text)
	f.close()
	var last := FileAccess.open(LAST_FILE, FileAccess.WRITE)
	if last:
		last.store_string("%s\n%s" % [path.get_file(), sid])
		last.close()
	return {"ok": true, "path": path, "id": id, "error": ""}
