class_name VariantIO extends RefCounted

# XX claude-library (новый файл)
########################
## VariantIO. Чтение и запись данных игрока Library (ATTN_22 §22.6.2, шаг L0)
########################
## Всё в JSON под user://library/: profile.json и variants/<id>.json. Папку можно подменить (тесты).
## Битый или пустой файл не роняет: предупреждение в Output и пустой результат.
## Идентификатор исполнения идёт в имя файла, поэтому проверяется (ModelVariant.is_valid_id).

const DEFAULT_DIR := "user://library"
const PROFILE_FILE := "profile.json"
const VARIANTS_DIR := "variants"


static func profile_path(dir: String = DEFAULT_DIR) -> String:
	return dir.path_join(PROFILE_FILE)


static func variant_path(id: String, dir: String = DEFAULT_DIR) -> String:
	return dir.path_join(VARIANTS_DIR).path_join(id + ".json")


# --- профиль ---

static func save_profile(p: LibraryProfile, dir: String = DEFAULT_DIR) -> Error:
	return _write_json(profile_path(dir), p.to_dict())


## Профиль из файла; нет файла или он битый: пустой профиль
static func load_profile(dir: String = DEFAULT_DIR) -> LibraryProfile:
	var d: Variant = _read_json(profile_path(dir))
	if d is Dictionary:
		return LibraryProfile.from_dict(d)
	return LibraryProfile.new()


# --- исполнения ---

static func save_variant(v: ModelVariant, dir: String = DEFAULT_DIR) -> Error:
	if not ModelVariant.is_valid_id(v.id):
		push_warning("VariantIO: недопустимый id исполнения '%s'" % v.id)
		return ERR_INVALID_PARAMETER
	return _write_json(variant_path(v.id, dir), v.to_dict())


## Исполнение или null (нет файла, битый файл, недопустимый id)
static func load_variant(id: String, dir: String = DEFAULT_DIR) -> ModelVariant:
	if not ModelVariant.is_valid_id(id):
		return null
	var d: Variant = _read_json(variant_path(id, dir))
	if d is Dictionary:
		return ModelVariant.from_dict(d)
	return null


## Все исполнения; base не пустой: только этой модели. Порядок по имени, затем по id
static func list_variants(dir: String = DEFAULT_DIR, base: String = "") -> Array[ModelVariant]:
	var out: Array[ModelVariant] = []
	var folder := dir.path_join(VARIANTS_DIR)
	if not DirAccess.dir_exists_absolute(folder):
		return out
	for f in DirAccess.get_files_at(folder):
		if not f.ends_with(".json"):
			continue
		var v := load_variant(f.get_basename(), dir)
		if v == null:
			continue
		if base != "" and v.base != base:
			continue
		out.append(v)
	out.sort_custom(func(a: ModelVariant, b: ModelVariant) -> bool:
		if a.name != b.name:
			return a.name < b.name
		return a.id < b.id)
	return out


static func delete_variant(id: String, dir: String = DEFAULT_DIR) -> Error:
	if not ModelVariant.is_valid_id(id):
		return ERR_INVALID_PARAMETER
	var path := variant_path(id, dir)
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	return DirAccess.remove_absolute(path)


# --- JSON ---

static func _write_json(path: String, data: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		var err := FileAccess.get_open_error()
		push_warning("VariantIO: не удалось записать %s (код %d)" % [path, err])
		return err
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return OK


## Содержимое файла или null: нет файла, пустой, не JSON или не словарь
static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("VariantIO: не удалось открыть %s (код %d)" % [path, FileAccess.get_open_error()])
		return null
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("VariantIO: %s: не JSON (строка %d: %s)" % [path, json.get_error_line(), json.get_error_message()])
		return null
	if not (json.data is Dictionary):
		push_warning("VariantIO: %s: ожидался словарь" % path)
		return null
	return json.data
