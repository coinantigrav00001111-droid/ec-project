class_name C_Fuse extends C_PowerDevice

#####################
## Предохранитель (ATTN_10 §10.9 D5)
#####################
## Вход и выход. Ток ветки (клипы, питаемые через него, и локо на их цепях) выше `limit_a`: через `HOLD_MS`
## предохранитель перегорает и размыкает ветку, выше `INSTANT_FACTOR` лимита сразу. Замена: кнопка во вкладке или клик по ручке.
## Ток ветки считает `PowerSolver.branch_current` по цепям клипов; если на тех же цепях стоят локо других веток, они тоже в сумме (приближение P1).

const HOLD_MS := 500
const INSTANT_FACTOR := 2.0

var limit_a := 1.0
var blown := false
var current := 0.0
var _over_since := -1
var _connected := false


func title() -> String:
	return "Предохранитель"


func positions() -> int:
	return 0


func state_text() -> String:
	return "ПЕРЕГОРЕЛ (%.1f А)" % limit_a if blown else "%.2f из %.1f А" % [current, limit_a]


func _build_terminals() -> void:
	_add_term(&"in", PowerTerminal.Role.DEV_IN, -1.2)
	_add_term(&"out", PowerTerminal.Role.DEV_OUT, 1.2)


func on_entity_ready() -> void:
	if entity.has_comp(C_Ghost) or _connected:
		return
	_connected = true
	PGM.solver_stepped.connect(_on_step)


func _exit_tree() -> void:
	if _connected and PGM.solver_stepped.is_connected(_on_step):
		PGM.solver_stepped.disconnect(_on_step)
		_connected = false


func _links_of(t: PowerTerminal) -> Array:
	if blown or t != term(&"out"):
		return []
	return [{"terminal": term(&"in"), "flip": false, "via": self}]


## Клик по ручке заменяет перегоревший предохранитель
func activate() -> void:
	if blown:
		replace_fuse()


func replace_fuse() -> void:
	if not blown:
		return
	blown = false
	_over_since = -1
	_changed()


func set_limit(a: float) -> void:
	limit_a = clampf(a, 0.1, 10.0)
	_refresh()


func _on_step() -> void:
	if blown or not is_instance_valid(entity):
		return
	var nets: Dictionary = {}
	for clip in PGM.active_clips:
		if is_instance_valid(clip) and clip.drive_via.has(self) and clip.feed_net() != 0:
			nets[clip.feed_net()] = true
	current = PowerSolver.branch_current(PGM.ports, nets, PGM.load_for_lights)
	if current > limit_a * INSTANT_FACTOR:
		_blow()
		return
	if current > limit_a:
		var now := Time.get_ticks_msec()
		if _over_since < 0:
			_over_since = now
		elif now - _over_since >= HOLD_MS:
			_blow()
			return
	else:
		_over_since = -1
	_refresh()


func _blow() -> void:
	blown = true
	current = 0.0
	_over_since = -1
	print("⚡ Предохранитель перегорел (лимит %.1f А)" % limit_a)
	_changed()


func _knob_color() -> Color:
	return Color(0.9, 0.15, 0.1) if blown else Color(0.85, 0.8, 0.5)


func _refresh() -> void:
	super()
	if _ctl != null:
		_ctl.rotation_degrees.y = 0.0


func save_data() -> Dictionary:
	return {"limit": limit_a, "blown": blown}


func load_data(d: Dictionary) -> void:
	limit_a = clampf(float(d.get("limit", 1.0)), 0.1, 10.0)
	blown = bool(d.get("blown", false))
	_refresh()
	PGM.request_recalculate()
