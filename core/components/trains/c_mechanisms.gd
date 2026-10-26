class_name C_Mechanisms extends ICapability

####################
## Способность. Подвижные части вагона/локо: двери, позже пантограф, дышла, фары...
####################
## Один компонент держит СПИСОК механизмов (Entity не допускает два компонента одного типа).
## Конфиг: WagonConfig.mechanisms (Array[MechanismConfig]). Узлы ищет PartRegistry (C_Visual.parts),
## по роли, а не по имени.
##
## ИСКЛЮЧЕНИЕ из Node Ownership: меши принадлежит C_TrainVisual, но трансформ узла, который
## объявлен механизмом (part_role), двигает ТОЛЬКО этот компонент. C_TrainVisual их не трогает.
##
## События IN:  on_mechanism_set {id, state 0..1}, on_mechanism_toggle {id}
## События OUT: on_mechanism_changed {id, state, moving} - начало и конец движения (звук, UI)
##
## СВЕТ (ATTN_16_mechanisms.md). Тот же компонент держит и источники света: WagonConfig.lights (Array[LightConfig]).
## Источники создаются КОДОМ в точках из конфига (позиция, поворот, родитель-роль), маркеры в сцене не нужны.
## События IN:  on_light_set {id, state 0..1}, on_light_toggle {id}
## События OUT: on_light_changed {id, state, changing}
## Тени у источников сущностей выключены всегда (тени только у лампы стола, GFX).
## Отладка (Global.debug_mode, сущность выбрана): I - вкл/выкл весь свет, Shift+I - метки источников и размеры кузова в Output
## Порядок в components: Identity -> TrainVisual -> ... -> Mechanisms

class Mech extends RefCounted:
	var cfg: MechanismConfig
	var node: Node3D            # null - часть не найдена
	var rest: Transform3D       # поза покоя (t = 0), как пришла из сцены
	var t := 0.0                # текущее состояние 0..1
	var target := 0.0
	var enabled := true
	var manual := false         # игрок взял управление (на будущее: AUTO-правила)

	func is_moving() -> bool:
		return not is_equal_approx(t, target)

	## Возвращает true, если дошли до цели в этом шаге
	func step(dt: float) -> bool:
		var was_moving := is_moving()
		t = move_toward(t, target, dt / maxf(cfg.duration, 0.01))
		apply()
		return was_moving and not is_moving()

	func apply() -> void:
		if node == null or not is_instance_valid(node):
			return
		var k := smoothstep(0.0, 1.0, t)
		var ax := cfg.axis.normalized() if cfg.axis.length_squared() > 0.0001 else Vector3.RIGHT
		match cfg.actuator:
			MechanismConfig.Actuator.SLIDE:
				node.transform = Transform3D(rest.basis, rest.origin + ax * cfg.travel * k)
			MechanismConfig.Actuator.ROTATE:
				node.transform = Transform3D(rest.basis * Basis(ax, deg_to_rad(cfg.travel * k)), rest.origin)


class Lamp extends RefCounted:
	var cfg: LightConfig
	var anchor: Node3D          # родитель источника; null - узел-родитель не найден
	var light: Light3D          # null - источник не создан (kind EMISSIVE до шага L6)
	var gizmo: Node3D           # отладочная метка точки и направления
	var t := 0.0                # текущая яркость 0..1
	var target := 0.0
	var enabled := true
	var manual := false         # игрок взял управление (на будущее: AUTO-правила)

	func is_changing() -> bool:
		return not is_equal_approx(t, target)

	## Возвращает true, если дошли до цели в этом шаге
	func step(dt: float, ghost: bool) -> bool:
		var was := is_changing()
		t = move_toward(t, target, dt / maxf(cfg.fade_time, 0.01))
		apply(ghost)
		return was and not is_changing()

	func apply(ghost: bool) -> void:
		if light == null or not is_instance_valid(light):
			return
		light.light_energy = cfg.energy * t
		light.visible = t > 0.001 and not ghost


var _mechs: Dictionary = {}          # StringName -> Mech
var _order: Array[StringName] = []
var _saved: Dictionary = {}          # id(String) -> {t, manual, enabled}
var _lamps: Dictionary = {}          # StringName -> Lamp
var _lamp_order: Array[StringName] = []
var _saved_lights: Dictionary = {}   # id(String) -> {t, manual, enabled}
var _gizmos_on := false
var _ghost := false


func _init() -> void:
	set_process(false)


func on_entity_ready() -> void:
	var vis := get_comp(C_Visual) as C_Visual
	var identity := get_comp(C_Identity) as C_Identity
	if vis == null or vis.parts == null or identity == null:
		return
	_ghost = has_comp(C_Ghost)
	var cfgs: Variant = identity.get_config('mechanisms', [])
	for c in cfgs:
		var cfg := c as MechanismConfig
		if cfg == null or _mechs.has(cfg.id):
			continue
		var m := Mech.new()
		m.cfg = cfg
		m.enabled = cfg.enabled
		m.node = vis.parts.find_one(cfg.part_role, cfg.part_aliases, &"Node3D", null, str(entity.name)) as Node3D
		if m.node:
			m.rest = m.node.transform
		m.t = cfg.start_state
		m.target = cfg.start_state
		_mechs[cfg.id] = m
		_order.append(cfg.id)
	_apply_saved()
	for id in _order:
		_mechs[id].apply()

	var lcfgs: Variant = identity.get_config('lights', [])
	for c in lcfgs:
		var lc := c as LightConfig
		if lc == null or _lamps.has(lc.id):
			continue
		_lamps[lc.id] = _build_lamp(lc, vis)
		_lamp_order.append(lc.id)
	_apply_saved_lights()
	_apply_all_lamps()


func on_component_added(type: Script) -> void:
	if type == C_Ghost:
		_ghost = true
		_apply_all_lamps()


func on_component_removed(type: Script) -> void:
	if type == C_Ghost:
		_ghost = false
		_apply_all_lamps()


# ==========================================
# Команды (шина)
# ==========================================

func on_mechanism_set(data: Dictionary) -> void:
	set_state(data.get("id", &""), data.get("state", 1.0))


func on_mechanism_toggle(data: Dictionary) -> void:
	var m: Mech = _mechs.get(StringName(data.get("id", &"")))
	if m:
		set_state(m.cfg.id, 0.0 if m.target > 0.5 else 1.0)


## Публичный API (для InfoPanel и тестов)
func set_state(id: StringName, state: float) -> void:
	var m: Mech = _mechs.get(StringName(id))
	if m == null or not m.enabled or _ghost:
		return
	m.target = clampf(state, 0.0, 1.0)
	m.manual = true
	set_process(true)
	entity.send_event("on_mechanism_changed", {"id": m.cfg.id, "state": m.target, "moving": true})


func set_enabled(id: StringName, on: bool) -> void:
	var m: Mech = _mechs.get(StringName(id))
	if m:
		m.enabled = on


## Список для вкладки "Механизмы" в InfoPanel
func get_list() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for id in _order:
		var m: Mech = _mechs[id]
		res.append({
			"id": id, "title": m.cfg.title, "t": m.t, "target": m.target,
			"found": m.node != null, "enabled": m.enabled, "moving": m.is_moving(),
		})
	return res


func _process(delta: float) -> void:
	var any := false
	for id in _order:
		var m: Mech = _mechs[id]
		if not m.is_moving():
			continue
		if m.step(delta):
			entity.send_event("on_mechanism_changed", {"id": id, "state": m.t, "moving": false})
		any = any or m.is_moving()
	for id in _lamp_order:
		var l: Lamp = _lamps[id]
		if not l.is_changing():
			continue
		if l.step(delta, _ghost):
			entity.send_event("on_light_changed", {"id": id, "state": l.t, "changing": false})
		any = any or l.is_changing()
	if not any:
		set_process(false)


# ==========================================
# СВЕТ: команды (шина) и API
# ==========================================

func on_light_set(data: Dictionary) -> void:
	set_light(data.get("id", &""), data.get("state", 1.0))


func on_light_toggle(data: Dictionary) -> void:
	var l: Lamp = _lamps.get(StringName(data.get("id", &"")))
	if l:
		set_light(l.cfg.id, 0.0 if l.target > 0.5 else 1.0)


## Публичный API (для InfoPanel и тестов). state 0..1: яркость
func set_light(id: StringName, state: float) -> void:
	var l: Lamp = _lamps.get(StringName(id))
	if l == null or not l.enabled or _ghost or l.anchor == null:
		return
	l.target = clampf(state, 0.0, 1.0)
	l.manual = true
	set_process(true)
	entity.send_event("on_light_changed", {"id": l.cfg.id, "state": l.target, "changing": l.is_changing()})


func set_light_enabled(id: StringName, on: bool) -> void:
	var l: Lamp = _lamps.get(StringName(id))
	if l:
		l.enabled = on


## Список для вкладки "Механизмы" в InfoPanel (раздел "Свет")
func get_light_list() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for id in _lamp_order:
		var l: Lamp = _lamps[id]
		res.append({
			"id": id, "title": l.cfg.title, "t": l.t, "target": l.target,
			"found": l.anchor != null and l.light != null, "enabled": l.enabled, "changing": l.is_changing(),
		})
	return res


func _build_lamp(cfg: LightConfig, vis: C_Visual) -> Lamp:
	var l := Lamp.new()
	l.cfg = cfg
	l.enabled = cfg.enabled
	var parent: Node3D = vis.instance
	if cfg.anchor_role != &"":
		parent = vis.parts.find_one(cfg.anchor_role, cfg.anchor_aliases, &"Node3D", null, str(entity.name)) as Node3D
	l.anchor = parent
	if parent == null:
		return l

	match cfg.kind:
		LightConfig.Kind.SPOT:
			var s := SpotLight3D.new()
			s.spot_range = cfg.light_range
			s.spot_angle = cfg.spot_angle
			s.spot_attenuation = cfg.spot_attenuation
			l.light = s
		LightConfig.Kind.OMNI:
			var o := OmniLight3D.new()
			o.omni_range = cfg.light_range
			l.light = o
		_:
			push_warning("[C_Mechanisms] %s: источник '%s' типа EMISSIVE пока не поддержан (шаг L6)" % [entity.name, cfg.id])

	if l.light:
		l.light.name = "Light_" + String(cfg.id)
		l.light.light_color = cfg.color
		l.light.light_energy = 0.0
		l.light.shadow_enabled = false     # тени только у лампы стола
		l.light.visible = false
		l.light.position = cfg.position
		l.light.rotation_degrees = cfg.rotation_deg
		parent.add_child(l.light)

	l.gizmo = _make_gizmo(cfg)
	l.gizmo.position = cfg.position
	l.gizmo.rotation_degrees = cfg.rotation_deg
	l.gizmo.visible = _gizmos_on
	parent.add_child(l.gizmo)

	l.t = cfg.start_state
	l.target = cfg.start_state
	return l


func _apply_all_lamps() -> void:
	for id in _lamp_order:
		_lamps[id].apply(_ghost)


## Метка точки (шарик) и направления (стрелка вдоль -Z источника). Видна по Shift+I
func _make_gizmo(cfg: LightConfig) -> Node3D:
	var root := Node3D.new()
	root.name = "LightGizmo_" + String(cfg.id)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = cfg.color
	mat.no_depth_test = true
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.3
	sm.material = mat
	ball.mesh = sm
	root.add_child(ball)
	if cfg.kind == LightConfig.Kind.SPOT:
		var arrow := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.03
		cm.bottom_radius = 0.03
		cm.height = 1.5
		cm.material = mat
		arrow.mesh = cm
		arrow.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		arrow.position = Vector3(0.0, 0.0, -0.75)
		root.add_child(arrow)
	return root


func toggle_gizmos() -> void:
	_gizmos_on = not _gizmos_on
	for id in _lamp_order:
		var l: Lamp = _lamps[id]
		if l.gizmo and is_instance_valid(l.gizmo):
			l.gizmo.visible = _gizmos_on


## В Output: размеры кузова в системе корня модели (в ней же задаются position у LightConfig) и список источников
func print_layout() -> void:
	var vis := get_comp(C_Visual) as C_Visual
	if vis == null or vis.instance == null:
		return
	var lines: Array[String] = ["[Lights] %s. Оси корня модели: -Z нос, +Z хвост, +Y вверх, +X вправо по ходу" % entity.name]
	if not vis.mesh_nodes.is_empty() and vis.mesh_nodes[0].mesh:
		var m := vis.mesh_nodes[0]
		var b: AABB = (vis.instance.global_transform.affine_inverse() * m.global_transform) * m.mesh.get_aabb()
		lines.append("  кузов (mesh_nodes[0]): x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f" % [
			b.position.x, b.end.x, b.position.y, b.end.y, b.position.z, b.end.z])
	for id in _lamp_order:
		var l: Lamp = _lamps[id]
		lines.append("  %s: pos %s rot %s %s" % [id, l.cfg.position, l.cfg.rotation_deg,
				"" if l.anchor != null and l.light != null else "[NO LIGHT]"])
	print("\n".join(lines))


## Для вкладки Debug
func get_debug_info() -> Array[String]:
	var res: Array[String] = []
	for id in _order:
		var m: Mech = _mechs[id]
		res.append("%s: t=%.2f -> %.2f %s%s" % [id, m.t, m.target,
				"" if m.node else "[NO PART] ", "" if m.enabled else "[off]"])
	for id in _lamp_order:
		var l: Lamp = _lamps[id]
		res.append("light %s: t=%.2f -> %.2f %s%s" % [id, l.t, l.target,
				"" if l.light else "[NO LIGHT] ", "" if l.enabled else "[off]"])
	return res


# ==========================================
# ВРЕМЕННО, до вкладки в InfoPanel: O - переключить все механизмы выбранного вагона
# ==========================================

func _unhandled_input(event: InputEvent) -> void:
	if not Global.debug_mode or _ghost or (_mechs.is_empty() and _lamps.is_empty()) or not has_comp(C_Selected):
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_O:
		for id in _order:
			on_mechanism_toggle({"id": id})
	elif event.keycode == KEY_I:
		if event.shift_pressed:
			toggle_gizmos()
			print_layout()
		else:
			# все источники: если хоть один горит, гасим, иначе включаем
			var any_on := false
			for id in _lamp_order:
				any_on = any_on or _lamps[id].target > 0.5
			for id in _lamp_order:
				set_light(id, 0.0 if any_on else 1.0)


# ==========================================
# SAVE / LOAD
# ==========================================

func save_data() -> Dictionary:
	var d := {}
	for id in _order:
		var m: Mech = _mechs[id]
		d[String(id)] = {"t": m.t, "manual": m.manual, "enabled": m.enabled}
	var ld := {}
	for id in _lamp_order:
		var l: Lamp = _lamps[id]
		ld[String(id)] = {"t": l.t, "manual": l.manual, "enabled": l.enabled}
	return {
		'comp_path': get_script().resource_path,
		'comp_name': get_script().resource_path.get_file().get_basename(),
		'mech': d,
		'lights': ld,
	}


## SaveManager зовёт после add_child, то есть после on_entity_ready: применяем сразу
func load_data(data: Dictionary) -> void:
	_saved = data.get('mech', {})
	_apply_saved()
	_saved_lights = data.get('lights', {})
	_apply_saved_lights()


func _apply_saved() -> void:
	for key in _saved.keys():
		var m: Mech = _mechs.get(StringName(key))
		if m == null:
			continue
		var s: Dictionary = _saved[key]
		m.t = float(s.get("t", m.t))
		m.target = m.t
		m.manual = bool(s.get("manual", false))
		m.enabled = bool(s.get("enabled", m.enabled))
		m.apply()


func _apply_saved_lights() -> void:
	for key in _saved_lights.keys():
		var l: Lamp = _lamps.get(StringName(key))
		if l == null:
			continue
		var d: Dictionary = _saved_lights[key]
		l.t = float(d.get("t", l.t))
		l.target = l.t
		l.manual = bool(d.get("manual", false))
		l.enabled = bool(d.get("enabled", l.enabled))
		l.apply(_ghost)
