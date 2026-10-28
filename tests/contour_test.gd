extends Node

# XX claude-terra 13.2 B1 (новый файл)
## Тест контура листа: C_Contour.validate / cleaned / bounds / area / is_rect, обход и вырезы вогнутого листа.
## Чистая математика, сцена не нужна. Запуск: открыть tests/contour_test.tscn и нажать F6.
## Результат в Output: строки PASS / FAIL и итог.

var _fails := 0


func check(name: String, ok: bool, info := "") -> void:
	if ok:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name, "  ", info)


func near(a: float, b: float, eps := 0.01) -> bool:
	return absf(a - b) <= eps


func poly(arr: Array) -> PackedVector2Array:
	var res := PackedVector2Array()
	for v: Vector2 in arr:
		res.append(v)
	return res


## Правильный n-угольник радиуса r (выпуклый, годен для проверки числа вершин)
func ngon(n: int, r: float) -> PackedVector2Array:
	var res := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		res.append(Vector2(cos(a), sin(a)) * r)
	return res


func _ready() -> void:
	var square := poly([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	var tri := poly([Vector2(0, 0), Vector2(10, 0), Vector2(0, 10)])
	var ell := poly([Vector2(0, 0), Vector2(10, 0), Vector2(10, 5), Vector2(5, 5), Vector2(5, 10), Vector2(0, 10)])
	var ush := poly([Vector2(0, 0), Vector2(12, 0), Vector2(12, 8), Vector2(8, 8), Vector2(8, 3),
			Vector2(4, 3), Vector2(4, 8), Vector2(0, 8)])
	var bowtie := poly([Vector2(0, 0), Vector2(10, 10), Vector2(10, 0), Vector2(0, 10)])

	# --- validate: годные ---
	check("validate: квадрат", C_Contour.validate(square) == "", C_Contour.validate(square))
	check("validate: треугольник", C_Contour.validate(tri) == "", C_Contour.validate(tri))
	check("validate: буква Г", C_Contour.validate(ell) == "", C_Contour.validate(ell))
	check("validate: буква П", C_Contour.validate(ush) == "", C_Contour.validate(ush))
	var cw := square.duplicate()
	cw.reverse()
	check("validate: обход по часовой тоже годен", C_Contour.validate(cw) == "", C_Contour.validate(cw))
	check("validate: 64 вершины", C_Contour.validate(ngon(64, 100.0)) == "", C_Contour.validate(ngon(64, 100.0)))

	# --- validate: отказы ---
	check("validate: 2 вершины", C_Contour.validate(poly([Vector2(0, 0), Vector2(5, 0)])) != "")
	check("validate: 65 вершин", C_Contour.validate(ngon(65, 100.0)).begins_with("Больше"),
			C_Contour.validate(ngon(65, 100.0)))
	check("validate: бабочка (самопересечение)", C_Contour.validate(bowtie) == "Самопересечение",
			C_Contour.validate(bowtie))
	var tiny := poly([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)])   # площадь 0,5
	check("validate: площадь меньше 1", C_Contour.validate(tiny).begins_with("Площадь"), C_Contour.validate(tiny))
	var short := poly([Vector2(0, 0), Vector2(10, 0), Vector2(10, 0.5), Vector2(10, 10), Vector2(0, 10)])
	check("validate: короткое ребро", C_Contour.validate(short).begins_with("Ребро короче"), C_Contour.validate(short))
	var back := poly([Vector2(0, 0), Vector2(10, 0), Vector2(4, 0), Vector2(4, 6)])
	check("validate: ребро идёт назад", C_Contour.validate(back) == "Ребро идёт назад", C_Contour.validate(back))
	# вершина лежит на чужом ребре (касание)
	var touch := poly([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(5, 0), Vector2(0, 10)])
	check("validate: касание вершиной ребра", C_Contour.validate(touch) != "", "прошёл")

	# --- validate_chain (13.2 B2): незамкнутая цепочка при рисовании ---
	var c_open := poly([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	check("chain: одна вершина", C_Contour.validate_chain(poly([Vector2(0, 0)])) == "")
	check("chain: две вершины", C_Contour.validate_chain(poly([Vector2(0, 0), Vector2(10, 0)])) == "")
	check("chain: открытая С-образная", C_Contour.validate_chain(c_open) == "", C_Contour.validate_chain(c_open))
	check("chain: короткое ребро", C_Contour.validate_chain(poly([Vector2(0, 0), Vector2(0.5, 0)])).begins_with("Ребро короче"))
	check("chain: возврат назад", C_Contour.validate_chain(poly([Vector2(0, 0), Vector2(10, 0), Vector2(4, 0)])) == "Ребро идёт назад")
	var cross_chain := poly([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(5, -5)])
	check("chain: самопересечение", C_Contour.validate_chain(cross_chain) == "Самопересечение", C_Contour.validate_chain(cross_chain))
	check("chain: замкнутый тот же контур годен", C_Contour.validate(c_open) == "")
	# последнее и первое рёбра цепочки не соседние: касание вершиной первого ребра отклоняется
	var touch_chain := poly([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(5, 0)])
	check("chain: касание первого ребра", C_Contour.validate_chain(touch_chain) == "Самопересечение", C_Contour.validate_chain(touch_chain))

	# --- cleaned ---
	var dup := poly([Vector2(0, 0), Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	check("cleaned: повторная вершина убрана", C_Contour.cleaned(dup).size() == 4, str(C_Contour.cleaned(dup).size()))
	var col := poly([Vector2(0, 0), Vector2(5, 0), Vector2(10, 0), Vector2(10, 5), Vector2(10, 10), Vector2(0, 10)])
	check("cleaned: вершины на прямой убраны", C_Contour.cleaned(col).size() == 4, str(C_Contour.cleaned(col).size()))
	check("cleaned: Г не меняется", C_Contour.cleaned(ell).size() == 6, str(C_Contour.cleaned(ell).size()))
	check("cleaned: порядок сохранён", C_Contour.cleaned(col)[0] == Vector2(0, 0) and C_Contour.cleaned(col)[1] == Vector2(10, 0),
			str(C_Contour.cleaned(col)))

	# --- геометрия ---
	var c := C_Contour.new()
	c.points = ell
	check("area: Г = 75", near(c.area(), 75.0), str(c.area()))
	check("size: Г = 10 x 10", c.size().is_equal_approx(Vector2(10, 10)), str(c.size()))
	check("is_rect: Г нет", not c.is_rect())
	c.set_rect(Vector2(40, 20))
	check("is_rect: прямоугольник 40x20", c.is_rect())
	check("area: 40x20 = 800", near(c.area(), 800.0), str(c.area()))
	check("size: 40x20", c.size().is_equal_approx(Vector2(40, 20)), str(c.size()))
	check("is_rect: ромб нет", not C_Contour.is_rect_points(poly([Vector2(0, 5), Vector2(5, 0), Vector2(10, 5), Vector2(5, 10)])))
	c.points = cw
	check("normalized_points: против часовой", C_Contour.signed_area(c.normalized_points()) > 0.0)
	c.free()

	# --- вогнутый лист с вырезом (C_TerrainLayer._slab_polygons) ---
	var layer := C_TerrainLayer.new()
	var cut := FoamCut.new()
	cut.polygon = poly([Vector2(1, 1), Vector2(3, 1), Vector2(3, 3), Vector2(1, 3)])   # 2x2 в нижней ножке Г
	var cuts: Array[FoamCut] = [cut]
	var pieces: Array[PackedVector2Array] = layer._slab_polygons(C_Contour.cleaned(ell), cuts)
	var total := 0.0
	var all_tri := true
	for pc in pieces:
		total += absf(C_Contour.signed_area(pc))
		if Geometry2D.triangulate_polygon(pc).is_empty():
			all_tri = false
	check("Г с вырезом 2x2: площадь 71", near(total, 71.0, 0.05), str(total))
	check("Г с вырезом: все куски триангулируются", all_tri)
	# set_levels (13.2 B2): предел 1..MAX_LEVELS, без ноды меша только меняет число
	layer.set_levels(99)
	check("set_levels: не больше MAX_LEVELS", layer.levels == C_TerrainLayer.MAX_LEVELS, str(layer.levels))
	layer.set_levels(-3)
	check("set_levels: не меньше 1", layer.levels == 1, str(layer.levels))
	var no_cut: Array[FoamCut] = []
	pieces = layer._slab_polygons(C_Contour.cleaned(ell), no_cut)
	check("Г без выреза: один полигон", pieces.size() == 1, str(pieces.size()))
	layer.free()

	print("--------")
	print("contour_test: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
