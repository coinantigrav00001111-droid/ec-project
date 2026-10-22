extends Node

# XX claude-switch (новый файл)
## Тест упора: вагон едет в упор на разных скоростях.
## Запуск: открыть tests/buffer_stop_test.tscn и нажать F6. Результат смотреть в Output.
## Раскладка: упор в начале координат (стена на z = -5.95, открытый стык на z = +5.95),
## подводящие flex-треки от него в сторону +Z, вагон едет в -Z.
## Скорость держим постоянной, пока торец не подойдет к стене ближе 4 ю, дальше вагон едет сам.
## Ожидается:
##   v = 1.0  вагон остановился у стены (зазор около 0, скорость около 0), остался на рельсах
##   v = 1.5  то же, отскок чуть заметнее
##   v = 3.0  сход (reason buffer_stop_impact): dv = (1 + 0.44) * 3.0 = 4.3 больше impact_dv_limit = 3.0

const HALF := 5.95    # половина длины упора (L = 11.9)

var flex_s: EntitySetting
var wagon_s: EntitySetting
var stop_s: EntitySetting


func place(e: Entity, pos: Vector3) -> void:
	add_child(e)
	e.global_position = pos


func run(speed: float) -> void:
	for c in get_children():
		c.free()
	await get_tree().physics_frame

	var stop: Entity = EntityFactory.new().create_from_setting(stop_s)
	place(stop, Vector3.ZERO)
	var feeders: Array[Entity] = []
	for i in 3:
		var f: Entity = EntityFactory.new().create_from_setting(flex_s)
		place(f, Vector3(0, 0, HALF + 10.0 * (i + 1)))
		feeders.append(f)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var w: Entity = EntityFactory.new().create_from_setting(wagon_s)
	add_child(w)
	w.global_position = feeders[0].global_position
	var ch := w.get_comp(C_Chassis) as C_Chassis
	var cp := w.get_comp(C_Coupler) as C_Coupler
	ch.on_train_snapped({"track": feeders[0], "offset": 4.0})
	await get_tree().physics_frame
	await get_tree().physics_frame

	var min_gap := INF
	var derailed := false
	for f in 1500:
		var front_z := w.global_position.z - cp.offset_z    # торец носом в -Z
		var gap := front_z - (-HALF)
		min_gap = minf(min_gap, gap)
		if gap > 4.0:
			ch.current_speed = speed
		await get_tree().physics_frame
		if not ch.is_on_rails:
			derailed = true
			break
	var front_z_end := w.global_position.z - cp.offset_z
	print("v=%.1f: сход=%s, мин. зазор=%.2f, конечный зазор=%.2f, скорость=%.2f" % [
			speed, derailed, min_gap, front_z_end + HALF, ch.current_speed])


func _ready() -> void:
	flex_s = load("res://data/tracks/objects/flex_01.tres")
	wagon_s = load("res://data/trains/objects/wagon_01.tres")
	stop_s = load("res://data/tracks/objects/buffer_stop.tres")
	for v in [1.0, 1.5, 3.0]:
		await run(v)
	print("готово")
	get_tree().quit()
