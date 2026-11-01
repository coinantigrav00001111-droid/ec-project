extends Node

# D0 (ATTN_10 §10.9): новый файл
## Замер пересчета сети питания на цепочке из N flex-траков с одним клипом.
## Запуск: открыть tests/power_bench.tscn и нажать F6. Результат в Output (числа нужны для бюджета в ATTN_10 §10.5.1).
## Печатает: число траков, время первого и повторного PGM.recalculate_grid, время PGM.request_recalculate до первого await,
## время создания цепочки. Менять размер: COUNT.

const COUNT := 500

var flex_s: EntitySetting


func _ready() -> void:
	flex_s = load("res://data/tracks/objects/flex_01.tres")
	var t0 := Time.get_ticks_usec()
	var ents: Array[Entity] = []
	for i in COUNT:
		var e: Entity = EntityFactory.new().create_from_setting(flex_s)
		add_child(e)
		e.global_transform = Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), Vector3(0, 0, -10.0 * i))
		ents.append(e)
	var t_build := Time.get_ticks_usec() - t0
	for i in 12:
		await get_tree().physics_frame

	PGM.create_power_clip(ents[0], 1, true)
	PGM.set_power_pwm(1, 50)
	for i in 6:
		await get_tree().physics_frame

	# первый расчет: все траки новые, вид обновляется у всех
	var t1 := Time.get_ticks_usec()
	PGM.recalculate_grid()
	var t_first := Time.get_ticks_usec() - t1
	# повторный: ничего не изменилось
	var t2 := Time.get_ticks_usec()
	PGM.recalculate_grid()
	var t_again := Time.get_ticks_usec() - t2
	# вызов запроса пересчета до первого await (то, что видит вызывающий код в своем кадре)
	var t3 := Time.get_ticks_usec()
	PGM.request_recalculate()
	var t_request := Time.get_ticks_usec() - t3

	var in_net := 0
	for e in ents:
		if (e.get_comp(C_PowerTrack) as C_PowerTrack).contour_of(0) == 1:
			in_net += 1
	print("power_bench: траков %d, в цепи 1: %d (ожидается все)" % [COUNT, in_net])
	print("  создание цепочки: %.1f мс" % (t_build / 1000.0))
	print("  recalculate_grid, первый: %.2f мс (внутри builder+визуал: last_recalc_usec = %d мкс)" % [t_first / 1000.0, PGM.last_recalc_usec])
	print("  recalculate_grid, повторный: %.2f мс" % (t_again / 1000.0))
	print("  request_recalculate до первого await: %.3f мс" % (t_request / 1000.0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	get_tree().quit()
