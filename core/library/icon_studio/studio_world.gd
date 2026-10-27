extends Node3D

########################
## Icon Studio: мир студии (ATTN_18 §18.3.2, шаги I1 и часть I2)
########################
## Живёт внутри SubViewport с own_world_3d = true: свои камера, свет и окружение.
## Держит объект (Entity из фабрики или просто сцена), считает его AABB, ведёт орбитальную камеру.
## Свет пока временный (три источника следуют за камерой), полная настройка в шаге I3.

signal camera_changed

const SOURCE_ENTITY := 0   ## объект собирается EntityFactory, как в игре
const SOURCE_SCENE := 1    ## запасной путь: только PackedScene из визуал-компонента (ATTN_18 R1)

const FIT_MARGIN := 0.08
const ORBIT_SPEED := 0.4        # градусов на пиксель
const ZOOM_STEP := 1.1
const PITCH_LIMIT := 89.0

var yaw := 35.0
var pitch := -25.0              ## отрицательный = смотрим сверху
var fov := 30.0
var ortho := false
var zoom := 1.0
var pivot_offset := Vector3.ZERO

var subject: Node3D
var bounds := AABB(Vector3(-5.0, 0.0, -5.0), Vector3(10.0, 10.0, 10.0))

var _factory: EntityFactory
var _subject_root: Node3D
var _cam: Camera3D
var _key: DirectionalLight3D
var _fill: DirectionalLight3D
var _rim: DirectionalLight3D
var _env: Environment
var _token := 0                 # номер последнего запроса: устаревшие ответы отбрасываем
var _drag_button := 0
var _fit_dist := 30.0
var _fit_size := 30.0


func _ready() -> void:
	_factory = EntityFactory.new()
	add_child(_factory)

	_subject_root = Node3D.new()
	_subject_root.name = "Subject"
	add_child(_subject_root)

	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.56, 0.59, 0.63)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.85, 0.87, 0.95)
	_env.ambient_light_energy = 0.55
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = _env
	add_child(we)

	_key = _make_light("Key", 1.25, true)
	_fill = _make_light("Fill", 0.35, false)
	_rim = _make_light("Rim", 0.6, false)

	_cam = Camera3D.new()
	_cam.name = "Camera"
	_cam.current = true
	add_child(_cam)
	_update_camera()


func _make_light(light_name: String, energy: float, shadow: bool) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.name = light_name
	l.light_energy = energy
	l.shadow_enabled = shadow
	add_child(l)
	return l


# ==========================================
# ОБЪЕКТ
# ==========================================

## Создаёт объект и ставит в мир. Возвращает словарь:
## ok, via, name, error, meshes, aabb, warn, stale (true: пока грузили, пришёл новый запрос)
func set_subject(setting: EntitySetting, source: int, settle_frames: int) -> Dictionary:
	_token += 1
	var token := _token
	_clear_subject()
	var info := {"ok": false, "via": "", "name": setting.name, "error": "", "meshes": 0,
		"aabb": AABB(), "warn": "", "stale": false}

	var node: Node3D = null
	if source == SOURCE_ENTITY:
		info.via = "entity"
		node = _factory.create_from_setting(setting)
	else:
		info.via = "scene"
		node = _scene_of(setting)
	if node == null:
		info.error = "не удалось создать объект (нет подходящего компонента или сцены)"
		return info

	# Тела не должны падать, пока объект «оживает» в первые кадры
	for body in _find_all(node, "RigidBody3D"):
		(body as RigidBody3D).freeze = true
	_subject_root.add_child(node)
	subject = node

	# Несколько кадров обработки: части компонентов строят меши отложенно. Потом всё замораживаем
	for i in settle_frames:
		await get_tree().process_frame
		if token != _token:
			info.stale = true
			return info
	await get_tree().process_frame
	if token != _token or not is_instance_valid(node):
		info.stale = true
		return info
	node.process_mode = Node.PROCESS_MODE_DISABLED

	var stat := _measure(node)
	info.meshes = stat.meshes
	if stat.meshes == 0:
		info.warn = "нет видимых мешей (меш мог не построиться, попробуйте больше кадров «settle» или источник «Сцена»)"
	else:
		bounds = stat.aabb
		info.aabb = stat.aabb
	info.ok = true
	return info


func _clear_subject() -> void:
	if is_instance_valid(subject):
		subject.process_mode = Node.PROCESS_MODE_DISABLED
		if subject.has_method("kill_me"):
			subject.kill_me()
		else:
			subject.queue_free()
		_subject_root.remove_child(subject)   # имя и группы освобождаются сразу, не ждём конца кадра
	subject = null


## Запасной путь: сцена из визуал-компонента (trackvisual) или из object_config (вагон, дом)
func _scene_of(setting: EntitySetting) -> Node3D:
	for cs in setting.components:
		var sc: Variant = cs.get("scene")
		if sc is PackedScene:
			return (sc as PackedScene).instantiate() as Node3D
		var ident := cs as IdentitySetting
		if ident != null and ident.object_config != null:
			var sc2: Variant = ident.object_config.get("scene")
			if sc2 is PackedScene:
				return (sc2 as PackedScene).instantiate() as Node3D
	return null


func _find_all(root: Node, type_name: String) -> Array[Node]:
	var res: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n.is_class(type_name):
			res.append(n)
	return res


## Суммарный AABB видимой геометрии. Подписи (Label3D) и невидимые узлы не считаем
func _measure(root: Node) -> Dictionary:
	var total := AABB()
	var has := false
	var count := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is GeometryInstance3D) or n is Label3D:
			continue
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var a := g.get_aabb()
		if a.size == Vector3.ZERO:
			continue
		var wa: AABB = g.global_transform * a
		total = wa if not has else total.merge(wa)
		has = true
		count += 1
	return {"aabb": total, "meshes": count}


# ==========================================
# КАМЕРА
# ==========================================

func get_camera_state() -> Dictionary:
	return {"yaw": yaw, "pitch": pitch, "fov": fov, "ortho": ortho}


func set_camera_state(d: Dictionary) -> void:
	yaw = float(d.get("yaw", yaw))
	pitch = clampf(float(d.get("pitch", pitch)), -PITCH_LIMIT, PITCH_LIMIT)
	fov = clampf(float(d.get("fov", fov)), 5.0, 90.0)
	ortho = bool(d.get("ortho", ortho))
	_update_camera()


func set_ortho(on: bool) -> void:
	ortho = on
	_update_camera()
	camera_changed.emit()


## Вписать объект в кадр: дистанция по описанной сфере AABB, камера в центр, зум и сдвиг сброшены
func fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	var aspect := maxf(vp.x, 1.0) / maxf(vp.y, 1.0)
	var radius := maxf(bounds.size.length() * 0.5, 0.01)
	var narrow := minf(1.0, aspect)   # в узком кадре ограничивает ширина
	var half := atan(tan(deg_to_rad(fov) * 0.5) * narrow)
	_fit_dist = radius / sin(half) * (1.0 + FIT_MARGIN)
	_fit_size = radius * 2.0 / narrow * (1.0 + FIT_MARGIN)
	zoom = 1.0
	pivot_offset = Vector3.ZERO
	_update_camera()
	camera_changed.emit()


func handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			match mb.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					zoom = clampf(zoom / ZOOM_STEP, 0.05, 20.0)
					_update_camera()
					camera_changed.emit()
				MOUSE_BUTTON_WHEEL_DOWN:
					zoom = clampf(zoom * ZOOM_STEP, 0.05, 20.0)
					_update_camera()
					camera_changed.emit()
				MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
					_drag_button = mb.button_index
		elif mb.button_index == _drag_button:
			_drag_button = 0
	elif event is InputEventMotion and _drag_button != 0:
		var mm := event as InputEventMouseMotion
		if mm == null:
			return
		var pan := _drag_button != MOUSE_BUTTON_LEFT or Input.is_key_pressed(KEY_SHIFT)
		if pan:
			_pan(mm.relative)
		else:
			yaw = fmod(yaw - mm.relative.x * ORBIT_SPEED, 360.0)
			pitch = clampf(pitch - mm.relative.y * ORBIT_SPEED, -PITCH_LIMIT, PITCH_LIMIT)
		_update_camera()
		camera_changed.emit()


func _pan(rel: Vector2) -> void:
	var vp_h := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var per_px: float
	if ortho:
		per_px = _fit_size * zoom / vp_h
	else:
		per_px = 2.0 * _fit_dist * zoom * tan(deg_to_rad(fov) * 0.5) / vp_h
	var b := _cam.global_basis
	pivot_offset += (-b.x * rel.x + b.y * rel.y) * per_px


func _update_camera() -> void:
	if _cam == null:
		return
	var up := deg_to_rad(-pitch)
	var yw := deg_to_rad(yaw)
	var dir := Vector3(sin(yw) * cos(up), sin(up), cos(yw) * cos(up))
	var pivot := bounds.get_center() + pivot_offset
	var radius := maxf(bounds.size.length() * 0.5, 0.01)
	var dist := _fit_dist if ortho else _fit_dist * zoom
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL if ortho else Camera3D.PROJECTION_PERSPECTIVE
	_cam.fov = fov
	_cam.size = _fit_size * zoom
	_cam.near = maxf(0.05, dist - radius * 3.0)
	_cam.far = dist + radius * 3.0 + 100.0
	_cam.global_position = pivot + dir * dist
	_cam.look_at(pivot, Vector3.UP)
	# Свет следует за камерой: всегда есть ключевой сверху-слева, заполняющий и контровой
	_aim(_key, -35.0, 40.0)
	_aim(_fill, -10.0, -55.0)
	_aim(_rim, -20.0, 160.0)
	_key.directional_shadow_max_distance = dist + radius * 3.0


## Поворот света относительно направления камеры (градусы). -Z света = направление луча
func _aim(l: DirectionalLight3D, pitch_deg: float, yaw_deg: float) -> void:
	l.global_basis = _cam.global_basis * Basis.from_euler(Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0.0))
