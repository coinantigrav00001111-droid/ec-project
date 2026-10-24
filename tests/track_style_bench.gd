extends Node3D

# XX claude-styles (новый файл)
## Замер шага 1.5: сколько стоит процедурный трак по сравнению с бюджетным (сцены из Blender).
## Запуск: открыть tests/track_style_bench.tscn и нажать F6 (лучше без отладчика: Debug -> Run without debugger,
## отладчик искажает фпс). Окно должно быть открыто и видимым, результат в Output и в user://track_style_bench.md.
## Для каждой пары «вариант x число траков» тест: спавнит сетку траков, ждёт прогрева,
## меряет обзор сверху (видно всё) и крупный план (видна ~десятая часть, остальное отсекается), затем чистит сцену.
## Вертикальная синхронизация и лимит фпс на время теста выключены.

const COUNTS := [300, 500]
const WARMUP_FRAMES := 60
const SAMPLE_FRAMES := 120
const SHADOWS := true          # тень от направленного света: она удваивает число отрисовок
const OBJ := "res://data/tracks/objects/"

## suite: [название, размер ячейки (ширина, глубина), [[метка, файл], ...]]. Первый вариант в наборе = бюджет (эталон)
const SUITES := [
	["прямые", Vector2(4.0, 24.0), [
		["бюджет G239 (Blender)", "g239.tres"],
		["дерево+балласт", "s239_wood_ballast.tres"],
		["дерево", "s239_wood.tres"],
		["бетон+балласт", "s239_concrete_ballast.tres"],
		["бетон", "s239_concrete.tres"]]],
	["дуги R2", Vector2(24.0, 24.0), [
		["бюджет R2 (Blender)", "r2.tres"],
		["дерево+балласт", "sr2_wood_ballast.tres"],
		["бетон", "sr2_concrete.tres"]]],
	["пандусы 0.5", Vector2(4.0, 24.0), [
		["бюджет G239-05 (Blender)", "g239_r05.tres"],
		["дерево+балласт", "s239r05_wood_ballast.tres"]]],
]

var _cam: Camera3D
var _sun: DirectionalLight3D
var _rows: Array[String] = []


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_cam = Camera3D.new()
	_cam.far = 4000.0
	add_child(_cam)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = SHADOWS
	_sun.rotation_degrees = Vector3(-60, 30, 0)
	add_child(_sun)
	await get_tree().process_frame

	_rows.append("| набор | вариант | траков | создание, мс | узлов | коллизий | обзор, тени: мс / фпс / отрис. | обзор, без теней | план, тени | план, без теней | план: тени есть, трак НЕ отбрасывает | объектов в обзоре | треуг. в обзоре, тыс | process мс | physics мс (ср / макс) | видеопамять, МБ |")
	_rows.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for suite in SUITES:
		for item in suite[2]:
			for n in COUNTS:
				await _run(suite[0], suite[1], item[0], OBJ + item[1], n)

	var report := "\n".join(_rows)
	print("\n", report)
	var path := "user://track_style_bench.md"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(report)
		f.close()
		print("\nсохранено: ", ProjectSettings.globalize_path(path))
	get_tree().quit()


func _run(suite: String, cell: Vector2, label: String, file: String, n: int) -> void:
	var setting := load(file) as EntitySetting
	if setting == null:
		push_error("нет объекта: " + file)
		return
	var has_identity := false
	for c in setting.components:
		if c is IdentitySetting:
			has_identity = true
	if not has_identity:
		push_warning("пропуск %s: в объекте нет IdentitySetting (Entity._ready падает на get_name_e)" % file)
		return
	var factory := EntityFactory.new()
	var cols := maxi(1, ceili(sqrt(n * cell.y / cell.x)))
	var spawned: Array[Entity] = []

	var t0 := Time.get_ticks_usec()
	for i in n:
		var e: Entity = factory.create_from_setting(setting)
		add_child(e)
		e.global_position = Vector3((i % cols) * cell.x, 0.0, -floori(float(i) / cols) * cell.y)
		spawned.append(e)
	var spawn_ms := (Time.get_ticks_usec() - t0) / 1000.0

	await get_tree().physics_frame
	await get_tree().physics_frame

	var rows_count := ceili(float(n) / cols)
	var w := cols * cell.x
	var d := rows_count * cell.y
	var center := Vector3(w * 0.5, 0.0, -d * 0.5)
	var counts := _count_nodes()

	# 1) обзор: камера над центром, в кадре вся сетка
	var aspect := 16.0 / 9.0
	var vp := get_viewport().get_visible_rect().size
	if vp.y > 0.0:
		aspect = vp.x / vp.y
	var half_t := tan(deg_to_rad(_cam.fov) * 0.5)
	var need := maxf(d * 0.5, w * 0.5 / aspect) / half_t * 1.1
	var over_pos := Vector3(center.x, need, center.z)
	var close_pos := Vector3(center.x, 25.0, center.z)
	_sun.shadow_enabled = SHADOWS
	var over := await _measure(over_pos)                 # 1) обзор: вся сетка в кадре
	var close := await _measure(close_pos)               # 2) крупный план: малая часть, с тенями
	_sun.shadow_enabled = false                          # 3) то же без теней: чистая стоимость геометрии
	var over_ns := await _measure(over_pos)
	var close_ns := await _measure(close_pos)
	_sun.shadow_enabled = SHADOWS                        # 4) тени от солнца есть, но трак их не отбрасывает
	_set_track_shadows(spawned, false)
	var close_nc := await _measure(close_pos)

	_rows.append("| %s | %s | %d | %.0f | %d | %d | %s | %s | %s | %s | %s | %d | %.0f | %.2f | %.2f / %.2f | %.0f |" % [
		suite, label, n, spawn_ms, counts[0], counts[2],
		_fmt(over), _fmt(over_ns), _fmt(close), _fmt(close_ns), _fmt(close_nc),
		over.objs, over.prims / 1000.0, over.proc, over.phys, over.phys_max, over.vram])
	print(_rows.back())

	for e in spawned:
		e.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame


func _fmt(m: Dictionary) -> String:
	return "%.2f / %.0f / %d" % [m.ms, m.fps, m.draws]


## Включает или выключает отбрасывание теней у всей геометрии траков (меши и MultiMesh шпал)
func _set_track_shadows(entities: Array[Entity], on: bool) -> void:
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for e in entities:
		var stack: Array[Node] = [e]
		while not stack.is_empty():
			var nd: Node = stack.pop_back()
			if nd is GeometryInstance3D:
				(nd as GeometryInstance3D).cast_shadow = mode
			stack.append_array(nd.get_children())


## Ставит камеру сверху, прогревает, затем усредняет кадры
func _measure(cam_pos: Vector3) -> Dictionary:
	_cam.global_position = cam_pos
	_cam.look_at(Vector3(cam_pos.x, 0.0, cam_pos.z), Vector3.FORWARD)
	for i in WARMUP_FRAMES:
		await get_tree().process_frame
	var dt_sum := 0.0
	var proc := 0.0
	var phys := 0.0
	var phys_max := 0.0
	var last := Time.get_ticks_usec()
	var last_pf := Engine.get_physics_frames()
	var phys_n := 0
	for i in SAMPLE_FRAMES:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		dt_sum += (now - last) / 1000.0
		last = now
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var pf := Engine.get_physics_frames()
		if pf != last_pf:   # монитор обновляется только после физического тика, иначе читали бы старое значение
			last_pf = pf
			var p := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			phys += p
			phys_n += 1
			phys_max = maxf(phys_max, p)
	var ms := dt_sum / SAMPLE_FRAMES
	return {
		"ms": ms,
		"fps": 1000.0 / maxf(ms, 0.001),
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objs": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"prims": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"proc": proc / SAMPLE_FRAMES,
		"phys": phys / maxi(phys_n, 1),
		"phys_max": phys_max,
		"vram": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
	}


## [всего узлов, MeshInstance3D, CollisionShape3D] под тестом (без камеры и света)
func _count_nodes() -> Array:
	var stack: Array[Node] = [self]
	var total := 0
	var meshes := 0
	var shapes := 0
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		total += 1
		if nd is MeshInstance3D:
			meshes += 1
		elif nd is CollisionShape3D:
			shapes += 1
		stack.append_array(nd.get_children())
	return [total - 3, meshes, shapes]
