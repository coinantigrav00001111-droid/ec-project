extends Node

# XX claude-terra 13.1.8 (новый файл)
## Тест FlexSolver: дуга, пределы, цепочка Эрмита, радиусы, высота. Чистая математика, сцена не нужна.
## Запуск: открыть tests/flex_solver_test.tscn и нажать F6. Результат в Output: строки PASS / FAIL и итог.

var _fails := 0
var _lim := FlexSolver.Limits.new()      # r_min 25, l_min 10, l_max 90, grade 0.045


func check(name: String, ok: bool, info := "") -> void:
	if ok:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name, "  ", info)


func near(a: float, b: float, eps := 0.05) -> bool:
	return absf(a - b) <= eps


func _ready() -> void:
	# --- arc_to ---
	var d := FlexSolver.arc_to(Vector2(0.0, 30.0), _lim)
	var pts: PackedVector2Array = d.points
	check("arc: прямая вперед, радиус INF", is_inf(d.radius), str(d.radius))
	check("arc: прямая вперед, длина 30", near(d.length, 30.0), str(d.length))
	check("arc: начало в нуле", pts[0].length() < 0.001, str(pts[0]))
	check("arc: конец на цели", pts[pts.size() - 1].distance_to(Vector2(0.0, 30.0)) < 0.05, str(pts[pts.size() - 1]))

	d = FlexSolver.arc_to(Vector2(20.0, 20.0), _lim)      # круче r_min: должна упереться в предел
	check("arc: упирается в r_min", near(d.radius, _lim.r_min, 0.1), str(d.radius))
	var mid: float = d.radii[d.radii.size() / 2]
	check("arc: радиус в середине = r_min", near(mid, _lim.r_min, 0.5), str(mid))

	d = FlexSolver.arc_to(Vector2(10.0, 200.0), _lim)
	check("arc: длина не больше l_max", d.length <= _lim.l_max + 0.01, str(d.length))
	d = FlexSolver.arc_to(Vector2(0.0, 2.0), _lim)
	check("arc: длина не меньше l_min", d.length >= _lim.l_min - 0.01, str(d.length))

	var dl := FlexSolver.arc_to(Vector2(-20.0, 40.0), _lim)
	var dr := FlexSolver.arc_to(Vector2(20.0, 40.0), _lim)
	var pl: PackedVector2Array = dl.points
	var pr: PackedVector2Array = dr.points
	check("arc: зеркальность влево и вправо", near(pl[pl.size() - 1].x, -pr[pr.size() - 1].x, 0.01))

	# --- radii ---
	var circle := PackedVector2Array()
	for i in 20:
		var a := i * 0.03
		circle.append(Vector2(30.0 * (1.0 - cos(a)), 30.0 * sin(a)))
	var r := FlexSolver.radii(circle)
	check("radii: окружность R = 30", near(r[10], 30.0, 0.05), str(r[10]))
	var line := PackedVector2Array([Vector2(0, 0), Vector2(0, 1), Vector2(0, 2)])
	check("radii: прямая INF", is_inf(FlexSolver.radii(line)[1]))

	# --- hermite_chain / best_chain ---
	var up := Vector2(0.0, 1.0)
	var straight: Array[Vector2] = [Vector2(0, 0), Vector2(0, 20), Vector2(0, 40)]
	var hc := FlexSolver.hermite_chain(straight, up, up, 0.5)
	var max_x := 0.0
	for p in hc:
		max_x = maxf(max_x, absf(p.x))
	check("hermite: прямая остается прямой", max_x < 0.001, str(max_x))
	check("hermite: концы на опорных точках",
			hc[0].is_equal_approx(straight[0]) and hc[hc.size() - 1].is_equal_approx(straight[2]))

	var gentle: Array[Vector2] = [Vector2(0, 0), Vector2(2, 30), Vector2(0, 60)]
	var ch := FlexSolver.best_chain(gentle, up, up, _lim)
	check("best_chain: пологая S валидна", ch.valid, "min R %.1f, L %.1f" % [ch.min_radius, ch.length])
	var tight: Array[Vector2] = [Vector2(0, 0), Vector2(15, 10), Vector2(0, 20)]
	ch = FlexSolver.best_chain(tight, up, up, _lim)
	check("best_chain: слишком крутая невалидна", not ch.valid, "min R %.1f" % ch.min_radius)
	check("best_chain: длина = path_length", near(ch.length, FlexSolver.path_length(ch.points), 0.001))

	# --- высота ---
	check("y_at: начало", near(FlexSolver.y_at(0.0, 40.0, 1.0, 3.0, 0.0, 0.0), 1.0, 0.001))
	check("y_at: конец", near(FlexSolver.y_at(40.0, 40.0, 1.0, 3.0, 0.0, 0.0), 3.0, 0.001))
	check("grade_at: на концах 0 при m=0", near(FlexSolver.grade_at(0.0, 40.0, 1.0, 3.0, 0.0, 0.0), 0.0, 0.001))

	print("--- итог: %s ---" % ("ВСЕ ПРОШЛИ" if _fails == 0 else "ПРОВАЛОВ: %d" % _fails))
