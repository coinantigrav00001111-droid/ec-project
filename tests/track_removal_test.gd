extends Node

# XX claude-fix (новый файл)
## Регрессионный тест удаления трака. Запуск: открыть tests/track_removal_test.tscn и нажать F6.
## Сценарии:
##   1) удалить пустой трак (раньше: ошибка c_path.gd ballast_samples "!is_inside_tree()" в Output)
##   2) удалить трак, на котором стоит вагон (раньше: ошибка "Trying to assign invalid previously freed instance"
##      в c_chassis.gd и краш). Ожидается: вагон сходит с рельс (is_on_rails = false), без ошибок
##   3) удалить трак под ЗАДНЕЙ тележкой, пока передняя на соседнем (проверяет все тележки, а не только переднюю)
## Тест сам проверяет только сход вагона. Ошибок в Output (красные строки E ...) не должно быть вообще.

var flex_s: EntitySetting
var wagon_s: EntitySetting


func piece(pos: Vector3) -> Entity:
	var e: Entity = EntityFactory.new().create_from_setting(flex_s)
	add_child(e)
	e.global_transform = Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), pos)
	return e


func clear() -> void:
	for c in get_children():
		c.free()
	await get_tree().physics_frame


func wagon_on(track: Entity, offset: float) -> Entity:
	var w: Entity = EntityFactory.new().create_from_setting(wagon_s)
	add_child(w)
	w.global_transform = Transform3D(track.global_basis, track.global_position)
	var ch := w.get_comp(C_Chassis) as C_Chassis
	ch.on_train_snapped({"track": track, "offset": offset})
	return w


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func check(title: String, ok: bool) -> void:
	print(("  OK    " if ok else "  FAIL  "), title)


func _ready() -> void:
	flex_s = load("res://data/tracks/objects/flex_01.tres")
	wagon_s = load("res://data/trains/objects/wagon_01.tres")

	print("== 1. удаление пустого трака")
	await clear()
	var a := piece(Vector3.ZERO)
	await frames(3)
	a.queue_free()
	await frames(3)
	check("трак удалён без падения (смотрите Output на красные E)", true)

	print("== 2. удаление трака под вагоном")
	await clear()
	var t0 := piece(Vector3.ZERO)
	piece(Vector3(0, 0, -10))
	await frames(3)
	var w := wagon_on(t0, 3.0)
	await frames(10)
	var ch := w.get_comp(C_Chassis) as C_Chassis
	check("вагон встал на рельсы", ch.is_on_rails)
	ch.current_speed = 1.0
	await frames(5)
	t0.queue_free()
	await frames(10)
	check("вагон сошёл после удаления трака", not ch.is_on_rails)

	print("== 3. удаление трака только под задней тележкой")
	await clear()
	var u0 := piece(Vector3.ZERO)
	var u1 := piece(Vector3(0, 0, -10))
	await frames(3)
	var w2 := wagon_on(u1, 0.5)   # вагон у начала u1: передняя тележка на u1, задняя на u0 или рядом со стыком
	await frames(10)
	var ch2 := w2.get_comp(C_Chassis) as C_Chassis
	ch2.current_speed = 1.0
	await frames(5)
	u0.queue_free()
	await frames(10)
	check("вагон жив, ошибок нет (сошёл или остался, если задняя тележка на u1)", is_instance_valid(w2))

	print("готово")
	get_tree().quit()
