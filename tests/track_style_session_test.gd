extends Node

## ATTN_17 §17.13, шаг U3c: стиль сессии у траков. Запуск: открыть tests/track_style_session_test.tscn, F6.
## Результат в Output: во всех строках должно быть OK, в конце ИТОГ: OK.
## Проверяет: набор стилей читается; трак со стилем «следовать сессии» (g107) строится в запрошенном стиле и
## пишет style_id в сейв; трак с зафиксированным стилем (s239_concrete) запрос игнорирует и style_id не пишет;
## неизвестный id заменяется стилем по умолчанию; SavedGame хранит track_style.

var _bad := 0


func check(label: String, cond: bool, detail: String = "") -> void:
	if not cond:
		_bad += 1
	print("  %s %s %s" % ["OK " if cond else "ОШИБКА", label, detail])


func _ready() -> void:
	var factory := EntityFactory.new()
	var follow := load("res://data/tracks/objects/g107.tres") as EntitySetting
	var fixed := load("res://data/tracks/objects/s239_concrete.tres") as EntitySetting

	print("== 1. набор стилей")
	print("  стили: ", TSM.style_set.ids(), ", по умолчанию: ", TSM.default_id, ", активный: ", TSM.current_id)
	check("набор без замечаний", TSM.style_set.validate().is_empty(), str(TSM.style_set.validate()))
	check("есть активный стиль", TSM.current_style() != null)

	print("== 2. трак «следовать сессии» (g107) в каждом стиле набора")
	for id in TSM.style_set.ids():
		var e := factory.create_from_setting(follow, id)
		add_child(e)
		var vis := e.get_comp(C_StyleVisual) as C_StyleVisual
		var d := e.save_entity()
		check("стиль %s" % id, e.style_id == id and vis.style.id == id and d.get("style_id") == id,
			"style_id=%s, визуал=%s, в сейве=%s" % [e.style_id, vis.style.id, d.get("style_id")])
		e.queue_free()

	print("== 3. запрос не задан: берётся активный стиль")
	var e0 := factory.create_from_setting(follow)
	add_child(e0)
	check("активный стиль", e0.style_id == TSM.current_id, "style_id=%s, активный=%s" % [e0.style_id, TSM.current_id])
	e0.queue_free()

	print("== 4. неизвестный id заменяется стилем по умолчанию")
	var e1 := factory.create_from_setting(follow, &"нет_такого_стиля")
	add_child(e1)
	check("запасной стиль", e1.style_id == TSM.default_id, "style_id=%s" % e1.style_id)
	e1.queue_free()

	print("== 5. зафиксированный стиль (s239_concrete) запрос игнорирует")
	var e2 := factory.create_from_setting(fixed, &"wood")
	add_child(e2)
	var v2 := e2.get_comp(C_StyleVisual) as C_StyleVisual
	var d2 := e2.save_entity()
	check("стиль в объекте", v2.style != null and v2.style.id == &"concrete", "визуал=%s" % v2.style.id)
	check("style_id пуст, в сейве ключа нет", e2.style_id == &"" and not d2.has("style_id"))
	e2.queue_free()

	print("== 6. SavedGame хранит стиль макета")
	var sg := SavedGame.new()
	sg.track_style = &"concrete"
	var path := "user://track_style_session_test.tres"
	ResourceSaver.save(sg, path)
	var back := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SavedGame
	check("track_style прочитан", back != null and back.track_style == &"concrete")
	DirAccess.remove_absolute(path)

	print("ИТОГ: ", "OK" if _bad == 0 else "ОШИБОК %d" % _bad)
