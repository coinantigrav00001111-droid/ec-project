extends Node

# XX claude-switch (новый файл)
## Диагностика сохранения положения стрелки. Идет по тому же пути, что SaveManager:
## Entity.save_entity -> ResourceSaver (SavedGame) -> ResourceLoader -> новая сущность -> load_data у компонентов.
## Запуск: открыть tests/switch_save_test.tscn и нажать F6. Результат смотреть в Output.
## Ожидается: во всех шагах route=1 и active_route=1.
## Шаг 5 моделирует гонку (load_data раньше on_entity_ready), ее закрывает флаг _loaded в C_Switch.
## Если какой-то шаг показывает route=0, пришлите вывод: по первому такому шагу видно, где теряется положение.

const SAVE_PATH := "user://switch_save_test.tres"


func report(label: String, e: Entity) -> void:
	var sw := e.get_comp(C_Switch) as C_Switch
	var path := e.get_comp(C_Path) as C_Path
	print("  %s: route=%d, active_route=%d, curve==routes[1]: %s" % [
			label, sw.route, path.active_route, path.curve == path.routes[1]])


## Как SaveManager.load_game: создать, поставить, добавить в дерево, накатить данные компонентов
func spawn(d: Dictionary, switch_before_add: bool) -> Entity:
	var setting := load(d["setting_path"]) as EntitySetting
	var e: Entity = EntityFactory.new().create_from_setting(setting)
	e.global_transform = d["transform"]
	var comps: Dictionary = d["components"]
	if switch_before_add:
		# гонка: данные стрелки приходят до того, как сущность "готова" (on_entity_ready еще не было)
		var c := e.get_comp(C_Switch)
		c.load_data(comps[C_Switch])
		add_child(e)
	else:
		add_child(e)
		for comp_type in comps.keys():
			var cur = e.get_comp(comp_type)
			if cur and cur.has_method("load_data"):
				cur.load_data(comps[comp_type])
	return e


func _ready() -> void:
	var s := load("res://data/tracks/objects/switch_r.tres") as EntitySetting
	var e: Entity = EntityFactory.new().create_from_setting(s)
	add_child(e)
	await get_tree().physics_frame
	var sw := e.get_comp(C_Switch) as C_Switch

	print("== 1. переключили на ветку 1")
	print("  request: ", sw.request(1, &"force"))
	report("после переключения", e)

	print("== 2. Entity.save_entity")
	var d := e.save_entity()
	print("  в сейве компонентов: ", d.get("components", {}).size(), ", C_Switch есть: ", d.get("components", {}).has(C_Switch))
	if d.get("components", {}).has(C_Switch):
		print("  данные C_Switch: ", d["components"][C_Switch])

	print("== 3. ResourceSaver и обратно с диска")
	var sg := SavedGame.new()
	sg.entities.append(d)
	print("  save err: ", ResourceSaver.save(sg, SAVE_PATH), " (0 = OK)")
	var back := ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SavedGame
	var d2: Dictionary = back.entities[0]
	var has := false
	for k in d2["components"].keys():
		if k == C_Switch:
			has = true
			print("  данные C_Switch с диска: ", d2["components"][k])
	print("  C_Switch в загруженном сейве: ", has)

	print("== 4. загрузка как SaveManager (данные после add_child)")
	var e2 := spawn(d2, false)
	await get_tree().physics_frame
	report("новая сущность", e2)

	print("== 5. гонка: данные стрелки до on_entity_ready")
	var e3 := spawn(d2, true)
	await get_tree().physics_frame
	report("новая сущность", e3)

	print("готово")
	get_tree().quit()
