extends Node

# D0/D1 (ATTN_10 §10.9): новый файл
## Тест ядра питания (PGM + RailNetBuilder) на настоящих flex-траках.
## Запуск: открыть tests/power_core_test.tscn и нажать F6. Результат в Output: строки PASS / FAIL и итог.
## Раскладка как в switch_power_test: flex_01 длиной 10 ю, цепочка вдоль -Z, каждый сценарий на чистой сцене.
## S1 цепочка из 5: клип на первом, все в цепи 1, полярность одинаковая
## S2 в цепочке убран средний трак: хвост без цепи
## S3 стык «лицом к лицу» (конец к концу): полярность второго трака развёрнута, в цепь входит
## S4 два клипа с одной цепью: оба на месте, конфликта нет (раньше второй клип снимался)
## S5 два клипа с разными цепями в одной связности: оба на месте, у второго conflict = "label"
## S6 клипы на концах цепочки с одной цепью: согласовано; «поменять полярность» у одного: КЗ, цепь отключена защитой
## S7 изостык между 2 и 3 траками: хвост без цепи, клип на хвосте даёт свою цепь; изостык переживает save/load
## S8 сброс сети (PGM.reset_state): напряжения 0, сигнал state_reset
## S10 D3, политика TRIP: два клипа с разными выводами в одной цепи отключают оба вывода (SHORT, причина "conflict"); MERGE так не делает
## S11 D2: клип с выводом 11 второго источника питается от него, метка в списке «Вывод 11»
## S9 P1 (исправлен в main отдельным коммитом): PGM крутит полосы материалов цепи по ключам кэша "<цепь>_<полярность>" и "<цепь>_<полярность>_<масштаб>_<swap>"

var _fails := 0
var flex_s: EntitySetting


func check(name: String, ok: bool, info := "") -> void:
	if ok:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name, "  ", info)


func piece(pos: Vector3, fwd: Vector3 = Vector3(0, 0, -1)) -> Entity:
	var e: Entity = EntityFactory.new().create_from_setting(flex_s)
	add_child(e)
	e.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), pos)
	return e


## Цепочка из n траков вдоль -Z от z = 0
func chain(n: int) -> Array[Entity]:
	var out: Array[Entity] = []
	for i in n:
		out.append(piece(Vector3(0, 0, -10.0 * i)))
	return out


func net(e: Entity) -> int:
	return (e.get_comp(C_PowerTrack) as C_PowerTrack).contour_of(0)


func flip(e: Entity) -> bool:
	return (e.get_comp(C_PowerTrack) as C_PowerTrack).flip_of(0)


func nets_text(ents: Array) -> String:
	var parts: PackedStringArray = []
	for e in ents:
		parts.append("%d%s" % [net(e), "'" if flip(e) else ""])
	return " ".join(parts)


## Чистая сцена и сеть
func fresh() -> void:
	for c in get_children():
		c.free()
	PGM.reset_state()
	await get_tree().physics_frame


## Дать физике увидеть стыки, затем пересчитать сеть сразу
func settle() -> void:
	for i in 6:
		await get_tree().physics_frame
	PGM.recalculate_grid()
	await get_tree().physics_frame


func _ready() -> void:
	flex_s = load("res://data/tracks/objects/flex_01.tres")

	# --- S1 ---
	await fresh()
	var c1 := chain(5)
	await settle()
	PGM.create_power_clip(c1[0], 1, true)
	await settle()
	check("S1 цепочка из 5: все в цепи 1", c1.all(func(e): return net(e) == 1), nets_text(c1))
	check("S1 цепочка из 5: полярность одинаковая", c1.all(func(e): return not flip(e)), nets_text(c1))
	check("S1 сводка: 5 траков и 1 фидер", PGM.net_info.has(1) and PGM.net_info[1].tracks == 5 and PGM.net_info[1].feeders == 1, str(PGM.net_info))

	# --- S2 ---
	await fresh()
	var c2 := chain(5)
	await settle()
	PGM.create_power_clip(c2[0], 1, true)
	c2[2].free()
	await settle()
	check("S2 убран средний: голова в цепи 1", net(c2[0]) == 1 and net(c2[1]) == 1)
	check("S2 убран средний: хвост без цепи", net(c2[3]) == 0 and net(c2[4]) == 0, nets_text([c2[0], c2[1], c2[3], c2[4]]))

	# --- S3 ---
	await fresh()
	var a3 := piece(Vector3(0, 0, 0))
	var b3 := piece(Vector3(0, 0, -20), Vector3(0, 0, 1))   # его конец стыкуется с концом первого
	await settle()
	PGM.create_power_clip(a3, 1, true)
	await settle()
	check("S3 лицом к лицу: второй в цепи 1", net(b3) == 1, str(net(b3)))
	check("S3 лицом к лицу: полярность второго развёрнута", flip(b3) and not flip(a3), "a=%s b=%s" % [flip(a3), flip(b3)])

	# --- S4 ---
	await fresh()
	var c4 := chain(3)
	await settle()
	var k4a := PGM.create_power_clip(c4[0], 1, true)
	var k4b := PGM.create_power_clip(c4[2], 1, true)
	await settle()
	check("S4 два клипа одной цепи: оба на месте", c4[0].get_comp(C_PowerClip) != null and c4[2].get_comp(C_PowerClip) != null)
	check("S4 два клипа одной цепи: конфликта нет", (c4[0].get_comp(C_PowerClip) as C_PowerClip).conflict == "" and (c4[2].get_comp(C_PowerClip) as C_PowerClip).conflict == "")
	check("S4 две точки подачи в сводке", PGM.net_info.has(1) and PGM.net_info[1].feeders == 2 and not PGM.net_info[1].short, str(PGM.net_info))
	check("S4 все траки в цепи 1", c4.all(func(e): return net(e) == 1), nets_text(c4) + " ids %d %d" % [k4a, k4b])

	# --- S5 ---
	await fresh()
	var c5 := chain(3)
	await settle()
	PGM.create_power_clip(c5[0], 1, true)
	PGM.create_power_clip(c5[2], 2, true)
	await settle()
	var k5a := c5[0].get_comp(C_PowerClip) as C_PowerClip
	var k5b := c5[2].get_comp(C_PowerClip) as C_PowerClip
	check("S5 разные цепи в одной связности: оба клипа на месте", k5a != null and k5b != null)
	if k5a and k5b:
		check("S5 лидер (меньший номер) без конфликта", k5a.conflict == "", k5a.conflict)
		check("S5 второй клип помечен conflict = label", k5b.conflict == "label", k5b.conflict)
	check("S5 цепь питает лидер (1)", c5.all(func(e): return net(e) == 1), nets_text(c5))

	# --- S6 ---
	await fresh()
	var c6 := chain(3)
	await settle()
	PGM.create_power_clip(c6[0], 1, true)
	PGM.create_power_clip(c6[2], 1, true)
	PGM.set_power_pwm(1, 50)
	await settle()
	check("S6 без разворота согласовано", not PGM.net_info[1].short and not PGM.shorted_nets.has(1) and not PGM.power_pwm[1]["is_stopped"], str(PGM.net_info))
	(c6[2].get_comp(C_PowerClip) as C_PowerClip).reversed = true   # провода второго клипа перепутаны
	await settle()
	check("S6 разворот одного клипа: КЗ", PGM.net_info[1].short and PGM.shorted_nets.has(1), str(PGM.net_info))
	check("S6 КЗ: цепь отключена защитой", PGM.power_pwm[1]["is_stopped"], str(PGM.power_pwm[1]))
	check("S6 КЗ: клип с неверной полярностью помечен polarity", (c6[2].get_comp(C_PowerClip) as C_PowerClip).conflict == "polarity", (c6[2].get_comp(C_PowerClip) as C_PowerClip).conflict)
	check("S6 КЗ: клип не снят", c6[2].get_comp(C_PowerClip) != null)
	(c6[2].get_comp(C_PowerClip) as C_PowerClip).reversed = false
	await settle()
	check("S6 разворот снят: КЗ ушло", not PGM.net_info[1].short and not PGM.shorted_nets.has(1), str(PGM.net_info))
	PGM.reset_contour(1)
	check("S6 после reset_contour цепь снова включена", not PGM.power_pwm[1]["is_stopped"])

	# --- S7 ---
	await fresh()
	var c7 := chain(4)
	await settle()
	PGM.create_power_clip(c7[0], 1, true)
	var j := RailNetBuilder.find_joint(c7[1], c7[2])
	var s7 := c7[1].get_comp(C_Socket) as C_Socket
	s7.set_gap(j.id1, true)
	await settle()
	check("S7 изостык: голова в цепи 1", net(c7[0]) == 1 and net(c7[1]) == 1, nets_text(c7))
	check("S7 изостык: хвост без цепи", net(c7[2]) == 0 and net(c7[3]) == 0, nets_text(c7))
	PGM.create_power_clip(c7[3], 2, true)
	await settle()
	check("S7 клип на хвосте даёт свою цепь 2", net(c7[2]) == 2 and net(c7[3]) == 2 and net(c7[1]) == 1, nets_text(c7))
	check("S7 клипы оба на месте и без конфликта", (c7[3].get_comp(C_PowerClip) as C_PowerClip).conflict == "" and c7[0].get_comp(C_PowerClip) != null)
	# сохранение и загрузка изостыка
	var saved: Dictionary = s7.save_data()
	s7.set_gap(j.id1, false)
	check("S7 изостык снят", not s7.is_gap(j.id1))
	s7.load_data(saved)
	check("S7 изостык вернулся из сейва", s7.is_gap(j.id1), str(saved))
	await settle()
	check("S7 после загрузки изостыка хвост снова отдельно", net(c7[2]) == 2 and net(c7[1]) == 1, nets_text(c7))
	# снятие изостыка склеивает цепь, лидер (меньший номер) питает все, клип 2 остается с conflict
	s7.set_gap(j.id1, false)
	await settle()
	check("S7 изостык снят: цепь склеилась в 1", c7.all(func(e): return net(e) == 1), nets_text(c7))
	check("S7 изостык снят: клип 2 остался с conflict = label", (c7[3].get_comp(C_PowerClip) as C_PowerClip).conflict == "label")
	check("S7 пустой Socket без изостыков не пишет сейв", (c7[0].get_comp(C_Socket) as C_Socket).save_data().is_empty())

	# --- S8 ---
	await fresh()
	PGM.set_power_pwm(3, 70)
	var got := [0]
	var on_reset := func(): got[0] += 1
	PGM.state_reset.connect(on_reset)
	PGM.reset_state()
	PGM.state_reset.disconnect(on_reset)
	check("S8 сброс: напряжение 0", PGM.power_pwm[3]["voltage"] == 0, str(PGM.power_pwm[3]))
	check("S8 сброс: защита снята", not PGM.power_pwm[3]["is_stopped"])
	check("S8 сброс: сигнал state_reset ушел", got[0] == 1, str(got[0]))

	# --- S9 (P1) ---
	var mats: Array[ShaderMaterial] = []
	var keys := ["7_false", "7_true_1.5_true", "8_false"]
	for key in keys:
		var m := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nuniform float scroll_speed = 0.0;\nvoid fragment() {}\n"
		m.shader = sh
		m.set_shader_parameter("scroll_speed", 0.0)
		C_TrackVisual.power_materials_cache[key] = m
		mats.append(m)
	PGM.set_power_pwm(7, 40)
	check("S9 P1: прямая полярность +0.4", is_equal_approx(float(mats[0].get_shader_parameter("scroll_speed")), 0.4), str(mats[0].get_shader_parameter("scroll_speed")))
	check("S9 P1: развёрнутая полярность -0.4", is_equal_approx(float(mats[1].get_shader_parameter("scroll_speed")), -0.4), str(mats[1].get_shader_parameter("scroll_speed")))
	check("S9 P1: чужая цепь не тронута", is_equal_approx(float(mats[2].get_shader_parameter("scroll_speed")), 0.0))
	for key in keys:
		C_TrackVisual.power_materials_cache.erase(key)

	# --- S10 ---
	await fresh()
	var c10 := chain(3)
	await settle()
	PGM.create_power_clip(c10[0], 1, true)
	PGM.create_power_clip(c10[2], 2, true)
	PGM.set_command(1, 50)
	PGM.set_command(2, 40)
	await settle()
	check("S10 MERGE: конфликт помечен, но выводы работают", (c10[2].get_comp(C_PowerClip) as C_PowerClip).conflict == "label" and not PGM.get_output(1).tripped and not PGM.get_output(2).tripped)
	check("S10 MERGE: клип знает лидера", (c10[2].get_comp(C_PowerClip) as C_PowerClip).conflict_with == 1)
	PGM.conflict_policy = PGM.ConflictPolicy.TRIP
	PGM.recalculate_grid()
	check("S10 TRIP: оба вывода отключены", PGM.get_output(1).tripped and PGM.get_output(2).tripped, "%s %s" % [PGM.get_output(1).tripped, PGM.get_output(2).tripped])
	check("S10 TRIP: состояние SHORT, причина conflict", PGM.get_output(1).state == PowerOutput.State.SHORT and PGM.get_output(2).trip_reason == "conflict")
	check("S10 TRIP: напряжение 0", PGM.get_power(1) == 0.0 and PGM.get_power(2) == 0.0)
	PGM.conflict_policy = PGM.ConflictPolicy.MERGE
	PGM.recalculate_grid()
	PGM.reset_protection()
	check("S10 после MERGE и сброса питание вернулось", PGM.get_power(1) == 50.0 and PGM.get_power(2) == 40.0)

	# --- S11 ---
	await fresh()
	var panel2 := Node.new()
	var src2 := PGM.register_source(PowerModels.MULTI, panel2)
	var src3 := PGM.register_source(PowerModels.MULTI, self)
	var c11 := chain(2)
	await settle()
	PGM.create_power_clip(c11[0], 11, true)
	PGM.set_command(11, 60)
	await settle()
	check("S11 цепь 11 питает оба трака", net(c11[0]) == 11 and net(c11[1]) == 11, nets_text(c11))
	check("S11 напряжение цепи 11", PGM.get_power(11) == 60.0)
	check("S11 подпись вывода", PGM.label_text(11) == "Вывод 11", PGM.label_text(11))
	check("S11 первый свободный вывод это 1, не 11", PGM.get_free_contour_id() == 1, str(PGM.get_free_contour_id()))
	PGM.unregister_source(src2)
	PGM.unregister_source(src3)
	panel2.free()
	await fresh()
	print("--------")
	print("power_core_test: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit()
