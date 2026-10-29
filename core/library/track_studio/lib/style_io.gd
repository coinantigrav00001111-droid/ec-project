class_name TrackStyleIO extends RefCounted

########################
## Файлы стилей траков (ATTN_20, шаг T1)
########################
## Список, загрузка, рабочая копия и запись `TrackStyle` в `.tres`. Только ресурсы и пути, без интерфейса.

const STYLES_DIR := "res://data/tracks/styles/"


## Пути всех `.tres` папки, которые являются TrackStyle, по алфавиту
static func list_paths(dir: String = STYLES_DIR) -> PackedStringArray:
	var out := PackedStringArray()
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for f in da.get_files():
		if not f.ends_with(".tres"):
			continue
		var path := dir.path_join(f)
		if ResourceLoader.load(path) is TrackStyle:
			out.append(path)
	out.sort()
	return out


## Читает файл заново (без кэша), чтобы увидеть то, что на диске
static func load_style(path: String) -> TrackStyle:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as TrackStyle


## Рабочая копия: поверхностная, материалы и меш остаются теми же ресурсами (ссылки на файлы не превращаются во встроенные копии)
static func working_copy(style: TrackStyle) -> TrackStyle:
	return style.duplicate() as TrackStyle


static func path_for_id(id: String, dir: String = STYLES_DIR) -> String:
	return dir.path_join(id + ".tres")


## Идентификатор стиля = имя файла: латиница в нижнем регистре, цифры, подчёркивание, начинается с буквы
static func is_valid_id(id: String) -> bool:
	var re := RegEx.new()
	re.compile("^[a-z][a-z0-9_]*$")
	return re.search(id) != null


## base, base_2, base_3... пока имя занято (existing: id или пути)
static func unique_id(base: String, dir: String = STYLES_DIR) -> String:
	var id := base
	var n := 2
	while FileAccess.file_exists(path_for_id(id, dir)):
		id = "%s_%d" % [base, n]
		n += 1
	return id


## Записывает стиль. Возвращает код Error (OK = 0)
static func save(style: TrackStyle, path: String) -> int:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	return ResourceSaver.save(style, path)


## Короткое описание ресурса для интерфейса: путь, «встроен» или прочерк
static func describe(res: Resource) -> String:
	if res == null:
		return "—"
	var p := res.resource_path
	if p.is_empty():
		return "(встроенный) %s" % res.get_class()
	if p.contains("::"):
		return "(внутри %s) %s" % [p.get_slice("::", 0).get_file(), res.get_class()]
	return p


## Строки "x y" -> профиль. Возвращает {ok, points, error}. Разделители: пробел, табуляция, точка с запятой
static func parse_profile(text: String) -> Dictionary:
	var pts := PackedVector2Array()
	var lineno := 0
	for raw in text.split("\n"):
		lineno += 1
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var tokens: Array = []
		for t in line.replace(";", " ").replace("\t", " ").split(" ", false):
			var s := String(t).strip_edges().trim_suffix(",").replace(",", ".")
			if not s.is_empty():
				tokens.append(s)
		if tokens.size() != 2 or not String(tokens[0]).is_valid_float() or not String(tokens[1]).is_valid_float():
			return {"ok": false, "points": PackedVector2Array(), "error": "строка %d: нужно два числа «x y»" % lineno}
		pts.append(Vector2(float(tokens[0]), float(tokens[1])))
	return {"ok": true, "points": pts, "error": ""}


static func profile_to_text(p: PackedVector2Array) -> String:
	var lines := PackedStringArray()
	for v in p:
		lines.append("%s  %s" % [_num(v.x), _num(v.y)])
	return "\n".join(lines)


static func _num(v: float) -> String:
	return ("%.4f" % v).rstrip("0").rstrip(".") if not is_zero_approx(v) else "0"
