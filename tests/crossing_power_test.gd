extends Node

# XX claude-switch (новый файл)
## Тест раздельной электрики кросса (CrossingConfig.separate_circuits).
## Запуск: открыть tests/crossing_power_test.tscn и нажать F6. Результат смотреть в Output.
## Раскладка: кросс в начале координат, к каждому из 4 концов примыкает flex-трак 10 ю.
## Клип контура 1 на подводе пути A, клип контура 2 на подводе пути B.
## Ожидается (separate_circuits = true):
##   A0 и A1: контур 1, B0 и B1: контур 2
##   кросс: луч 0 = 1, луч 1 = 2 (в инфопанели "1 | 2"), полярность обоих лучей false
## Для separate_circuits = false (один проводник) контуры сольются: PGM напишет "Столкновение контуров",
## клип-агрессор снимется, при следующем пересчете сеть станет одним контуром.

var flex_s: EntitySetting
var cross_s: EntitySetting


func piece(pos: Vector3, fwd: Vector3) -> Entity:
	var e: Entity = EntityFactory.new().create_from_setting(flex_s)
	add_child(e)
	e.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), pos)
	return e


func show_state(label: String, e: Entity) -> void:
	var pt := e.get_comp(C_PowerTrack) as C_PowerTrack
	print("  %s: контур %s, полярность %s" % [label, pt.contour_text(), pt.flip_text()])


func _ready() -> void:
	flex_s = load("res://data/tracks/objects/flex_01.tres")
	cross_s = load("res://data/tracks/objects/crossing.tres")

	var cross: Entity = EntityFactory.new().create_from_setting(cross_s)
	add_child(cross)
	cross.global_position = Vector3.ZERO
	await get_tree().physics_frame
	var path := cross.get_comp(C_Path) as C_Path
	var pt := cross.get_comp(C_PowerTrack) as C_PowerTrack
	print("лучей у кросса: ", pt.legs, " (ожидается 2)")

	var feeders := {}
	for r in 2:
		var c: Curve3D = path.routes[r]
		var p0 := path.path_node.to_global(c.sample_baked(0.0))
		var p1 := path.path_node.to_global(c.sample_baked(c.get_baked_length()))
		var d := (p1 - p0).normalized()
		var letter := "A" if r == 0 else "B"
		feeders[letter + "0"] = piece(p0 - d * 10.0, d)   # заканчивается в начале пути
		feeders[letter + "1"] = piece(p1, d)              # начинается в конце пути
	await get_tree().physics_frame
	await get_tree().physics_frame

	PGM.create_power_clip(feeders["A0"], 1, true)
	PGM.create_power_clip(feeders["B0"], 2, true)
	PGM.set_power_pwm(1, 50)
	PGM.set_power_pwm(2, 30)
	for i in 6:
		await get_tree().physics_frame
	PGM.recalculate_grid()

	print("== после пересчета сети")
	for k in ["A0", "A1", "B0", "B1"]:
		show_state(k, feeders[k])
	show_state("Кросс", cross)
	print("напряжение кросса по лучам: ", pt.voltage_text(), " (ожидается 50 | 30)")
	print("готово")
	get_tree().quit()
