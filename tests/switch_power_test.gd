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
##   ветка 1: выбранная ветка соединила две цепи. D1 (ATTN_10): питает клип с меньшим номером (контур 1), клип D НЕ снимается
##   и помечается conflict = "label" (в Output строка «клип D: на месте, conflict=label»). Раньше клип-агрессор снимался

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


## Диагностика стыков (если цепь не дошла до стрелки): соседи, ближайшие сокеты, живость, изостыки, группа
func diag(f: Entity, sw: Entity, s: Entity, d: Entity) -> void:
	var names := {f: "F", sw: "SW", s: "S", d: "D"}
	for e: Entity in [f, sw, s, d]:
		var sock := e.get_comp(C_Socket) as C_Socket
		var nb: PackedStringArray = []
		for n in sock.get_connected_entities():
			nb.append(names.get(n, str(n.name)))
		var el: PackedStringArray = []
		for n in sock.get_electric_neighbors():
			el.append(names.get(n, str(n.name)))
		var live: PackedStringArray = []
		for i in sock.sockets.size():
			live.append("%d:%s%s" % [i, "жив" if sock.is_socket_live(i) else "МЕРТВ", "+изостык" if sock.is_gap(i) else ""])
		var hh := (e.get_comp(C_Path) as C_Path).head_height()
		print("  диаг %s: головка=%.2f, в группе=%s, соседи=%s, электр=%s, сокеты %s" % [names[e], hh, e.is_in_group("power_track"), nb, el, ", ".join(live)])
	for pair in [[f, sw], [sw, s], [sw, d]]:
		var j := RailNetBuilder.find_joint(pair[0], pair[1])
		print("  диаг стык %s-%s: %s" % [names[pair[0]], names[pair[1]], j])


func scenario(title: String, clip_on_d: bool) -> void:
	for c in get_children():
		c.free()
	PGM.reset_state()   # клипы освобождены без on_removed: убрать их и старые напряжения
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
	diag(f, sw, s, d)
	state("ветка 0", ents)
	swc.request(1, &"force")
	for i in 8:
		await get_tree().physics_frame
	state("ветка 1", ents)
	if clip_on_d:
		var cd := d.get_comp(C_PowerClip) as C_PowerClip
		if cd == null:
			print("  клип D: СНЯТ (ошибка: с D1 клипы не снимаются)")
		else:
			print("  клип D: на месте, conflict=%s" % ("нет" if cd.conflict == "" else cd.conflict))
	swc.request(0, &"force")
	for i in 8:
		await get_tree().physics_frame
	state("обратно на ветку 0", ents)


func _ready() -> void:
	flex_s = load("res://data/tracks/objects/flex_01.tres")
	# У flex_01 стиль без балласта (головка 0.45), у стрелки по умолчанию (0.85): ступенька между ними не проводит ток
	# (ATTN_15 §2.10, C_Socket.get_electric_neighbors). Для теста flex получает стиль по умолчанию, как у стрелки (в памяти, ресурс не сохраняется)
	for comp in flex_s.components:
		if comp is FlexVisualSetting:
			comp.style = TrackStyle.new()
	sw_s = load("res://data/tracks/objects/switch_r.tres")
	await scenario("Сценарий 1: ток только на выбранную ветку", false)
	await scenario("Сценарий 2: на ответвлении свой клип", true)
	print("готово")
	get_tree().quit()
