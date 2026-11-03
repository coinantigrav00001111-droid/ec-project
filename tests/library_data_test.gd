extends Node

# XX claude-library (новый файл)
## Проверка шага L0 (ATTN_22): правила и пресеты, паспорта, исполнение и профиль (JSON), запись и чтение.
## Запуск: открыть tests/library_data_test.tscn и нажать F6.
## Итог в Output: строки PASS/FAIL и «Library data: n/m». Временные файлы в user://library_data_test (после теста удаляются).
## Две строки «VariantIO: ... не JSON» и «недопустимый id» в Output ожидаемы: так проверяется битый файл и защита имени.

const TMP := "user://library_data_test"
const PASSPORT_KEYS := [&"train.loco.loco_01", &"train.boxcar.wagon_02", &"building.house.house_01"]

var _ok := 0
var _all := 0


func _ready() -> void:
	_rm_tree(TMP)
	_test_rules()
	_test_passports()
	_test_variant()
	_test_profile_and_io()
	_test_broken_and_ids()
	_rm_tree(TMP)
	print("Library data: %d/%d" % [_ok, _all])
	get_tree().quit(0 if _ok == _all else 1)


# --- правила ---

func _test_rules() -> void:
	var s := LibraryRules.make(LibraryRules.Source.SANDBOX, LibraryRules.Preset.SIMPLE)
	_check("Простая: покраска 1, детали нет, свет 0, тест 0, сборка 0, генератор 0, реставрации нет",
		s.level(LibraryRules.K_PAINT) == 1 and not s.allows(LibraryRules.K_PARTS_SWAP) and s.level(LibraryRules.K_FIT) == 0
		and s.level(LibraryRules.K_TEST) == 0 and s.level(LibraryRules.K_KIT) == 0 and s.level(LibraryRules.K_GEN) == 0
		and not s.allows(LibraryRules.K_RESTORE))
	var st := LibraryRules.make(LibraryRules.Source.SANDBOX, LibraryRules.Preset.STANDARD)
	_check("Стандарт: 2, детали да, свет 1, тест 1, сборка 1, генератор 1, реставрация да",
		st.level(LibraryRules.K_PAINT) == 2 and st.allows(LibraryRules.K_PARTS_SWAP) and st.level(LibraryRules.K_FIT) == 1
		and st.level(LibraryRules.K_TEST) == 1 and st.level(LibraryRules.K_KIT) == 1 and st.level(LibraryRules.K_GEN) == 1
		and st.allows(LibraryRules.K_RESTORE))
	var r := LibraryRules.make(LibraryRules.Source.SANDBOX, LibraryRules.Preset.REALISTIC)
	_check("Реалистичная: 3, детали да, свет 2, тест 2, сборка 2, генератор 2",
		r.level(LibraryRules.K_PAINT) == 3 and r.level(LibraryRules.K_FIT) == 2 and r.level(LibraryRules.K_TEST) == 2
		and r.level(LibraryRules.K_KIT) == 2 and r.level(LibraryRules.K_GEN) == 2)
	_check("песочница: каталог открыт, кампания: закрыт",
		s.catalog_open() and not LibraryRules.make(LibraryRules.Source.CAMPAIGN, LibraryRules.Preset.STANDARD).catalog_open())
	var c := LibraryRules.make(LibraryRules.Source.CAMPAIGN, LibraryRules.Preset.SIMPLE)
	c.overrides[LibraryRules.K_PAINT] = 3
	_check("переопределение главы перекрывает пресет", c.level(LibraryRules.K_PAINT) == 3 and c.level(LibraryRules.K_FIT) == 0)
	c.overrides[LibraryRules.K_DEBUG_ALL] = true
	_check("debug.all открывает каталог кампании", c.catalog_open())
	_check("неизвестный ключ даёт 0 и не разрешён", s.level("нет.такого") == 0 and not s.allows("нет.такого"))
	# круг через словарь и JSON: числа в JSON становятся float, enum восстанавливается
	var back := LibraryRules.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	_check("правила: круг to_dict, JSON, from_dict",
		back.source == c.source and back.preset == c.preset and back.level(LibraryRules.K_PAINT) == 3 and back.catalog_open())
	var bad := LibraryRules.from_dict({"source": 99, "preset": -5})
	_check("from_dict зажимает enum в допустимые значения",
		int(bad.source) == 1 and int(bad.preset) == 0)
	var cyc := LibraryRules.make(LibraryRules.Source.SANDBOX, LibraryRules.Preset.SIMPLE)
	var seen := {}
	for i in 6:
		seen[cyc.label()] = true
		cyc.cycle_debug()
	_check("cycle_debug: 6 разных комбинаций и возврат к началу", seen.size() == 6 and cyc.label() == "Песочница · Простая")


# --- паспорта ---

func _test_passports() -> void:
	var catalog := {}
	for s in EntityCatalogProvider.load_all():
		catalog[s.get_key()] = s
	for k in PASSPORT_KEYS:
		var info := ModelInfo.find(k)
		_check("паспорт %s читается" % k, info != null and info.key == k)
		_check("для паспорта %s есть объект каталога" % k, catalog.has(k))
		if info != null:
			_check("паспорт %s: без данных автора условие «free», строка прототипа пуста" % k,
				info.unlock_kind() == "free" and info.xp_cost() == 0 and info.prototype_line() == "")
	_check("паспорта нет у неизвестного ключа", ModelInfo.find(&"train.none.none") == null)
	for path in EntityCatalogProvider.list_resources(ModelInfo.DIR):
		var info2 := load(path) as ModelInfo
		_check("%s: key совпадает с именем файла и есть в каталоге" % path.get_file(),
			info2 != null and path.get_file().get_basename() == String(info2.key) and catalog.has(info2.key))


# --- исполнение ---

func _test_variant() -> void:
	var v := ModelVariant.new()
	v.id = ModelVariant.make_id()
	v.base = "train.boxcar.wagon_02"
	v.name = "Красный товарный"
	v.paint = {"body": {"color": "#c0392b", "finish": "matte", "wear": 0.25}}
	v.parts = {"door": "alt_1"}
	v.fit = {"cab_light": {"on": false}}
	v.tuning = {"mass": 2.5}
	v.built = true
	_check("make_id даёт допустимый id", ModelVariant.is_valid_id(v.id))
	var d: Dictionary = JSON.parse_string(JSON.stringify(v.to_dict()))
	var back := ModelVariant.from_dict(d)
	_check("исполнение: круг to_dict, JSON, from_dict",
		back.id == v.id and back.base == v.base and back.name == v.name and back.built
		and back.paint["body"]["color"] == "#c0392b" and float(back.paint["body"]["wear"]) == 0.25
		and back.parts["door"] == "alt_1" and back.fit["cab_light"]["on"] == false and float(back.tuning["mass"]) == 2.5)
	# поля новой версии не теряются при перезаписи
	d["future_field"] = {"x": 1.0}
	d["v"] = 7
	var newer := ModelVariant.from_dict(d)
	var out := newer.to_dict()
	_check("неизвестные поля и версия новее сохраняются", out.has("future_field") and int(out["v"]) == 7)
	var dup := v.duplicate_variant()
	dup.paint["body"]["color"] = "#000000"
	_check("duplicate_variant не делит данные с оригиналом", v.paint["body"]["color"] == "#c0392b")
	var weird := ModelVariant.from_dict({"paint": 5, "decals": "x", "parts": [1]})
	_check("поля неверных типов дают пустые значения, без ошибок",
		weird.paint.is_empty() and weird.decals.is_empty() and weird.parts.is_empty() and weird.id == "")


# --- профиль и запись ---

func _test_profile_and_io() -> void:
	var p := LibraryProfile.new()
	p.xp = 120
	_check("add_owned: первый раз true, повтор false", p.add_owned(&"train.loco.loco_01") and not p.add_owned(&"train.loco.loco_01"))
	_check("is_owned", p.is_owned(&"train.loco.loco_01") and not p.is_owned(&"train.boxcar.wagon_02"))
	p.variants.append("abc1")
	p.kits = {"building.house.house_01": {"step": 3.0}}
	p.rules = LibraryRules.make(LibraryRules.Source.CAMPAIGN, LibraryRules.Preset.REALISTIC).to_dict()
	_check("профиль записан", VariantIO.save_profile(p, TMP) == OK)
	var q := VariantIO.load_profile(TMP)
	_check("профиль: круг через файл JSON",
		q.xp == 120 and q.is_owned(&"train.loco.loco_01") and q.variants == ["abc1"]
		and float(q.kits["building.house.house_01"]["step"]) == 3.0
		and LibraryRules.from_dict(q.rules).label() == "Кампания · Реалистичная")
	_check("нет файла: пустой профиль", VariantIO.load_profile(TMP + "/no_such_dir").owned.is_empty())

	var a := ModelVariant.new()
	a.id = "va1"
	a.base = "train.loco.loco_01"
	a.name = "Б"
	var b := ModelVariant.new()
	b.id = "vb2"
	b.base = "train.boxcar.wagon_02"
	b.name = "А"
	_check("исполнения записаны", VariantIO.save_variant(a, TMP) == OK and VariantIO.save_variant(b, TMP) == OK)
	_check("load_variant читает записанное", VariantIO.load_variant("va1", TMP).name == "Б")
	var all := VariantIO.list_variants(TMP)
	_check("list_variants: оба, порядок по имени", all.size() == 2 and all[0].id == "vb2" and all[1].id == "va1")
	var only := VariantIO.list_variants(TMP, "train.loco.loco_01")
	_check("list_variants по модели", only.size() == 1 and only[0].id == "va1")
	_check("delete_variant удаляет, повтор даёт ERR_FILE_NOT_FOUND",
		VariantIO.delete_variant("va1", TMP) == OK and VariantIO.delete_variant("va1", TMP) == ERR_FILE_NOT_FOUND
		and VariantIO.load_variant("va1", TMP) == null)
	_check("list_variants в несуществующей папке пуст", VariantIO.list_variants(TMP + "/no_such_dir").is_empty())


# --- битые файлы и защита имени ---

func _test_broken_and_ids() -> void:
	DirAccess.make_dir_recursive_absolute(TMP + "/" + VariantIO.VARIANTS_DIR)
	var f := FileAccess.open(VariantIO.variant_path("broken", TMP), FileAccess.WRITE)
	f.store_string("{ это не json")
	f.close()
	_check("битый файл исполнения: null, без падения", VariantIO.load_variant("broken", TMP) == null)
	var g := FileAccess.open(VariantIO.profile_path(TMP), FileAccess.WRITE)
	g.store_string("[1, 2, 3]")
	g.close()
	_check("в профиле не словарь: пустой профиль", VariantIO.load_profile(TMP).owned.is_empty())
	var h := FileAccess.open(VariantIO.profile_path(TMP), FileAccess.WRITE)
	h.store_string("")
	h.close()
	_check("пустой файл профиля: пустой профиль", VariantIO.load_profile(TMP).xp == 0)

	var evil := ModelVariant.new()
	evil.id = "../evil"
	_check("id с путём не записывается", VariantIO.save_variant(evil, TMP) == ERR_INVALID_PARAMETER)
	_check("id с путём не читается и не удаляется",
		VariantIO.load_variant("../evil", TMP) == null and VariantIO.delete_variant("../evil", TMP) == ERR_INVALID_PARAMETER)
	for bad in ["", "a b", "a/b", "a.b", "я", "x".repeat(65)]:
		_check("недопустимый id '%s'" % bad.left(12), not ModelVariant.is_valid_id(bad))
	for good in ["a", "A-1_b", "x".repeat(64)]:
		_check("допустимый id '%s'" % good.left(12), ModelVariant.is_valid_id(good))


# --- служебное ---

func _rm_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for d in DirAccess.get_directories_at(path):
		_rm_tree(path.path_join(d))
	DirAccess.remove_absolute(path)


func _check(title: String, cond: bool) -> void:
	_all += 1
	if cond:
		_ok += 1
		print("PASS  ", title)
	else:
		print("FAIL  ", title)
