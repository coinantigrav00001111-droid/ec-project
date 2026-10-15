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


var _mechs: Dictionary = {}          # StringName -> Mech
var _order: Array[StringName] = []
var _saved: Dictionary = {}          # id(String) -> {t, manual, enabled}
var _ghost := false


func _init() -> void:
	set_process(false)


func on_entity_ready() -> void:
	var vis := get_comp(C_Visual) as C_Visual
	var identity := get_comp(C_Identity) as C_Identity
	if vis == null or vis.parts == null or identity == null:
		return
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


func on_component_added(type: Script) -> void:
	if type == C_Ghost:
		_ghost = true


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
	if not any:
		set_process(false)


## Для вкладки Debug
func get_debug_info() -> Array[String]:
	var res: Array[String] = []
	for id in _order:
		var m: Mech = _mechs[id]
		res.append("%s: t=%.2f -> %.2f %s%s" % [id, m.t, m.target,
				"" if m.node else "[NO PART] ", "" if m.enabled else "[off]"])
	return res


# ==========================================
# ВРЕМЕННО, до вкладки в InfoPanel: O - переключить все механизмы выбранного вагона
# ==========================================

func _unhandled_input(event: InputEvent) -> void:
	if not Global.debug_mode or _ghost or _mechs.is_empty() or not has_comp(C_Selected):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_O:
		for id in _order:
			on_mechanism_toggle({"id": id})


# ==========================================
# SAVE / LOAD
# ==========================================

func save_data() -> Dictionary:
	var d := {}
	for id in _order:
		var m: Mech = _mechs[id]
		d[String(id)] = {"t": m.t, "manual": m.manual, "enabled": m.enabled}
	return {
		'comp_path': get_script().resource_path,
		'comp_name': get_script().resource_path.get_file().get_basename(),
		'mech': d,
	}


## SaveManager зовёт после add_child, то есть после on_entity_ready: применяем сразу
func load_data(data: Dictionary) -> void:
	_saved = data.get('mech', {})
	_apply_saved()


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
