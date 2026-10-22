class_name C_BufferStop extends ICapability

# XX claude-switch (новый файл)
####################
## Способность. Упор (тупиковый буфер) на конце трака.
####################
## Геометрия трака обычная (одна кривая C_Path). Упор добавляет:
##  1. Физику. Торец стоит неподвижной "стеной" в конце кривой. Вагон, торец которого дошел до стены,
##     получает силу буфера (пружина с демпфером, как у C_Coupler при контакте буферов).
##     Первый контакт: Δv = (1 + e) * v_close. Если Δv > impact_dv_limit вагона или v_close > max_speed,
##     вагон сходит (on_derailed, reason = buffer_stop_impact), иначе отскакивает на буферах.
##     Силу считаем с приоритетом физики -10, то есть ДО C_Chassis (как C_Coupler).
##  2. Визуал: буферный брус и две стойки у стены (ноды в инстансе C_SwitchVisual, чтобы работали
##     оверлеи выделения/наведения).
##  3. Закрытый стык: сокет у стены выключается, к упору можно пристыковаться только открытым концом.
## Должен стоять в массиве компонентов ПОСЛЕ C_Path и C_Socket.
## Конфиг (C_Identity): BufferStopConfig (stop_at_end, max_speed).
## События наружу (звук/анимация): on_buffer_impact {wagon, v_close, dv, derailed}
##   Вагону уходят те же события, что при ударе сцепок: on_coupler_impact, on_derailed, on_coupler_force.

const SCAN_PERIOD := 0.1      # с, как часто обновляем список вагонов поблизости
const SCAN_MARGIN := 6.0      # ю, запас радиуса поиска
const MAX_OVERLAP := 2.0      # ю, глубже торец уже "за стеной": считаем, что вагон не касается
const RELEASE_GAP := 0.05     # ю, контакт отпускаем при таком зазоре
const BUMP_SPEED := 0.3       # ю/с, ниже стук не сообщаем

const BEAM_SIZE := Vector3(2.6, 0.9, 0.5)    # брус: ширина, высота, глубина вдоль пути
const POST_SIZE := Vector3(0.35, 1.2, 0.35)  # стойка

var stop_at_end := true
var max_speed := 0.0

# --- "ощущение" буфера, значения как у C_Coupler ---
var omega := 12.0            # частота, рад/с
var zeta := 0.25             # демпфирование (0.25 -> отскок ~0.44)
var hard_stop_mult := 6.0    # во сколько раз жестче упор буфера
var align_cos := 0.8         # торец должен смотреть на стену (cos угла)
var lateral_tol := 1.5       # допуск по боковому смещению торца, ю

var _contacts := {}          # "id_end" -> true, торцы, уже коснувшиеся стены
var _neighbors: Array[C_Coupler] = []
var _scan_timer := 0.0


func _init() -> void:
	process_physics_priority = -10   # раньше C_Chassis (0), как у C_Coupler


func on_entity_ready() -> void:
	var identity := get_comp(C_Identity) as C_Identity
	if identity:
		stop_at_end = bool(identity.get_config('stop_at_end', true))
		max_speed = float(identity.get_config('max_speed', 0.0))

	var path := get_comp(C_Path) as C_Path
	if path == null or path.curve == null:
		push_error("C_BufferStop: нужен C_Path перед компонентом")
		return

	_build_fitting(path)

	# Закрытый стык: к упору пристыковаться можно только открытым концом (0 - начало, 1 - конец кривой)
	entity.send_event("on_socket_enabled", {"index": 1 if stop_at_end else 0, "enabled": false})

	# Один маршрут: сообщаем визуалу и опорам, что путь готов (меш трака строит C_SwitchVisual по этому событию)
	var one: Array[Curve3D] = [path.curve]
	path.set_routes(one, 0)


# ==========================================
# Геометрия стены
# ==========================================

## Лицо упора: точка в конце кривой (мир) и направление ИЗ трака В упор (мир)
func _face() -> Dictionary:
	var path := get_comp(C_Path) as C_Path
	var curve := path.curve
	var s := curve.get_baked_length() if stop_at_end else 0.0
	var t := curve.sample_baked_with_rotation(s)
	var pos := path.path_node.to_global(t.origin)
	var fwd := (path.path_node.global_basis * -t.basis.z).normalized()
	return {"pos": pos, "dir": fwd if stop_at_end else -fwd}


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# ==========================================
# Физика
# ==========================================

func _physics_process(delta: float) -> void:
	if delta <= 0.0 or entity == null or not entity.is_inside_tree():
		return
	if entity.has_comp(C_Ghost):
		return
	var path := get_comp(C_Path) as C_Path
	if path == null or path.curve == null or path.path_node == null:
		return

	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = SCAN_PERIOD
		_refresh_neighbors()

	var face := _face()
	for cp in _neighbors:
		if not is_instance_valid(cp) or cp.entity == null:
			continue
		var ch := cp.entity.get_comp(C_Chassis) as C_Chassis
		if ch == null or not ch.is_on_rails:
			_forget(cp)
			continue
		for end in 2:
			_process_end(cp, end, ch, face, delta)


## Раз в SCAN_PERIOD собираем вагоны возле стены (грубая отсечка)
func _refresh_neighbors() -> void:
	var face := _face()
	var fpos: Vector3 = face.pos
	var fresh: Array[C_Coupler] = []
	for node in entity.get_tree().get_nodes_in_group(C_Coupler.GROUP):
		var cp := node as C_Coupler
		if cp == null or cp.entity == null or cp.entity.is_queued_for_deletion():
			continue
		if cp.entity.global_position.distance_to(fpos) <= cp.offset_z + SCAN_MARGIN:
			fresh.append(cp)
	_neighbors = fresh


func _process_end(cp: C_Coupler, end: int, ch: C_Chassis, face: Dictionary, delta: float) -> void:
	var key := "%d_%d" % [cp.get_instance_id(), end]

	# Торец вагона: позиция и наружная нормаль (нос -Z вагона, хвост +Z), всё в плоскости XZ
	var z := -cp.offset_z if end == C_Coupler.FRONT else cp.offset_z
	var p: Vector3 = cp.entity.global_transform * Vector3(0.0, 0.0, z)
	var n := -cp.entity.global_basis.z
	if end == C_Coupler.REAR:
		n = -n
	n = _flat(n)
	if n.length_squared() < 0.0001:
		return
	n = n.normalized()

	var fdir: Vector3 = _flat(face.dir).normalized()
	if n.dot(fdir) < align_cos:
		_contacts.erase(key)   # торец смотрит не на стену (другой конец вагона или другой путь)
		return

	var d: Vector3 = _flat(face.pos - p)
	var s := d.dot(n)                     # зазор до стены вдоль торца (<= 0: касание)
	if s > RELEASE_GAP:
		_contacts.erase(key)
		return
	if s > 0.0 or s < -MAX_OVERLAP:
		return
	if (d - n * s).length() > lateral_tol:
		_contacts.erase(key)              # сбоку от стены
		return

	var ax := ch.get_motion_axis()
	var v_close := (ax * ch.current_speed).dot(n)   # > 0: едет в стену

	if not _contacts.has(key):
		_contacts[key] = true
		if _first_contact(cp, ch, ax, n, v_close):
			return                        # вагон сошел, силу не считаем

	_apply_buffer_force(cp, ax, n, s, v_close, delta)


## Первый кадр касания. Возвращает true, если вагон разбился (сошел)
func _first_contact(cp: C_Coupler, ch: C_Chassis, ax: Vector3, n: Vector3, v_close: float) -> bool:
	if v_close <= 0.0:
		return false
	var dv := (1.0 + _restitution(zeta)) * v_close   # стена неподвижна: mu = m
	var crash := dv > cp.impact_dv_limit or (max_speed > 0.0 and v_close > max_speed)
	if crash:
		cp.entity.send_event("on_derailed", {
			"reason": "buffer_stop_impact",
			"current_velocity_3d": ax * ch.current_speed - n * dv,
		})
	cp.entity.send_event("on_coupler_impact", {"v_close": v_close, "dv": dv, "derailed": crash})
	if crash or v_close > BUMP_SPEED:
		entity.send_event("on_buffer_impact", {"wagon": cp.entity, "v_close": v_close, "dv": dv, "derailed": crash})
	return crash


## Сила буфера на вагон. Формулы как в C_Coupler._solve_link для сжатия, партнер неподвижен
func _apply_buffer_force(cp: C_Coupler, ax: Vector3, n: Vector3, s: float, v_close: float, dt: float) -> void:
	var m := _mass(cp)
	var w := minf(omega, 0.3 / dt)                   # устойчивость при любых массах и dt
	var trv := cp.buffer_travel
	var x := minf(-s, trv * 3.0)                     # глубину ограничиваем, чтобы дроп "внахлест" не взрывал вагон
	var sdot := -v_close                             # > 0: расходятся
	var push := m * (w * w * x - 2.0 * zeta * w * sdot)
	if x > trv:
		push += m * w * w * hard_stop_mult * (x - trv)   # упор буфера
	var f := maxf(push, 0.0)
	if f > 0.0:
		# Стена толкает вагон против его торца (-n). Проекция на ось движения, как у сцепки
		cp.entity.send_event("on_coupler_force", {"force": (-n * f).dot(ax)})


func _forget(cp: C_Coupler) -> void:
	_contacts.erase("%d_%d" % [cp.get_instance_id(), C_Coupler.FRONT])
	_contacts.erase("%d_%d" % [cp.get_instance_id(), C_Coupler.REAR])


func _mass(cp: C_Coupler) -> float:
	var k := cp.entity.get_comp(C_Kinematics) as C_Kinematics
	return maxf(k.mass, 0.01) if k else 1.0


## Коэффициент восстановления затухающего осциллятора (как в C_Coupler)
func _restitution(z: float) -> float:
	return exp(-PI * z / sqrt(1.0 - z * z))


# ==========================================
# Визуал: буферный брус и стойки
# ==========================================

func _build_fitting(path: C_Path) -> void:
	var vis := get_comp(C_TrackVisual) as C_TrackVisual
	if vis == null or vis.instance == null:
		return
	TrackMeshBuilder.ensure_materials()

	var curve := path.curve
	var L := curve.get_baked_length()
	var s := L if stop_at_end else 0.0
	var fr := TrackMeshBuilder.frame(curve, s, L)
	var outward := fr.f if stop_at_end else -fr.f       # из трака в упор (кривая-локально)
	var bas := Basis(fr.r, fr.u, fr.r.cross(fr.u))
	var top := path.head_height()

	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(0.72, 0.12, 0.10)
	beam_mat.roughness = 0.6
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.22, 0.22, 0.25)
	post_mat.roughness = 0.8

	var root := Node3D.new()
	root.name = "BufferFitting"
	vis.instance.add_child(root)

	# Брус: чуть за лицом стены (лицо = конец кривой), над поверхностью катания
	var beam_c: Vector3 = fr.p + outward * (BEAM_SIZE.z * 0.5) + fr.u * (top + 0.15 + BEAM_SIZE.y * 0.5)
	root.add_child(_box("Beam", BEAM_SIZE, beam_mat, Transform3D(bas, beam_c)))

	# Две стойки у колеи, от основания до низа бруса
	var post_h := top + 0.15
	var rail_x := 0.875
	if vis.get("style") != null:
		rail_x = (vis.get("style") as TrackStyle).rail_x
	for sx in [-1.0, 1.0]:
		var pc: Vector3 = fr.p + outward * (BEAM_SIZE.z * 0.5) + fr.r * (sx * rail_x) + fr.u * (post_h * 0.5)
		root.add_child(_box("Post", Vector3(POST_SIZE.x, post_h, POST_SIZE.z), post_mat, Transform3D(bas, pc)))


func _box(node_name: String, size: Vector3, mat: Material, xf: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.transform = xf
	return mi
