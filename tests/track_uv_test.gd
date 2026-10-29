extends Node

# XX claude-track-studio (новый файл)
## Проверка шага T0 (ATTN_20): UV рельса и балласта по тайлу, тангенты, поправка питания, валидатор.
## Запуск: открыть tests/track_uv_test.tscn и нажать F6. Итог в Output: строки PASS/FAIL и «TrackUV: n/m».

const L := 20.0
const EPS := 0.001

var _ok := 0
var _all := 0


func _ready() -> void:
	var curve := Curve3D.new()
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -L))

	# --- 1. Стиль по умолчанию: UV как раньше ---
	var st := TrackStyle.new()
	var am := TrackMeshBuilder.build_mesh(st, curve, L, false)
	var b := _uv_range(am, 0)   # балласт
	_check("по умолчанию: балласт UV.x от -L*0.1 до 0", absf(b.position.x + L * 0.1) < EPS and absf(b.end.x) < EPS)
	_check("по умолчанию: балласт UV.y в 0..1", b.position.y > -EPS and b.end.y < 1.0 + EPS)
	var r := _uv_range(am, 1)   # рельсы
	_check("по умолчанию: рельс UV.x от -L*0.1 до 0", absf(r.position.x + L * 0.1) < EPS and absf(r.end.x) < EPS)
	_check("по умолчанию: рельс UV.y в 0..1", r.position.y > -EPS and r.end.y < 1.0 + EPS)
	_check("по умолчанию: power_stripe_scale = 1", is_equal_approx(st.power_stripe_scale(), 1.0))
	_check("по умолчанию: тангенты не строятся", _has_tangents(am, 0) == false and _has_tangents(am, 1) == false)

	# --- 2. Свой тайл ---
	var st2 := TrackStyle.new()
	st2.ballast_uv_tile = Vector2(2.0, 1.0)
	st2.rail_uv_tile = Vector2(5.0, 0.5)
	var am2 := TrackMeshBuilder.build_mesh(st2, curve, L, false)
	var b2 := _uv_range(am2, 0)
	# длина ломаной балласта: 0.7071 + 2.2 + 0.7071
	var ballast_len := 2.0 * Vector2(0.5, 0.5).length() + 2.2
	_check("тайл (2,1): балласт UV.x от -L/2 до 0", absf(b2.position.x + L / 2.0) < EPS and absf(b2.end.x) < EPS)
	_check("тайл (2,1): балласт UV.y от 0 до длины ломаной", absf(b2.position.y) < EPS and absf(b2.end.y - ballast_len / 1.0) < EPS)
	var r2 := _uv_range(am2, 1)
	_check("тайл (5,0.5): рельс UV.x от -L/5 до 0", absf(r2.position.x + L / 5.0) < EPS and absf(r2.end.x) < EPS)
	# длина ломаной рельса 0.25 + 0.2 + 0.25 = 0.7, делим на 0.5
	_check("тайл (5,0.5): рельс UV.y до 0.7/0.5", absf(r2.end.y - 0.7 / 0.5) < EPS)
	_check("тайл (5,0): power_stripe_scale = 0.5", is_equal_approx(_scale_of(Vector2(5.0, 0.0)), 0.5))

	# --- 3. Тайл по одной оси ---
	var st3 := TrackStyle.new()
	st3.ballast_uv_tile = Vector2(0.0, 1.0)
	var b3 := _uv_range(TrackMeshBuilder.build_mesh(st3, curve, L, false), 0)
	_check("тайл (0,1): вдоль как раньше, поперёк в мировых", absf(b3.position.x + L * 0.1) < EPS and b3.end.y > 1.5)

	# --- 4. Нормальная карта даёт тангенты ---
	var st4 := TrackStyle.new()
	var mat := StandardMaterial3D.new()
	mat.normal_enabled = true
	mat.normal_texture = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGB8))
	st4.rail_material = mat
	st4.ballast_material = mat
	var am4 := TrackMeshBuilder.build_mesh(st4, curve, L, false)
	_check("нормальная карта: у балласта и рельса есть тангенты", _has_tangents(am4, 0) and _has_tangents(am4, 1))

	# --- 5. Валидатор ---
	var msgs := TrackStyleValidator.validate(TrackStyle.new())
	var bad := 0
	for m in msgs:
		if m["level"] >= TrackStyleValidator.Level.WARN:
			bad += 1
	_check("валидатор: стиль по умолчанию без ошибок и предупреждений", bad == 0)

	var broken := TrackStyle.new()
	broken.rail_profile = PackedVector2Array([Vector2(0.1, 0.0), Vector2(0.1, 0.25), Vector2(-0.1, 0.25), Vector2(-0.1, 0.0)])
	_check("валидатор: обход справа налево - ошибка", _count_level(broken, TrackStyleValidator.Level.ERROR) >= 1)

	var cross := TrackStyle.new()
	cross.ballast_profile = PackedVector2Array([Vector2(-1.6, 0.0), Vector2(1.1, 0.5), Vector2(-1.1, 0.5), Vector2(1.6, 0.0)])
	_check("валидатор: самопересечение профиля - ошибка", _count_level(cross, TrackStyleValidator.Level.ERROR) >= 1)

	var narrow := TrackStyle.new()
	narrow.sleeper_size = Vector3(1.5, 0.2, 0.3)
	_check("валидатор: шпала уже колеи - ошибка", _count_level(narrow, TrackStyleValidator.Level.ERROR) >= 1)

	var wide := TrackStyle.new()
	wide.collision_width = 4.0
	_check("валидатор: collision_width не по основанию - предупреждение", _count_level(wide, TrackStyleValidator.Level.WARN) >= 1)

	var tiny := TrackStyle.new()
	tiny.rail_profile = PackedVector2Array([Vector2(0.0, 0.0)])
	_check("валидатор: профиль из одной точки - ошибка и can_build = false",
		_count_level(tiny, TrackStyleValidator.Level.ERROR) >= 1 and not TrackStyleValidator.can_build(tiny))

	# --- 6. Разбор профиля из текста ---
	var pr := TrackStyleIO.parse_profile("-0.1 0\n-0.1, 0.25 \n# комментарий\n0,1;0.25\n0.1\t0")
	_check("parse_profile: 4 точки, запятая как десятичная", pr["ok"] and (pr["points"] as PackedVector2Array).size() == 4 and absf((pr["points"] as PackedVector2Array)[2].x - 0.1) < EPS)
	_check("parse_profile: ошибка в строке", not TrackStyleIO.parse_profile("1 2\nabc").ok)

	print("TrackUV: %d/%d" % [_ok, _all])
	get_tree().quit(0 if _ok == _all else 1)


func _scale_of(tile: Vector2) -> float:
	var s := TrackStyle.new()
	s.rail_uv_tile = tile
	return s.power_stripe_scale()


func _count_level(s: TrackStyle, level: int) -> int:
	var n := 0
	for m in TrackStyleValidator.validate(s):
		if m["level"] == level:
			n += 1
	return n


## Границы UV поверхности: position = минимум, end = максимум
func _uv_range(am: ArrayMesh, surface: int) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var arrays := am.surface_get_arrays(surface)
	for uv in (arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array):
		lo = lo.min(uv)
		hi = hi.max(uv)
	return Rect2(lo, hi - lo)


func _has_tangents(am: ArrayMesh, surface: int) -> bool:
	var t = am.surface_get_arrays(surface)[Mesh.ARRAY_TANGENT]
	return t != null and (t as PackedFloat32Array).size() > 0


func _check(title: String, cond: bool) -> void:
	_all += 1
	if cond:
		_ok += 1
		print("PASS  ", title)
	else:
		print("FAIL  ", title)
