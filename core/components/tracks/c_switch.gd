class_name C_Switch extends ICapability

# XX claude-switch (новый файл)
####################
## Способность. Управление стрелкой: какой маршрут активен, кто и как его переключает.
####################
## Геометрию и маршруты держит C_Path (routes / active_route), форму строит C_SwitchShape.
## Тут только положение и правила перекладки:
##  - MANUAL: переключает рычаг у стрелки (клик по рычагу, источник &"manual");
##  - REMOTE: рычаг заблокирован (привод держит стрелку), команды приходят из панели/проводов (&"remote").
##    Время перекладки throw_time (0 = мгновенно). Пока идет перекладка, состояние MOVING.
##  - Стрелку под вагоном не переложить (замок): пока тележка стоит на этом траке, команда отклоняется.
## Шина событий:
##   on_switch_request {route = -1 (следующий) или индекс, source} -> data.ok / data.reason
##   on_lever_pressed {collider, consumed} - от SelectTool по клику в рычаг
##   исходящие: on_switch_changed {route, source}, on_switch_moving {route}, on_switch_rejected {reason}
## Электрика режима E0: стрелка один проводящий трак (C_PowerTrack), PGM ничего не знает о маршруте.

enum Drive { MANUAL, REMOTE }
enum State { SETTLED, MOVING }

const GROUP := &"switch"

var route := 0
var control: Drive = Drive.MANUAL
## Время перекладки, с. 0 = мгновенно
var throw_time := 0.0
var state: State = State.SETTLED

var _target := 0
var _source: StringName = &"manual"
var _t := 0.0


func _init() -> void:
	set_physics_process(false)


func on_added() -> void:
	entity.add_to_group(GROUP)


func on_entity_ready() -> void:
	var identity := get_comp(C_Identity) as C_Identity
	if identity:
		route = int(identity.get_config('start_route', 0))
	_apply(route, &"init")


# ==========================================
# API
# ==========================================

func route_count() -> int:
	var p := get_comp(C_Path) as C_Path
	return maxi(p.routes.size(), 1) if p else 1


## Запрос на перекладку. target = -1: следующий маршрут по кругу. Возвращает true, если принят
func request(target: int, source: StringName) -> bool:
	if state == State.MOVING:
		return _reject(&"moving")
	var n := route_count()
	if n < 2:
		return _reject(&"single_route")
	if target < 0:
		target = (route + 1) % n
	if target >= n:
		return _reject(&"bad_route")
	if source != &"force":
		if control == Drive.MANUAL and source != &"manual":
			return _reject(&"manual_only")
		if control == Drive.REMOTE and source != &"remote":
			return _reject(&"remote_only")
	if target == route:
		return true
	if is_occupied():
		return _reject(&"occupied")

	if throw_time <= 0.0:
		_apply(target, source)
	else:
		state = State.MOVING
		_target = target
		_source = source
		_t = 0.0
		set_physics_process(true)
		entity.send_event("on_switch_moving", {"route": target})
	return true


## Замок: на стрелке стоит тележка какого-либо вагона
func is_occupied() -> bool:
	if entity == null or not entity.is_inside_tree():
		return false
	for node in entity.get_tree().get_nodes_in_group(C_Bogie.GROUP):
		var wagon := node as Entity
		if wagon == null or wagon.is_queued_for_deletion():
			continue
		var bc := wagon.get_comp(C_Bogie) as C_Bogie
		if bc == null:
			continue
		for b in bc.bogies_data:
			if b.current_track == entity:
				return true
	return false


# ==========================================
# События
# ==========================================

func on_switch_request(data: Dictionary) -> void:
	var ok := request(int(data.get("route", -1)), data.get("source", &"remote"))
	data["ok"] = ok


## Клик в рычаг (SelectTool шлет, когда луч попал в слой handles и сущность имеет C_Switch).
## Забираем нажатие всегда, даже если стрелка не приняла команду (иначе клик выберет/потащит трак)
func on_lever_pressed(data: Dictionary) -> void:
	var col := data.get("collider") as Node
	if col == null or not col.has_meta(&"switch_lever") or not entity.is_ancestor_of(col):
		return
	request(-1, &"manual")
	data["consumed"] = true


func _unhandled_key_input(event: InputEvent) -> void:
	# Временная кнопка пульта: T по выбранной стрелке = команда remote. Заменит панель/провода (Roadmap 13)
	if event.is_action_pressed(&"key_t") and entity and entity.has_comp(C_Selected) and not entity.has_comp(C_Ghost):
		request(-1, &"remote")


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < throw_time:
		return
	set_physics_process(false)
	state = State.SETTLED
	if is_occupied():
		_reject(&"occupied")   # пока перекладывали, заехала тележка: возвращаем как было
		return
	_apply(_target, _source)


# ==========================================
# Внутреннее
# ==========================================

func _apply(target: int, source: StringName) -> void:
	var path := get_comp(C_Path) as C_Path
	if path and path.is_multi_route():
		path.set_active_route(target)
	route = target
	entity.send_event("on_switch_changed", {"route": route, "source": source})


func _reject(reason: StringName) -> bool:
	entity.send_event("on_switch_rejected", {"reason": reason})
	return false


# ==========================================
# Save / Load
# ==========================================

func save_data() -> Dictionary:
	return {
		'comp_path': get_script().resource_path,
		'comp_name': get_script().resource_path.get_file().get_basename(),
		"route": route,
		"control": int(control),
		"throw_time": throw_time,
	}


func load_data(data: Dictionary) -> void:
	control = int(data.get("control", control)) as Drive
	throw_time = float(data.get("throw_time", throw_time))
	# Положение применяем сразу: сущность уже собрана (SaveManager грузит после add_child),
	# а вагоны садятся на трак позже (restore_snap_after_load) и считают смещение по активной кривой
	_apply(int(data.get("route", route)), &"load")
