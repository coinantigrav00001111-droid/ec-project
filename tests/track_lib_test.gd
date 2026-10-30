extends Node

# XX claude-track-studio (новый файл)
## Проверка шагов T2 и T3 (ATTN_20): разбор наборов текстур, сборка материала, конвертация нормали,
## генератор и нормализация меша шпалы. Запуск: открыть tests/track_lib_test.tscn и нажать F6.
## Итог в Output: строки PASS/FAIL и «TrackLib: n/m». Файлы набора не меняются (временные файлы в user://track_lib_test).

const SETS := "res://data/textures/track"
const TMP := "user://track_lib_test"
const EPS := 0.002

var _ok := 0
var _all := 0


func _ready() -> void:
	_test_scan_real_sets()
	_test_scan_names()
	_test_build_material()
	_test_dx_to_gl()
	_test_generator()
	_test_normalize()
	print("TrackLib: %d/%d" % [_ok, _all])
	get_tree().quit(0 if _ok == _all else 1)


# --- T2: наборы ---

func _test_scan_real_sets() -> void:
	var sets := TrackMaterialBuilder.list_sets(SETS)
	print("наборы: ", sets)
	for s in sets:
		var f := TrackMaterialBuilder.scan(SETS.path_join(s))
		var keys := []
		for k in f:
			keys.append(k)
		print("  %s: %s" % [s, keys])
		if s.ends_with("_1K-JPG"):
			_check("%s: цвет, нормаль GL, шероховатость найдены" % s,
				f.has("albedo") and f.has("normal") and f.has("roughness") and f.get("normal_is_dx", true) == false)
			_check("%s: IdMask и превью не приняты за карты" % s, not f.has("idmask") and String(f.get("albedo", "")).contains("_Color"))
	if sets.has("Metal007_1K-JPG"):
		var m := TrackMaterialBuilder.scan(SETS.path_join("Metal007_1K-JPG"))
		_check("Metal007: есть карта металличности, нет AO", m.has("metallic") and not m.has("ao"))
	if sets.has("Sleeper_01v1"):
		var sl := TrackMaterialBuilder.scan(SETS.path_join("Sleeper_01v1"))
		_check("Sleeper_01v1 (свои имена): цвет, нормаль, шероховатость, металличность, AO",
			sl.has("albedo") and sl.has("normal") and sl.has("roughness") and sl.has("metallic") and sl.has("ao"))
	if sets.has("Gravel023_1K-JPG"):
		var info := TrackMaterialBuilder.import_info(String(TrackMaterialBuilder.scan(SETS.path_join("Gravel023_1K-JPG"))["normal"]))
		_check("import_info читает .import нормали", info["ok"])


func _test_scan_names() -> void:
	DirAccess.make_dir_recursive_absolute(TMP + "/ph")
	for n in ["rock_diff_1k.jpg", "rock_nor_gl_1k.jpg", "rock_nor_dx_1k.jpg", "rock_rough_1k.jpg", "rock_arm_1k.jpg", "rock_disp_1k.png", "readme.txt"]:
		var fa := FileAccess.open(TMP + "/ph/" + n, FileAccess.WRITE)
		fa.store_8(0)
		fa.close()
	var f := TrackMaterialBuilder.scan(TMP + "/ph")
	_check("Poly Haven имена: цвет, нормаль GL (не DX), шероховатость, ORM, высота",
		f.has("albedo") and f.has("roughness") and f.has("orm") and f.has("height")
		and String(f["normal"]).contains("nor_gl") and f["normal_is_dx"] == false)
	DirAccess.make_dir_recursive_absolute(TMP + "/dx")
	var fb := FileAccess.open(TMP + "/dx/wall_NormalDX.jpg", FileAccess.WRITE)
	fb.store_8(0)
	fb.close()
	var g := TrackMaterialBuilder.scan(TMP + "/dx")
	_check("только NormalDX: нормаль найдена и помечена как DX", g.has("normal") and g["normal_is_dx"] == true)


func _test_build_material() -> void:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	var t := ImageTexture.create_from_image(img)
	var tex := {"albedo": t, "normal": t, "roughness": t, "ao": t}
	var ballast := TrackMaterialBuilder.build(tex, TrackMaterialBuilder.preset("ballast"))
	_check("ballast: нормаль включена, AO включено, металличность 0 без карты",
		ballast.normal_enabled and ballast.ao_enabled and is_equal_approx(ballast.metallic, 0.0))
	_check("ballast: фильтр с мипмапами и анизотропией",
		ballast.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC)
	var tex2 := tex.duplicate()
	tex2["metallic"] = t
	var rail := TrackMaterialBuilder.build(tex2, TrackMaterialBuilder.preset("rail"))
	_check("rail: металличность 1 при карте, AO выключено пресетом", is_equal_approx(rail.metallic, 1.0) and not rail.ao_enabled)
	var sl := TrackMaterialBuilder.preset("sleeper")
	sl["triplanar"] = true
	sl["mesh_uv_units"] = false
	sl["tile"] = Vector2(2.0, 2.0)
	var sm := TrackMaterialBuilder.build(tex, sl)
	_check("sleeper triplanar: uv1_triplanar и масштаб 1/тайл", sm.uv1_triplanar and is_equal_approx(sm.uv1_scale.x, 0.5))
	var gen := TrackMaterialBuilder.preset("sleeper")
	gen["tile"] = Vector2(4.0, 4.0)
	var gm := TrackMaterialBuilder.build(tex, gen)
	_check("sleeper по умолчанию: UV в ю, без triplanar, цвет вершин включён",
		not gm.uv1_triplanar and is_equal_approx(gm.uv1_scale.x, 0.25) and gm.vertex_color_use_as_albedo)
	var orm := TrackMaterialBuilder.build({"albedo": t, "orm": t}, TrackMaterialBuilder.preset("ballast"))
	_check("ORM: каналы AO=R, rough=G, metal=B",
		orm.ao_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED
		and orm.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		and orm.metallic_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_BLUE)
	# реальный набор: текстуры грузятся и материал собирается
	var found := TrackMaterialBuilder.scan(SETS.path_join("Gravel023_1K-JPG"))
	if not found.is_empty():
		var real := TrackMaterialBuilder.build(TrackMaterialBuilder.load_textures(found), TrackMaterialBuilder.preset("ballast"))
		_check("Gravel023: материал с цветом, нормалью и шероховатостью", real.albedo_texture != null and real.normal_texture != null and real.roughness_texture != null)


func _test_dx_to_gl() -> void:
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color8(100, 10, 200))
	DirAccess.make_dir_recursive_absolute(TMP)
	img.save_png(TMP + "/x_NormalDX.png")
	var out := TrackMaterialBuilder.convert_dx_to_gl(TMP + "/x_NormalDX.png")
	var ok := false
	if not out.is_empty():
		var r := Image.load_from_file(out)
		var px := r.get_pixel(0, 0)
		ok = absi(roundi(px.g8) - 245) <= 1 and absi(roundi(px.r8) - 100) <= 1 and absi(roundi(px.b8) - 200) <= 1
	_check("DX -> GL: зелёный канал инвертирован, остальные нет", ok)


# --- T3: шпалы ---

@warning_ignore("integer_division")
func _test_generator() -> void:
	var wood := TrackSleeperFactory.generate({})
	var a := wood.get_aabb()
	var base_tris := wood.get_faces().size() / 3
	_check("корпус: размер 3 × 0.2 × 0.3", _near(a.size, Vector3(3.0, 0.2, 0.3)))
	_check("корпус: центр опоры в 0, низ на 0", absf(a.get_center().x) < EPS and absf(a.get_center().z) < EPS and absf(a.position.y) < EPS)
	_check("корпус: одна поверхность, 32 треугольника, без вершинного цвета", wood.get_surface_count() == 1 and base_tris == 32 and wood.surface_get_arrays(0)[Mesh.ARRAY_COLOR] == null)
	_check("рельеф 0: лишних рёбер нет (те же 32 треугольника)",
		TrackSleeperFactory.generate({"top_dip": 0.0, "side_notch": 0.0}).get_faces().size() / 3 == base_tris)

	var trap := TrackSleeperFactory.generate({"profile": "trapezoid"})
	_check("трапеция: тот же габарит, треугольников 24 (6 граней)", _near(trap.get_aabb().size, Vector3(3.0, 0.2, 0.3)) and trap.get_faces().size() / 3 == 24)

	# площадки на любом сечении
	for prof in ["rect", "trapezoid"]:
		var pm := TrackSleeperFactory.generate({"profile": prof, "pads": true, "rail_x": 0.875, "pad_x": 0.875})
		_check("площадки на сечении %s: высота 0.22, +24 треугольника" % prof,
			absf(pm.get_aabb().size.y - 0.22) < EPS and pm.get_faces().size() / 3 == TrackSleeperFactory.generate({"profile": prof}).get_faces().size() / 3 + 24)
	var padded := TrackSleeperFactory.generate({"pads": true, "pad_color": Color(1, 0, 0)})
	var cols = padded.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var white := 0
	var red := 0
	if cols != null:
		for c in (cols as PackedColorArray):
			if c.is_equal_approx(Color.WHITE):
				white += 1
			elif c.r > 0.9 and c.g < 0.1:
				red += 1
	_check("площадки: вершинный цвет (корпус белый, площадки заданного цвета), одна поверхность", white > 0 and red == 72 and padded.get_surface_count() == 1)

	# рельс на корпусе при включённых площадках
	var seat := TrackSleeperFactory.generate({"pads": true, "pad_lifts_rail": false})
	var st_seat := TrackStyle.new()
	st_seat.sleeper_mesh = seat
	var st_lift := TrackStyle.new()
	st_lift.sleeper_mesh = padded
	_check("pad_lifts_rail = false: постель рельса 0.2 при AABB 0.22", absf(st_seat.sleeper_dims().y - 0.2) < EPS and absf(seat.get_aabb().size.y - 0.22) < EPS)
	_check("pad_lifts_rail = true: рельс на площадке, постель 0.22", absf(st_lift.sleeper_dims().y - 0.22) < EPS)

	# рельеф
	var dip := TrackSleeperFactory.generate({"top_dip": 0.03})
	_check("прогиб верха: треугольников больше, габарит прежний", dip.get_faces().size() / 3 > base_tris and _near(dip.get_aabb().size, Vector3(3.0, 0.2, 0.3)))
	var notch := TrackSleeperFactory.generate({"side_notch": 0.03})
	_check("выемки на боках: треугольников больше, габарит прежний", notch.get_faces().size() / 3 > base_tris and _near(notch.get_aabb().size, Vector3(3.0, 0.2, 0.3)))
	var both := TrackSleeperFactory.generate({"top_dip": 0.03, "side_notch": 0.03, "profile": "trapezoid", "pads": true})
	_check("рельеф с площадками и трапецией строится", both.get_faces().size() > 0 and both.get_surface_count() == 1)
	var dip_only := TrackSleeperFactory.generate({"top_dip": 0.03}).get_faces().size()
	_check("прогиб не трогает бока: те же вершины торцов (меньше, чем прогиб + выемки)", dip_only < TrackSleeperFactory.generate({"top_dip": 0.03, "side_notch": 0.03}).get_faces().size())

	# UV
	var uv_a: PackedVector2Array = TrackSleeperFactory.generate({}).surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var uv_b: PackedVector2Array = TrackSleeperFactory.generate({"uv_rotate": true}).surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var swapped := uv_a.size() == uv_b.size() and uv_a.size() > 0
	for i in mini(uv_a.size(), uv_b.size()):
		if not is_equal_approx(uv_a[i].x, uv_b[i].y) or not is_equal_approx(uv_a[i].y, uv_b[i].x):
			swapped = false
			break
	_check("uv_rotate: u и v поменялись местами", swapped)

	# контракт и валидатор
	var st := TrackStyle.new()
	st.sleeper_mesh = wood
	var bad := 0
	for m in TrackStyleValidator.validate(st):
		if m["level"] >= TrackStyleValidator.Level.WARN:
			bad += 1
	_check("валидатор: сгенерированная шпала без замечаний", bad == 0)
	var padded_style := TrackStyle.new()
	padded_style.sleeper_mesh = TrackSleeperFactory.generate({"pads": true, "pad_lifts_rail": false, "top_dip": 0.03, "side_notch": 0.03})
	var bad2 := 0
	for m in TrackStyleValidator.validate(padded_style):
		if m["level"] >= TrackStyleValidator.Level.WARN:
			bad2 += 1
	_check("валидатор: шпала с площадками и рельефом без замечаний", bad2 == 0)
	# нормали наружу: у верхней грани нормаль вверх
	var arrays := wood.surface_get_arrays(0)
	var up := 0
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in verts.size():
		if absf(verts[i].y - 0.2) < 0.0001 and norms[i].y > 0.9:
			up += 1
	_check("корпус: у вершин верха нормаль вверх", up >= 4)
	# в рельефе нормали тоже наружу: ни одной нормали, смотрящей внутрь от центра сечения (грубо: низ смотрит вниз)
	var rv: PackedVector3Array = dip.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var rn: PackedVector3Array = dip.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var inward := 0
	for i in rv.size():
		if rv[i].y < 0.0001 and rn[i].y > 0.5:
			inward += 1
	_check("прогиб: у вершин низа нет нормалей вверх", inward == 0)


func _test_normalize() -> void:
	var src := TrackSleeperFactory.generate({})
	# «неправильный» меш: в сантиметрах, повёрнут на 90°, смещён
	var bad_xf := Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * 100.0), Vector3(10.0, 7.0, -3.0))
	var res := TrackSleeperFactory.normalize([{"mesh": src, "xform": bad_xf}], {"scale": 0.01})
	var mesh: ArrayMesh = res["mesh"]
	var a := mesh.get_aabb()
	_check("normalize: размер 3 × 0.2 × 0.3 после масштаба и авто-поворота", _near(a.size, Vector3(3.0, 0.2, 0.3)))
	_check("normalize: центр опоры в 0, низ на 0", absf(a.get_center().x) < EPS and absf(a.get_center().z) < EPS and absf(a.position.y) < EPS)
	_check("normalize: в отчёте есть заметка о повороте", (res["report"]["notes"] as PackedStringArray).size() >= 1)
	var merged := TrackSleeperFactory.normalize([{"mesh": TrackSleeperFactory.generate({"profile": "trapezoid", "pads": true}), "xform": Transform3D.IDENTITY}], {"merge": true})
	_check("normalize: слияние даёт одну поверхность", (merged["mesh"] as ArrayMesh).get_surface_count() == 1)


func _near(a: Vector3, b: Vector3) -> bool:
	return (a - b).length() < EPS


func _check(title: String, cond: bool) -> void:
	_all += 1
	if cond:
		_ok += 1
		print("PASS  ", title)
	else:
		print("FAIL  ", title)
