# XX claude-switch (новый файл)
## Интеграционный тест стрелки: вагон едет через стрелку в 6 сценариях.
## Запуск: открыть tests/switch_drive_test.tscn и нажать F6 (Run Current Scene).
## Результат смотреть в Output: путь передней тележки по тракам (F = подвод, SW = стрелка, S = прямой выход,
## D = выход ответвления) и флаг схода. Ожидается:
##   1) F0 > SW > S0 > S1            4) S1 > S0, сход (против положения)
##   2) F0 > SW > D0 > D1            5) D1 > D0 > SW > F0
##   3) S1 > S0 > SW > F0            6) D1 > D0, сход (против положения)
extends Node

var flex_s: EntitySetting
var wagon_s: EntitySetting
const TOE_Z := 11.95

func place(e: Entity, pos: Vector3) -> void:
	add_child(e)
	e.global_position = pos

func flex_at(pos: Vector3) -> Entity:
	var e: Entity = EntityFactory.new().create_from_setting(flex_s)
	place(e, pos)
	return e

func switch_ent(hand: int, start: int) -> Entity:
	var s: EntitySetting = load("res://data/tracks/objects/%s.tres" % ("switch_r" if hand > 0 else "switch_l"))
	s = s.duplicate()
	# Стартовое положение берется из паспорта при создании сущности, поэтому правим паспорт ДО фабрики
	for comp in s.components:
		if comp is IdentitySetting:
			(comp.object_config as SwitchConfig).start_route = start
	var e: Entity = EntityFactory.new().create_from_setting(s)
	place(e, Vector3.ZERO)
	return e

func scenario(title: String, route: int, from_exit: int) -> void:
	# сносим старое
	for c in get_children():
		c.free()
	await get_tree().physics_frame
	print("== ", title)
	var sw := switch_ent(1, route)
	await get_tree().physics_frame
	var swc := sw.get_comp(C_Switch) as C_Switch
	swc.request(route, &"force")
	var path := sw.get_comp(C_Path) as C_Path
	var heel1 := path.path_node.to_global(path.routes[1].sample_baked(path.routes[1].get_baked_length()))
	var tracks := {}
	# подводящие: 3 штуки перед носком (z +TOE_Z ... +TOE_Z+30)
	for i in 3: tracks["F%d" % i] = flex_at(Vector3(0, 0, TOE_Z + 10.0 * (i + 1)))
	# выход прямой: 3 штуки
	for i in 3: tracks["S%d" % i] = flex_at(Vector3(0, 0, -TOE_Z - 10.0 * i))
	# выход ответвления: 3 штуки от конца ветки
	for i in 3: tracks["D%d" % i] = flex_at(Vector3(heel1.x, 0, heel1.z - 10.0 * i))
	var names := {}
	for k in tracks: names[tracks[k]] = k
	names[sw] = "SW"
	await get_tree().physics_frame
	await get_tree().physics_frame

	var w: Entity = EntityFactory.new().create_from_setting(wagon_s)
	add_child(w)
	var start_track: Entity = tracks["F0"] if from_exit == 0 else (tracks["S1"] if from_exit == 1 else tracks["D1"])
	var offset := 3.0
	var speed := 8.0
	if from_exit != 0:
		speed = -8.0
	w.global_position = start_track.global_position
	w.get_comp(C_Chassis).on_train_snapped({"track": start_track, "offset": offset})
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ch := w.get_comp(C_Chassis) as C_Chassis
	var bg := w.get_comp(C_Bogie) as C_Bogie
	var seq: Array = []
	var derailed := false
	for f in 700:
		ch.current_speed = speed
		await get_tree().physics_frame
		if bg.is_derailed or not ch.is_on_rails:
			derailed = true
			break
		var tr = bg.bogies_data.front().current_track
		var nm: String = names.get(tr, "?")
		if seq.is_empty() or seq.back() != nm:
			seq.append(nm)
	print("  путь передней тележки: ", seq, " сход=", derailed)

func _ready():
	flex_s = load("res://data/tracks/objects/flex_01.tres")
	wagon_s = load("res://data/trains/objects/wagon_01.tres")
	print("wagon_s=", wagon_s != null, " flex_s=", flex_s != null)
	await scenario("Из носка, стрелка на ПРЯМО", 0, 0)
	await scenario("Из носка, стрелка на ОТВЕТВЛЕНИЕ", 1, 0)
	await scenario("С прямого конца к носку, стрелка на ПРЯМО (пускает)", 0, 1)
	await scenario("С прямого конца к носку, стрелка на ОТВЕТВЛЕНИЕ (против шерсти)", 1, 1)
	await scenario("С ветки к носку, стрелка на ОТВЕТВЛЕНИЕ (пускает)", 1, 2)
	await scenario("С ветки к носку, стрелка на ПРЯМО (против шерсти)", 0, 2)
	get_tree().quit()
