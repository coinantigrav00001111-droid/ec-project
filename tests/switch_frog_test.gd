extends Node

# XX claude-switch (новый файл)
## Тест E2 (крестовина и КЗ). Вагон едет через стрелку при контуре 1 под напряжением 50.
## Запуск: открыть tests/switch_frog_test.tscn и нажать F6. Результат смотреть в Output.
## Раскладка как в switch_drive_test: подвод F (клип контура 1), стрелка, выходы S (прямой) и D (ответвление).
## Ожидается (tripped = контур 1 отключен защитой):
##   Insulated, ветка 0                    tripped=false
##   Insulated, ветка 1                    tripped=false
##   Live fixed, ветка 0                   tripped=false  (крестовина привязана к пути 0)
##   Live fixed, ветка 1                   tripped=true   (КЗ при проезде зоны крестовины, в консоли "КЗ (frog)")
##   Live switched, ветка 1                tripped=false  (полярность крестовины переключилась вместе со стрелкой)
##   Live fixed + power_routing, ветка 1   tripped=false  (ток на крестовину идет через остряки)
## frog_s в первой строке: где крестовина вдоль каждого пути (прямой, ответвление), ю.

const TOE_Z := 11.95

var flex_s: EntitySetting
var wagon_s: EntitySetting
var sw_s: EntitySetting


func flex_at(pos: Vector3) -> Entity:
	var e: Entity = EntityFactory.new().create_from_setting(flex_s)
	add_child(e)
	e.global_position = pos
	return e


func clear_all() -> void:
	for c in get_children():
		var clip = c.get_comp(C_PowerClip) if c is Entity else null
		if clip:
			PGM.unregister_clip(clip)
		c.free()
	PGM.emergency_stop(false)
	await get_tree().physics_frame


func scenario(title: String, frog_mode: int, routing: bool, route: int) -> void:
	await clear_all()
	for comp in sw_s.components:
		if comp is SwitchSettings:
			comp.frog = frog_mode
			comp.power_routing = routing

	var sw: Entity = EntityFactory.new().create_from_setting(sw_s)
	add_child(sw)
	sw.global_position = Vector3.ZERO
	await get_tree().physics_frame
	var swc := sw.get_comp(C_Switch) as C_Switch
	swc.request(route, &"force")
	var path := sw.get_comp(C_Path) as C_Path
	var heel1 := path.path_node.to_global(path.routes[1].sample_baked(path.routes[1].get_baked_length()))

	var f: Array[Entity] = []
	for i in 3:
		f.append(flex_at(Vector3(0, 0, TOE_Z + 10.0 * (i + 1))))
	for i in 3:
		flex_at(Vector3(0, 0, -TOE_Z - 10.0 * i))
	for i in 3:
		flex_at(Vector3(heel1.x, 0, heel1.z - 10.0 * i))
	await get_tree().physics_frame
	await get_tree().physics_frame

	PGM.create_power_clip(f[0], 1, true)
	PGM.set_power_pwm(1, 50)
	for i in 6:
		await get_tree().physics_frame
	PGM.recalculate_grid()
	await get_tree().physics_frame

	var w: Entity = EntityFactory.new().create_from_setting(wagon_s)
	add_child(w)
	w.global_position = f[0].global_position
	var ch := w.get_comp(C_Chassis) as C_Chassis
	ch.on_train_snapped({"track": f[0], "offset": 3.0})
	await get_tree().physics_frame
	await get_tree().physics_frame
	for i in 600:
		ch.current_speed = 8.0
		await get_tree().physics_frame
		if PGM.power_pwm[1]["is_stopped"] or not ch.is_on_rails:
			break

	print("%s: tripped=%s, сошел=%s, frog_s=%s" % [title, PGM.power_pwm[1]["is_stopped"], not ch.is_on_rails, swc.frog_s])


func _ready() -> void:
	flex_s = load("res://data/tracks/objects/flex_01.tres")
	wagon_s = load("res://data/trains/objects/wagon_01.tres")
	sw_s = load("res://data/tracks/objects/switch_r.tres")
	await scenario("Insulated, ветка 0", 0, false, 0)
	await scenario("Insulated, ветка 1", 0, false, 1)
	await scenario("Live fixed, ветка 0", 1, false, 0)
	await scenario("Live fixed, ветка 1", 1, false, 1)
	await scenario("Live switched, ветка 1", 2, false, 1)
	await scenario("Live fixed + power_routing, ветка 1", 1, true, 1)
	print("готово")
	get_tree().quit()
