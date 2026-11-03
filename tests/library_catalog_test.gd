extends Node

# XX claude-library (новый файл)
## Проверка шага L2 (ATTN_22): открыта ли модель (ModelAccess), слоты ракурсов (ViewSlots), фильтр каталога
## (LibraryCatalog.matches) и сама панель каталога (поиск, категория, признак, выбор, замки).
## Запуск: открыть tests/library_catalog_test.tscn и нажать F6.
## Итог в Output: строки PASS/FAIL и «Library catalog: n/m».
## SKIP не входит в итог: проверка не выполнялась (например, у категории нет фильтров).
## Замки опираются на тестовые условия открытия в паспортах loco_02el1 (xp) и loco_02el2 (chapter): если их убрать, этот блок надо поправить.

var _ok := 0
var _all := 0
var _emits := 0


func _ready() -> void:
	_test_access()
	_test_slots()
	_test_matches()
	await _test_catalog()
	print("Library catalog: %d/%d" % [_ok, _all])
	get_tree().quit(0 if _ok == _all else 1)


# --- ModelAccess ---

func _test_access() -> void:
	var sandbox := LibraryRules.make(LibraryRules.Source.SANDBOX, LibraryRules.Preset.STANDARD)
	var campaign := LibraryRules.make(LibraryRules.Source.CAMPAIGN, LibraryRules.Preset.STANDARD)
	var profile := LibraryProfile.new()
	var xp := ModelInfo.new()
	xp.unlock = {"kind": "xp", "xp": 100}
	var free := ModelInfo.new()
	var key := &"train.test.one"
	_check("песочница: платная модель открыта", ModelAccess.is_open(sandbox, profile, key, xp))
	_check("кампания: свободная модель открыта", ModelAccess.is_open(campaign, profile, key, free))
	_check("кампания: модель без паспорта открыта", ModelAccess.is_open(campaign, profile, key, null))
	_check("кампания: модель за опыт закрыта", not ModelAccess.is_open(campaign, profile, key, xp))
	profile.add_owned(key)
	_check("кампания: открытая игроком модель открыта", ModelAccess.is_open(campaign, profile, key, xp))
	var dbg := LibraryRules.make(LibraryRules.Source.CAMPAIGN, LibraryRules.Preset.STANDARD)
	dbg.overrides[LibraryRules.K_DEBUG_ALL] = true
	_check("debug.all открывает всё", ModelAccess.is_open(dbg, LibraryProfile.new(), key, xp))
	_check("правила null и профиль null не роняют: модель за опыт закрыта", not ModelAccess.is_open(null, null, key, xp))
	var chapter := ModelInfo.new()
	chapter.unlock = {"kind": "chapter", "id": "ch7"}
	var kit := ModelInfo.new()
	kit.unlock = {"kind": "kit"}
	_check("условие xp", ModelAccess.condition_text(xp) == "Откроется за 100 опыта.")
	_check("условие chapter", ModelAccess.condition_text(chapter) == "Откроется в главе «ch7».")
	_check("условие kit", ModelAccess.condition_text(kit) == "Откроется после сборки набора.")
	_check("условие у свободной и без паспорта пусто", ModelAccess.condition_text(free) == "" and ModelAccess.condition_text(null) == "")


# --- ViewSlots ---

func _test_slots() -> void:
	var d := ViewSlots.defaults()
	_check("слотов по умолчанию 6, все словари", d.size() == ViewSlots.COUNT and d.all(func(x): return x is Dictionary))
	_check("sanitize(null) даёт слоты по умолчанию", ViewSlots.sanitize(null) == d)
	_check("sanitize(не массив) даёт слоты по умолчанию", ViewSlots.sanitize("мусор") == d)
	_check("sanitize(слоты по умолчанию) ничего не меняет", ViewSlots.sanitize(d) == d)
	var custom := {"yaw": 10.0, "pitch": -5.0, "ortho": false, "fov": 30.0, "zoom": 1.5, "pivot": Vector3(0.1, 0.0, 0.0)}
	var raw: Array = [custom, 5, {"yaw": 1.0}]
	var out := ViewSlots.sanitize(raw)
	_check("верный слот сохраняется, неверные заменяются по умолчанию",
		out.size() == 6 and out[0] == custom and out[1] == d[1] and out[2] == d[2])
	var long_raw: Array = []
	for i in 9:
		long_raw.append(custom)
	_check("лишние слоты отбрасываются", ViewSlots.sanitize(long_raw).size() == ViewSlots.COUNT)
	var no_pivot := custom.duplicate()
	no_pivot.erase("pivot")
	_check("слот без pivot заменяется по умолчанию", ViewSlots.sanitize([no_pivot])[0] == d[0])


# --- фильтр ---

func _setting(key: StringName, name: String, cat: StringName, tag: StringName, facets := {}) -> EntitySetting:
	var s := EntitySetting.new()
	s.key = key
	s.name = name
	s.category = cat
	s.tag = tag
	s.facets = facets
	return s


func _test_matches() -> void:
	var track := _setting(&"track.straight.s239_wood", "S239 дерево", &"track", &"straight", {"sleeper": "wood", "ballast": "no"})
	var loco := _setting(&"train.loco.loco_x", "Тепловоз", &"train", &"loco")
	var all := LibraryCatalog.ALL
	_check("категория ALL подходит любому", LibraryCatalog.matches(track, "S239", "", all, {}) and LibraryCatalog.matches(loco, "Тепловоз", "", all, {}))
	_check("категория отсекает чужое", not LibraryCatalog.matches(loco, "Тепловоз", "", &"track", {}))
	_check("признак совпал", LibraryCatalog.matches(track, "S239", "", &"track", {&"sleeper": "wood"}))
	_check("признак не совпал", not LibraryCatalog.matches(track, "S239", "", &"track", {&"sleeper": "concrete"}))
	_check("два признака сразу", LibraryCatalog.matches(track, "S239", "", &"track", {&"sleeper": "wood", &"ballast": "no"})
		and not LibraryCatalog.matches(track, "S239", "", &"track", {&"sleeper": "wood", &"ballast": "yes"}))
	_check("признака у объекта нет: не подходит", not LibraryCatalog.matches(loco, "Тепловоз", "", all, {&"sleeper": "wood"}))
	_check("поиск по названию без учёта регистра", LibraryCatalog.matches(loco, "Тепловоз", "ТЕПЛО", all, {}))
	_check("поиск по имени объекта", LibraryCatalog.matches(loco, "Другое название", "тепловоз", all, {}))
	_check("поиск по key", LibraryCatalog.matches(loco, "Тепловоз", "loco_x", all, {}))
	_check("поиск с пробелами по краям", LibraryCatalog.matches(loco, "Тепловоз", "  тепло  ", all, {}))
	_check("поиск ничего не нашёл", not LibraryCatalog.matches(loco, "Тепловоз", "вагон", all, {}))


# --- панель каталога ---

func _test_catalog() -> void:
	var rules := LibraryRules.make(LibraryRules.Source.SANDBOX, LibraryRules.Preset.STANDARD)
	var profile := LibraryProfile.new()
	var total := 0
	var per_cat := {}
	for s in EntityCatalogProvider.load_all():
		if s.hide or not LibraryCatalog.COLLECTION_CATEGORIES.has(s.category):
			continue
		total += 1
		per_cat[s.category] = int(per_cat.get(s.category, 0)) + 1

	var cat := LibraryCatalog.new(rules, profile)
	add_child(cat)
	await get_tree().process_frame
	_check("каталог: показаны все объекты коллекции (%d)" % total, cat.total_count() == total and cat.visible_count() == total and total > 0)

	cat.set_category(&"building")
	_check("категория «building»: %d" % int(per_cat.get(&"building", 0)), cat.visible_count() == int(per_cat.get(&"building", 0)))

	var tracks := int(per_cat.get(&"track", 0))
	cat.set_category(&"track")
	var specs := CatalogMeta.filter_specs(&"track")
	if specs.is_empty():
		# После ATTN_17 §17.13 у траков фильтров нет: признаки панели проверяет только чистая функция matches
		_skip("у категории track нет фильтров (FACET_SPECS пуст): проверка признаков в панели пропущена")
		_check("категория без фильтров показывает все свои объекты (%d)" % tracks, cat.visible_count() == tracks)
	else:
		var spec: Dictionary = specs[0]
		var option := str(spec["options"][0]["id"])
		cat.set_facet(spec["id"], option)
		var keys := cat.visible_keys()
		var all_match := not keys.is_empty()
		for k in keys:
			if cat.setting_of(k).get_facet(spec["id"]) != option:
				all_match = false
		_check("признак «%s: %s» оставляет только подходящие объекты" % [spec["id"], option], all_match and keys.size() <= tracks)
		cat.set_facet(spec["id"], "")
		_check("признак «Все» возвращает все объекты категории", cat.visible_count() == tracks)

	cat.set_category(&"train")
	cat.set_query("wagon")
	var wagons_ok := cat.visible_count() >= 3
	for k in cat.visible_keys():
		if not (String(k).contains("wagon") or cat.info_of(k) != null and cat.info_of(k).title.to_lower().contains("wagon")):
			wagons_ok = false
	_check("поиск «wagon» среди поездов находит вагоны", wagons_ok)
	cat.set_query("zzzz-нет-такого")
	_check("поиск без результата даёт пустой список", cat.visible_count() == 0 and cat.first_visible_key() == &"")
	cat.set_query("")
	cat.set_category(LibraryCatalog.ALL)
	_check("после сброса фильтров снова все объекты", cat.visible_count() == total)

	cat.object_selected.connect(func(_s: EntitySetting) -> void: _emits += 1)
	var first := cat.first_visible_key()
	_check("select_key выбирает показанный объект и шлёт сигнал", cat.select_key(first) and _emits == 1)
	_check("select_key(emit=false) сигнал не шлёт", cat.select_key(first, false) and _emits == 1)
	_check("select_key несуществующего ключа даёт false", not cat.select_key(&"нет.такого.ключа"))

	# замки: тестовые условия в паспортах loco_02el1 (xp) и loco_02el2 (chapter)
	_check("песочница: ничего не закрыто", not cat.is_locked(&"train.loco.loco_02el1") and not cat.is_locked(&"train.loco.loco_01"))
	rules.source = LibraryRules.Source.CAMPAIGN
	cat.refresh_locks()
	_check("кампания: loco_02el1 (xp) и loco_02el2 (chapter) закрыты, loco_01 свободен",
		cat.is_locked(&"train.loco.loco_02el1") and cat.is_locked(&"train.loco.loco_02el2") and not cat.is_locked(&"train.loco.loco_01"))
	profile.add_owned(&"train.loco.loco_02el1")
	cat.refresh_locks()
	_check("открытая игроком модель перестала быть закрытой", not cat.is_locked(&"train.loco.loco_02el1") and cat.is_locked(&"train.loco.loco_02el2"))
	cat.queue_free()


# --- служебное ---

func _skip(title: String) -> void:
	print("SKIP  ", title)


func _check(title: String, cond: bool) -> void:
	_all += 1
	if cond:
		_ok += 1
		print("PASS  ", title)
	else:
		print("FAIL  ", title)
