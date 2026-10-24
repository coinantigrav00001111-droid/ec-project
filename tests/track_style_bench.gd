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
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_cam = Camera3D.new()
	_cam.far = 4000.0
	add_child(_cam)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = SHADOWS
	_sun.rotation_degrees = Vector3(-60, 30, 0)
	add_child(_sun)
	await get_tree().process_frame

	_rows.append("| набор | вариант | траков | создание, мс | узлов | коллизий | обзор, тени: мс / фпс / отрис. | обзор, без теней | план, тени | план, без теней | план: тени есть, трак НЕ отбрасывает | обзор: рендер CPU / GPU, мс | план: рендер CPU / GPU, мс | объектов в обзоре | треуг. в обзоре, тыс | process мс | physics мс (ср / макс) / тиков в сек (цель: см. project.godot) | видеопамять, МБ |")
	_rows.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for suite in SUITES:
		for item in suite[2]:
			for n in COUNTS:
				await _run(suite[0], suite[1], item[0], OBJ + item[1], n)

	await _sweep()
	await _physics_probe()

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
	# В игре тени траков по умолчанию выключены (QualityPreset.track_shadows). Для сравнения со старыми замерами
	# включаем их обратно: колонки «тени» и «без теней» показывают худший случай, колонка «трак НЕ отбрасывает»
	# соответствует умолчанию игры
	_set_track_shadows(spawned, true)
	var counts := _count_nodes()

	var need := _over_height(w, d)
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

	_rows.append("| %s | %s | %d | %.0f | %d | %d | %s | %s | %s | %s | %s | %s | %s | %d | %.0f | %.2f | %.2f / %.2f / %.0f | %.0f |" % [
		suite, label, n, spawn_ms, counts[0], counts[2],
		_fmt(over), _fmt(over_ns), _fmt(close), _fmt(close_ns), _fmt(close_nc),
		_fmt_rt(over), _fmt_rt(close_nc),
		over.objs, over.prims / 1000.0, over.proc, over.phys, over.phys_max, over.phz, over.vram])
	print(_rows.back())

	for e in spawned:
		e.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame


## Время кадра на рендер: процессор / видеокарта, мс (если драйвер не отдаёт GPU-время, будет 0)
func _fmt_rt(m: Dictionary) -> String:
	return "%.2f / %.2f" % [m.rcpu, m.rgpu]


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


## Строка пробы: кадр при hz0 и оценка тика относительно кадра при 1 Гц
func _probe_row(label: String, cam_pos: Vector3, f1: float, hz: int) -> void:
	var m: Dictionary = await _measure(cam_pos)
	_rows.append("| %s | %d | %.2f | %.0f | %s | %.0f | %.2f |" % [
		label, hz, m.ms, m.fps, _fmt_rt(m), m.phz, 1000.0 * (m.ms - f1) / (hz * m.ms)])
	print(_rows.back())


## Все узлы заданного класса под entity
func _find_all(root: Node, cls: String) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd.is_class(cls):
			out.append(nd)
		stack.append_array(nd.get_children())
	return out


## Что физического в среднем на один трак и сколько узлов крутят _physics_process / _process
func _phys_counts(entities: Array[Entity]) -> Dictionary:
	var areas := 0
	var bodies := 0
	var shapes := 0
	var phys_proc := 0
	var proc := 0
	for e in entities:
		var stack: Array[Node] = [e]
		while not stack.is_empty():
			var nd: Node = stack.pop_back()
			if nd is Area3D:
				areas += 1
			elif nd is StaticBody3D:
				bodies += 1
			elif nd is CollisionShape3D:
				shapes += 1
			if nd.is_physics_processing():
				phys_proc += 1
			if nd.is_processing():
				proc += 1
			stack.append_array(nd.get_children())
	var n := float(maxi(entities.size(), 1))
	return {"areas": areas / n, "bodies": bodies / n, "shapes": shapes / n, "phys_proc": phys_proc / n, "proc": proc / n}


## Высота камеры, при которой сетка w x d целиком в кадре
func _over_height(w: float, d: float) -> float:
	var aspect := 16.0 / 9.0
	var vp := get_viewport().get_visible_rect().size
	if vp.y > 0.0:
		aspect = vp.x / vp.y
	var half_t := tan(deg_to_rad(_cam.fov) * 0.5)
	return maxf(d * 0.5, w * 0.5 / aspect) / half_t * 1.1


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
	var pf0 := last_pf
	var t_start := Time.get_ticks_usec()
	var phys_n := 0
	var vp_rid := get_viewport().get_viewport_rid()
	var r_cpu := 0.0
	var r_gpu := 0.0
	for i in SAMPLE_FRAMES:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		dt_sum += (now - last) / 1000.0
		last = now
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		r_cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp_rid)
		r_gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
		var pf := Engine.get_physics_frames()
		if pf != last_pf:   # монитор обновляется только после физического тика, иначе читали бы старое значение
			last_pf = pf
			var p := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			phys += p
			phys_n += 1
			phys_max = maxf(phys_max, p)
	var ms := dt_sum / SAMPLE_FRAMES
	var elapsed := maxf((Time.get_ticks_usec() - t_start) / 1000000.0, 0.001)
	return {
		"rcpu": r_cpu / SAMPLE_FRAMES,
		"rgpu": r_gpu / SAMPLE_FRAMES,
		"phz": (Engine.get_physics_frames() - pf0) / elapsed,
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


# ==========================================
# Прогон качества и дальности теней (процедурный трак, 500 штук, обзор и крупный план)
# ==========================================

const SWEEP_FILE := "s239_wood_ballast.tres"
const SWEEP_COUNT := 500
## label, тени вообще, трак отбрасывает, каскадов (1/2/4), дальность м, фильтр 0..5 (0 жёсткие, 2 Soft Low, 5 ultra), атлас
const SWEEP := [
	["без теней", false, true, 4, 100.0, 2, 4096],
	["тени есть, трак не отбрасывает", true, false, 4, 100.0, 2, 4096],
	["база: 4 каскада, 100 м, фильтр 2, атлас 4096", true, true, 4, 100.0, 2, 4096],
	["2 каскада", true, true, 2, 100.0, 2, 4096],
	["1 каскад (orthogonal)", true, true, 1, 100.0, 2, 4096],
	["дальность 60 м", true, true, 4, 60.0, 2, 4096],
	["дальность 30 м", true, true, 4, 30.0, 2, 4096],
	["фильтр 0 (жёсткие)", true, true, 4, 100.0, 0, 4096],
	["фильтр 4 (мягкие high)", true, true, 4, 100.0, 4, 4096],
	["атлас 2048", true, true, 4, 100.0, 2, 2048],
	["атлас 8192", true, true, 4, 100.0, 2, 8192],
	["2 каскада + 40 м (дешёвый вариант)", true, true, 2, 40.0, 2, 2048],
]


func _sweep() -> void:
	var setting := load(OBJ + SWEEP_FILE) as EntitySetting
	if setting == null:
		return
	var cell := Vector2(4.0, 24.0)
	var factory := EntityFactory.new()
	var cols := maxi(1, ceili(sqrt(SWEEP_COUNT * cell.y / cell.x)))
	var spawned: Array[Entity] = []
	for i in SWEEP_COUNT:
		var e: Entity = factory.create_from_setting(setting)
		add_child(e)
		e.global_position = Vector3((i % cols) * cell.x, 0.0, -floori(float(i) / cols) * cell.y)
		spawned.append(e)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var w := cols * cell.x
	var d := ceili(float(SWEEP_COUNT) / cols) * cell.y
	var center := Vector3(w * 0.5, 0.0, -d * 0.5)
	var over_pos := Vector3(center.x, _over_height(w, d), center.z)
	var close_pos := Vector3(center.x, 25.0, center.z)

	_rows.append("")
	_rows.append("Прогон теней: s239 дерево+балласт x %d. Строка: вариант | обзор: мс / фпс / отрис. | план: мс / фпс / отрис." % SWEEP_COUNT)
	_rows.append("| вариант | обзор | план |")
	_rows.append("|---|---|---|")
	for cfg in SWEEP:
		_sun.shadow_enabled = cfg[1]
		_set_track_shadows(spawned, cfg[2])
		match cfg[3]:
			1:
				_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			2:
				_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			_:
				_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		_sun.directional_shadow_max_distance = cfg[4]
		RenderingServer.directional_soft_shadow_filter_set_quality(cfg[5] as RenderingServer.ShadowQuality)
		RenderingServer.directional_shadow_atlas_set_size(cfg[6], true)
		var over := await _measure(over_pos)
		var close := await _measure(close_pos)
		_rows.append("| %s | %s | %s |" % [cfg[0], _fmt(over), _fmt(close)])
		print(_rows.back())

	for e in spawned:
		e.queue_free()
	await get_tree().physics_frame


# ==========================================
# Прогон частоты физики: сколько кадра съедают физические тики
# Кадр = (рендер + скрипты) + тики_за_кадр * стоимость_тика, а тиков за кадр = частота * время_кадра.
# Меряем обзор при разной частоте физики и по разнице выводим стоимость одного тика.
# Пустая сцена (0 траков) отделяет постоянную стоимость от стоимости траков.
# ==========================================

const PROBE := [
	["пустая сцена, 0 траков", "", 0],
	["бюджет G239 x500", "g239.tres", 500],
	["дерево+балласт x500", "s239_wood_ballast.tres", 500],
]
const PROBE_HZ := [1, 30, 60, 120]


func _physics_probe() -> void:
	var hz0 := Engine.physics_ticks_per_second
	_sun.shadow_enabled = false   # тени тут ни при чём, убираем их из измерения
	_rows.append("")
	_rows.append("Прогон частоты физики (обзор, тени выключены). Оценка тика = 1000 * (кадр - кадр при 1 Гц) / (Гц * кадр).")
	_rows.append("| сцена | физика, Гц | кадр, мс | фпс | рендер CPU / GPU, мс | тиков в сек (факт) | оценка тика, мс |")
	_rows.append("|---|---|---|---|---|---|---|")
	for item in PROBE:
		var n: int = item[2]
		var spawned: Array[Entity] = []
		var cam_pos := Vector3(0.0, 100.0, 0.0)
		if n > 0:
			var setting := load(OBJ + item[1]) as EntitySetting
			if setting == null:
				continue
			var cell := Vector2(4.0, 24.0)
			var factory := EntityFactory.new()
			var cols := maxi(1, ceili(sqrt(n * cell.y / cell.x)))
			for i in n:
				var e: Entity = factory.create_from_setting(setting)
				add_child(e)
				e.global_position = Vector3((i % cols) * cell.x, 0.0, -floori(float(i) / cols) * cell.y)
				spawned.append(e)
			var w := cols * cell.x
			var d := ceili(float(n) / cols) * cell.y
			cam_pos = Vector3(w * 0.5, _over_height(w, d), -d * 0.5)
			await get_tree().physics_frame
			await get_tree().physics_frame
		var res := {}
		for hz in PROBE_HZ:
			Engine.physics_ticks_per_second = hz
			res[hz] = await _measure(cam_pos)
		var f1: float = res[1].ms
		for hz in PROBE_HZ:
			var m: Dictionary = res[hz]
			var tick_cost = 1000.0 * (m.ms - f1) / (hz * m.ms) if hz > 1 else 0.0
			_rows.append("| %s | %d | %.2f | %.0f | %s | %.0f | %s |" % [
				item[0], hz, m.ms, m.fps, _fmt_rt(m), m.phz, ("%.2f" % tick_cost) if hz > 1 else "-"])
			print(_rows.back())
		if n > 0:
			var pc := _phys_counts(spawned)
			_rows.append("  на один трак: Area3D %.1f, StaticBody3D %.1f, CollisionShape3D %.1f; узлов с _physics_process на 100 траков: %.0f, с _process: %.0f" % [
				pc.areas, pc.bodies, pc.shapes, pc.phys_proc * 100.0, pc.proc * 100.0])
			print(_rows.back())
			# Серия проб: что ещё стоит тика. Каждая строка добавляет отключение к предыдущим.
			Engine.physics_ticks_per_second = hz0
			# а) C_TrackSupport совсем выключен
			for e in spawned:
				var ts := e.get_comp(C_TrackSupport) as C_TrackSupport
				if ts:
					ts.set_physics_process(false)
			await _probe_row(item[0] + " [C_TrackSupport выкл]", cam_pos, f1, hz0)
			# б) у всех Area3D выключен мониторинг (балласт это Area3D)
			for e in spawned:
				for a in _find_all(e, "Area3D"):
					(a as Area3D).set_deferred("monitoring", false)
					(a as Area3D).set_deferred("monitorable", false)
			await get_tree().physics_frame
			await _probe_row(item[0] + " [+ Area3D monitoring выкл]", cam_pos, f1, hz0)
			# в) у всех CollisionShape3D выключен disabled
			for e in spawned:
				for c in _find_all(e, "CollisionShape3D"):
					(c as CollisionShape3D).set_deferred("disabled", true)
			await get_tree().physics_frame
			await _probe_row(item[0] + " [+ все CollisionShape3D выкл]", cam_pos, f1, hz0)
		Engine.physics_ticks_per_second = hz0
		for e in spawned:
			e.queue_free()
		await get_tree().physics_frame
