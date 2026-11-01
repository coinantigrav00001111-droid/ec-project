extends Node

# XX claude-track-studio (новый файл)
## Проверка шага T4 (ATTN_20): генераторы профилей, зеркало, привязка, проверки геометрии и логика редактора
## (вставка и удаление точек с зеркалом, история). Запуск: открыть tests/track_profile_test.tscn и нажать F6.
## Итог в Output: строки PASS/FAIL и «TrackProfile: n/m».

const EPS := 0.0005
const ProfileEditor := preload("res://core/library/track_studio/profile_editor.gd")

var _ok := 0
var _all := 0


func _ready() -> void:
	_test_generators()
	_test_tools()
	_test_editor()
	print("TrackProfile: %d/%d" % [_ok, _all])
	get_tree().quit(0 if _ok == _all else 1)


func _test_generators() -> void:
	var v := TrackProfileTools.rail_vignole()
	var info := TrackProfileTools.inspect(v)
	_check("Виньоль: 14 точек, обход слева направо, без самопересечений, низ на 0",
		v.size() == 14 and not info["reversed"] and (info["crossings"] as Array).is_empty() and absf(info["miny"]) < EPS and info["below_zero"] == 0)
	_check("Виньоль: ширина подошвы 0.2, высота 0.25, симметричный", absf(info["width"] - 0.2) < EPS and absf(info["height"] - 0.25) < EPS and TrackProfileTools.is_symmetric(v))
	var st := TrackStyle.new()
	st.rail_profile = v
	_check("Виньоль в стиле: rail_width 0.2, поверхность катания 0.85 как у коробки", absf(st.rail_width() - 0.2) < EPS and absf(st.head_height() - 0.85) < EPS)
	var bad := 0
	for m in TrackStyleValidator.validate(st):
		if m["level"] >= TrackStyleValidator.Level.WARN:
			bad += 1
	_check("Виньоль: валидатор без замечаний", bad == 0)
	_check("Виньоль строится в меш", TrackMeshBuilder.build_mesh(st, _straight(), 10.0, false).get_surface_count() == 2)
	# крайние параметры не ломают профиль
	var thin := TrackProfileTools.rail_vignole({"height": 0.1, "foot_width": 0.05, "web_width": 0.3, "head_width": 0.9, "head_height": 0.5, "foot_height": 0.2})
	var ti := TrackProfileTools.inspect(thin)
	_check("Виньоль с крайними параметрами остаётся корректным", (ti["crossings"] as Array).is_empty() and not ti["reversed"] and ti["below_zero"] == 0)
	for n in TrackProfileTools.RAIL_PRESETS:
		var p := TrackProfileTools.preset("rail", n)
		_check("пресет рельса «%s» без проблем" % n, TrackProfileTools.problems_text(p).is_empty())
	for n in TrackProfileTools.BALLAST_PRESETS:
		var p := TrackProfileTools.preset("ballast", n)
		_check("пресет балласта «%s» без проблем, симметричен" % n, TrackProfileTools.problems_text(p).is_empty() and TrackProfileTools.is_symmetric(p))
	var def := TrackProfileTools.preset("ballast", "Трапеция")
	_check("пресет «Трапеция» равен профилю балласта по умолчанию", def == TrackStyle.new().ballast_profile)
	_check("пресет «Коробка» равен профилю рельса по умолчанию", TrackProfileTools.preset("rail", "Коробка") == TrackStyle.new().rail_profile)


func _test_tools() -> void:
	var asym := PackedVector2Array([Vector2(-0.3, 0.0), Vector2(-0.1, 0.25), Vector2(0.1, 0.2), Vector2(0.2, 0.0)])
	_check("is_symmetric: несимметричный профиль замечен", not TrackProfileTools.is_symmetric(asym))
	var sym := TrackProfileTools.symmetrize(asym)
	_check("symmetrize: результат симметричен, правая половина сохранена", TrackProfileTools.is_symmetric(sym) and sym[3] == asym[3] and sym[2] == asym[2])
	var odd := PackedVector2Array([Vector2(-1, 0), Vector2(0.2, 0.5), Vector2(1, 0)])
	_check("symmetrize: средняя точка нечётного профиля встаёт на x = 0", is_zero_approx(TrackProfileTools.symmetrize(odd)[1].x))
	_check("snap: привязка к шагу", TrackProfileTools.snap(Vector2(0.131, 0.262), 0.025).is_equal_approx(Vector2(0.125, 0.25)))
	var cross := PackedVector2Array([Vector2(-1, 0), Vector2(1, 1), Vector2(-1, 1), Vector2(1, 0)])
	_check("intersections: самопересечение найдено", TrackProfileTools.intersections(cross).size() == 1)
	_check("problems_text: обратный обход и точки ниже нуля", TrackProfileTools.problems_text(PackedVector2Array([Vector2(1, 0), Vector2(0, -0.5), Vector2(-1, 0)])).contains("справа налево")
		and TrackProfileTools.problems_text(PackedVector2Array([Vector2(-1, 0), Vector2(0, -0.5), Vector2(1, 0)])).contains("ниже"))
	var np := TrackProfileTools.nearest_on_polyline(TrackProfileTools.rail_box(), Vector2(0.0, 0.3))
	_check("nearest_on_polyline: ближайший сегмент верхний", np["index"] == 1 and absf(np["point"].y - 0.25) < EPS)


func _test_editor() -> void:
	var ed := ProfileEditor.new()
	var start := TrackProfileTools.rail_vignole()
	ed.load_profile(start, ProfileEditor.Target.RAIL, null)
	ed.snap_on = false
	ed.set_mirror(true)
	_check("редактор: зеркало на симметричном профиле ничего не меняет", ed.profile == start and not ed.can_undo())
	# вставка в сегмент между 2 и 3 точкой, парный сегмент получает зеркальную точку
	var mid := Vector2((start[1].x + start[2].x) * 0.5, (start[1].y + start[2].y) * 0.5)
	ed.call("_insert_on_segment", 1, ed.call("_w2s", mid))
	_check("редактор: вставка с зеркалом даёт 2 точки и симметрию", ed.profile.size() == 16 and TrackProfileTools.is_symmetric(ed.profile))
	ed.undo()
	_check("редактор: отмена возвращает исходный профиль", ed.profile == start)
	ed.redo()
	_check("редактор: повтор возвращает 16 точек", ed.profile.size() == 16)
	ed.call("_delete", 2)
	_check("редактор: удаление с зеркалом убирает пару, остаётся симметрия", ed.profile.size() == 14 and TrackProfileTools.is_symmetric(ed.profile))
	# числовая правка точки с зеркалом
	ed.selected = 4
	ed.set_selected_point(Vector2(-0.07, 0.2))
	_check("редактор: правка точки отражается на парную", is_equal_approx(ed.profile[ed.profile.size() - 1 - 4].x, 0.07) and TrackProfileTools.is_symmetric(ed.profile))
	# без зеркала правка одиночная
	ed.set_mirror(false)
	var n := ed.profile.size()
	ed.selected = 0
	ed.set_selected_point(Vector2(-0.12, 0.0))
	_check("редактор без зеркала: парная точка не меняется", ed.profile.size() == n and not TrackProfileTools.is_symmetric(ed.profile))
	# включение зеркала симметризует по правой половине
	ed.set_mirror(true)
	_check("редактор: включение зеркала симметризует профиль", TrackProfileTools.is_symmetric(ed.profile))
	# apply_profile одна запись истории
	var before := ed._undo.size()
	ed.apply_profile(TrackProfileTools.rail_box())
	_check("редактор: пресет это одна запись истории", ed._undo.size() == before + 1 and ed.profile.size() == 4)
	# минимальное число точек
	ed.set_mirror(false)
	ed.apply_profile(PackedVector2Array([Vector2(-1, 0), Vector2(1, 0)]))
	ed.call("_delete", 0)
	_check("редактор: меньше двух точек не оставляет", ed.profile.size() == 2)
	ed.free()


func _straight() -> Curve3D:
	var c := Curve3D.new()
	c.add_point(Vector3.ZERO)
	c.add_point(Vector3(0.0, 0.0, -10.0))
	return c


func _check(title: String, cond: bool) -> void:
	_all += 1
	if cond:
		_ok += 1
		print("PASS  ", title)
	else:
		print("FAIL  ", title)
