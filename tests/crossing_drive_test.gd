extends Node

# XX claude-switch (новый файл)
## Интеграционный тест кросса: вагон едет по пути A и пути B, в обе стороны.
## Запуск: открыть tests/crossing_drive_test.tscn и нажать F6. Результат смотреть в Output.
## Раскладка: кросс в начале координат. К каждому из 4 концов примыкает по 2 flex-трака по 10 ю.
## Название трака: A0/B0 = подвод к началу пути, A1/B1 = к концу; цифра после буквы: 0 ближний к кроссу, 1 дальний.
## X/0 и X/1 в выводе: вагон на кроссе по пути 0 или 1 (route тележки). Ожидается:
##   1) A: A0_0 > A0_1 ... > X/0 > A1_0 > A1_1       (путь A насквозь, route 0)
##   2) B: B0_0 > B0_1 ... > X/1 > B1_0 > B1_1       (путь B насквозь, route 1)
##   3) A назад: A1_x > X/0 > A0_x
##   4) B назад: B1_x > X/1 > B0_x
## Вагон ни разу не сходит. Электрика (общий контур) в тесте не проверяется.

const L := 23.9

var flex_s: EntitySetting
var wagon_s: EntitySetting
var cross_s: EntitySetting


func piece(pos: Vector3, fwd: Vector3) -> Entity:
	var e: Entity = EntityFactory.new().create_from_setting(flex_s)
	add_child(e)
	e.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), pos)
	return e


func run(title: String, leg: int, reverse: bool) -> void:
	for c in get_children():
		c.free()
	await get_tree().physics_frame
	print("== ", title)

	var cross: Entity = EntityFactory.new().create_from_setting(cross_s)
	add_child(cross)
	cross.global_position = Vector3.ZERO
	await get_tree().physics_frame
	var path := cross.get_comp(C_Path) as C_Path

	var names := {cross: "X"}
	var legs := []   # для каждого пути: [точка начала (мир), точка конца (мир), направление (мир)]
	for r in 2:
		var c: Curve3D = path.routes[r]
		var l := c.get_baked_length()
		var p0 := path.path_node.to_global(c.sample_baked(0.0))
		var p1 := path.path_node.to_global(c.sample_baked(l))
		legs.append([p0, p1, (p1 - p0).normalized()])

	var tracks := {}   # "A0_0", ... -> Entity
	var letters := ["A", "B"]
	for r in 2:
		var p0: Vector3 = legs[r][0]
		var p1: Vector3 = legs[r][1]
		var d: Vector3 = legs[r][2]
		for i in 2:
			# подвод к началу: по направлению пути он заканчивается в p0
			var ent0 := piece(p0 - d * (10.0 * (i + 1)), d)
			tracks["%s0_%d" % [letters[r], i]] = ent0
			# выход от конца: начинается в p1
			var ent1 := piece(p1 + d * (10.0 * i), d)
			tracks["%s1_%d" % [letters[r], i]] = ent1
	for k in tracks:
		names[tracks[k]] = k
	await get_tree().physics_frame
	await get_tree().physics_frame

	var start: Entity = tracks["%s%d_0" % [letters[leg], 1 if reverse else 0]]
	var w: Entity = EntityFactory.new().create_from_setting(wagon_s)
	add_child(w)
	w.global_transform = Transform3D(start.global_basis, start.global_position)
	var ch := w.get_comp(C_Chassis) as C_Chassis
	var bg := w.get_comp(C_Bogie) as C_Bogie
	ch.on_train_snapped({"track": start, "offset": 3.0})
	await get_tree().physics_frame
	await get_tree().physics_frame

	var speed := -8.0 if reverse else 8.0
	var seq: Array = []
	var derailed := false
	for f in 700:
		ch.current_speed = speed
		await get_tree().physics_frame
		if bg.is_derailed or not ch.is_on_rails:
			derailed = true
			break
		var b: C_Bogie.BogieData = bg.bogies_data.front()
		var nm: String = names.get(b.current_track, "?")
		if b.current_track == cross:
			nm = "X/%d" % b.route
		if seq.is_empty() or seq.back() != nm:
			seq.append(nm)
	print("  путь передней тележки: ", seq, " сход=", derailed)


func _ready() -> void:
	flex_s = load("res://data/tracks/objects/flex_01.tres")
	wagon_s = load("res://data/trains/objects/wagon_01.tres")
	cross_s = load("res://data/tracks/objects/crossing.tres")
	await run("Путь A вперед", 0, false)
	await run("Путь B вперед", 1, false)
	await run("Путь A назад", 0, true)
	await run("Путь B назад", 1, true)
	print("готово")
	get_tree().quit()
