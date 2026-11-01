extends Node

# XX claude-terra 13.4 W1 (новый файл)
## Тест ядра воды: WaterFill (область заливки, домен, край стола, полосы, стенки). Листов и TGM не нужно:
## занятость ячейки подаётся функцией. Запуск: tests/water_test.tscn, F6, строки PASS / FAIL в Output.

var _fails := 0


func check(name: String, ok: bool, info := "") -> void:
	if ok:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name, "  ", info)


## Стол 20 x 10 ячеек: x 0..20, z 0..10. Кольцо берега x 5..10, z 2..6 (20 ячеек) с водоёмом внутри 6..9 x 3..5 (6 ячеек)
func ring_blocker(p: Vector2) -> bool:
	var outer := Rect2(5, 2, 5, 4)
	var inner := Rect2(6, 3, 3, 2)
	return outer.has_point(p) and not inner.has_point(p)


func _ready() -> void:
	var dom := Rect2(0, 0, 20, 10)
	var gd := WaterFill.grid_domain(dom, 1.0)
	check("grid_domain: 20 x 10 ячеек", gd == Rect2i(0, 0, 20, 10), str(gd))
	check("grid_domain: вершины не на сетке сжимают домен", WaterFill.grid_domain(Rect2(0.4, 0.4, 5.2, 3.2), 1.0) == Rect2i(1, 1, 4, 2))

	var pond := WaterFill.fill(Vector2(7.5, 3.5), 2.0, dom, 1.0, ring_blocker)
	check("fill: водоём внутри кольца 3 x 2 = 6 ячеек", pond["ok"] and pond["count"] == 6, str(pond["count"]))
	check("fill: водоём не касается края", pond["ok"] and not pond["touches_edge"])
	check("fill: bounds водоёма", pond["ok"] and pond["bounds"] == Rect2(6, 3, 3, 2), str(pond["bounds"]))

	var out := WaterFill.fill(Vector2(1.5, 1.5), 2.0, dom, 1.0, ring_blocker)
	check("fill: снаружи 200 - 20 = 180 ячеек (водоём внутри кольца не достижим)", out["ok"] and out["count"] == 180, str(out["count"]))
	check("fill: снаружи доходит до края", out["ok"] and out["touches_edge"])

	check("fill: клик на берегу отказ с причиной", not WaterFill.fill(Vector2(5.5, 2.5), 2.0, dom, 1.0, ring_blocker)["ok"]
			and WaterFill.fill(Vector2(5.5, 2.5), 2.0, dom, 1.0, ring_blocker)["why"] != "")
	check("fill: клик за краем стола отказ", not WaterFill.fill(Vector2(25, 5), 2.0, dom, 1.0, ring_blocker)["ok"])
	check("fill: уровень ниже слоя отказ", not WaterFill.fill(Vector2(7.5, 3.5), 0.0, dom, 1.0, ring_blocker)["ok"])

	var empty := func(_p: Vector2) -> bool: return false
	var all := WaterFill.fill(Vector2(10.5, 5.5), 1.0, dom, 1.0, empty)
	check("fill: пустой стол заливается весь (200)", all["ok"] and all["count"] == 200 and all["touches_edge"], str(all["count"]))
	check("fill: предохранитель MAX_CELLS", not WaterFill.fill(Vector2(10.5, 5.5), 1.0, dom, 1.0, empty, 50)["ok"])

	# домен меньше стола: «замёрзла на границе», что за ним, не заливается
	var small := WaterFill.fill(Vector2(10.5, 5.5), 1.0, Rect2(8, 4, 4, 3), 1.0, empty)
	check("fill: домен 4 x 3 даёт 12 ячеек", small["ok"] and small["count"] == 12, str(small["count"]))

	# шаг 2
	var half := WaterFill.fill(Vector2(10.5, 5.5), 1.0, dom, 2.0, empty)
	check("fill: шаг 2 даёт 10 x 5 = 50 ячеек", half["ok"] and half["count"] == 50, str(half["count"]))

	# полосы
	var rn := WaterFill.runs(pond["cells"])
	check("runs: водоём 3 x 2 это две полосы по 3", rn.size() == 2 and rn[0] == Vector3i(3, 6, 9) and rn[1] == Vector3i(4, 6, 9), str(rn))
	var rn2 := WaterFill.runs(out["cells"])
	var total := 0
	for r in rn2:
		total += r.z - r.y
	check("runs: сумма длин полос равна числу ячеек", total == out["count"], "%d / %d" % [total, out["count"]])
	check("runs: строка 2 с кольцом разбита на две полосы", rn2.filter(func(v: Vector3i): return v.x == 2).size() == 2)

	# стенки у края
	var w := WaterFill.edge_walls(all["cells"], all["dom"], 1.0)
	check("edge_walls: периметр стола 2 * (20 + 10) = 60 граней", w.size() == 60, str(w.size()))
	check("edge_walls: водоём внутри без стенок", WaterFill.edge_walls(pond["cells"], pond["dom"], 1.0).is_empty())

	# плавающие сущности: рейкаст видит воду (W4)
	var plain := EntitySetting.new()
	plain.category = &"building"
	var boat := EntitySetting.new()
	boat.category = &"building"
	boat.floats = true
	check("floats: обычный объект воду не видит", not plain.get_pick_layers().has(&"water"))
	check("floats: плавающий видит воду и землю", boat.get_pick_layers().has(&"water") and boat.get_pick_layers().has(&"ground"))
	var tboat := EntitySetting.new()
	tboat.category = &"terrain"
	tboat.floats = true
	check("floats: у категории с одним слоем ground добавляется water", tboat.get_pick_layers() == [&"ground", &"water"], str(tboat.get_pick_layers()))
	tboat.floats = false
	check("floats: выключили, слоёв категории water нет", not tboat.get_pick_layers().has(&"water"))
	check("water_level_at: без воды NO_WATER", TGM.water_level_at(0.0, 0.0) == TGM.NO_WATER)

	print("ИТОГО: ", "всё PASS" if _fails == 0 else "FAIL: %d" % _fails)
