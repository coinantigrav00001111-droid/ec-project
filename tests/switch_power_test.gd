extends Node

# XX claude-switch (новый файл)
## Тест E1 (power routing стрелки): ток идет только на выбранную ветку.
## Запуск: открыть tests/switch_power_test.tscn и нажать F6. Результат смотреть в Output.
## Раскладка: стрелка (правая) в начале координат, подвод F к носку, выходы S (прямой) и D (ответвление), по одному flex-траку.
## Клип контура 1 на подводе F. Стрелка с power_routing = true.
## Сценарий 1 (клипа на D нет). Ожидается:
##   ветка 0: F=1, SW=1, S=1, D=0         ветка 1: F=1, SW=1, S=0, D=1
## Сценарий 2 (на D свой клип контура 2). Ожидается:
##   ветка 0: S=1, D=2 (тупик питается сам, стрелка его не трогает)
##   ветка 1: в консоли "Столкновение контуров: 1 и 2" (выбранная ветка соединила две цепи), клип-агрессор снимается

const TOE_Z := 11.95

var flex_s: EntitySetting
var sw_s: EntitySetting


func piece(pos: Vector3, fwd: Vector3 = Vector3(0, 0, -1)) -> Entity:
	var e: Entity = EntityFactory.new().create_from_setting(flex_s)
	add_child(e)
	e.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), pos)
	return e


func state(label: String, ents: Dictionary) -> void:
	var parts: PackedStringArray = []
	for k in ents:
		parts.append("%s=%s" % [k, (ents[k].get_comp(C_PowerTrack) as C_PowerTrack).contour_text()])
	print("  %s: %s" % [label, ", ".join(parts)])


func scenario(title: String, clip_on_d: bool) -> void:
	for c in get_children():
		c.free()
	await get_tree().physics_frame
	print("== ", title)

	for comp in sw_s.components:
		if comp is IdentitySetting:   # режимы стрелки живут в паспорте (SwitchConfig), в компонент попадают при создании
			(comp.object_config as SwitchConfig).power_routing = true
	var sw: Entity = EntityFactory.new().create_from_setting(sw_s)
	add_child(sw)
	sw.global_position = Vector3.ZERO
	await get_tree().physics_frame
	var swc := sw.get_comp(C_Switch) as C_Switch
	var path := sw.get_comp(C_Path) as C_Path
	var heel1 := path.path_node.to_global(path.routes[1].sample_baked(path.routes[1].get_baked_length()))

	var f := piece(Vector3(0, 0, TOE_Z + 10.0))
	var s := piece(Vector3(0, 0, -TOE_Z))
	var d := piece(Vector3(heel1.x, 0, heel1.z))
	await get_tree().physics_frame
	await get_tree().physics_frame

	PGM.create_power_clip(f, 1, true)
	if clip_on_d:
		PGM.create_power_clip(d, 2, true)
	PGM.set_power_pwm(1, 50)
	PGM.set_power_pwm(2, 30)
	for i in 6:
		await get_tree().physics_frame
	PGM.recalculate_grid()
	await get_tree().physics_frame

	var ents := {"F": f, "SW": sw, "S": s, "D": d}
	state("ветка 0", ents)
	swc.request(1, &"force")
	for i in 8:
		await get_tree().physics_frame
	state("ветка 1", ents)
	swc.request(0, &"force")
	for i in 8:
		await get_tree().physics_frame
	state("обратно на ветку 0", ents)


func _ready() -> void:
	flex_s = load("res://data/tracks/objects/flex_01.tres")
	sw_s = load("res://data/tracks/objects/switch_r.tres")
	await scenario("Сценарий 1: ток только на выбранную ветку", false)
	await scenario("Сценарий 2: на ответвлении свой клип", true)
	print("готово")
	get_tree().quit()
