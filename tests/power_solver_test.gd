extends Node

# D2/D3 (ATTN_10 §10.9): новый файл
## Тест источников, решателя нагрузки и защиты. Без сцены и траков: порты-пустышки.
## Запуск: открыть tests/power_solver_test.tscn и нажать F6. Результат в Output: строки PASS / FAIL и итог.
## T1  напряжение вывода: команда, стоп, защита, сеть (источник с needs_supply и без)
## T2  перегрузка 1.3 А при лимите 1 А: OVERLOAD, через 0.5 с TRIPPED
## T3  ток выше 2 · лимита отключает сразу
## T4  ток в норме не отключает; два порта в одной цепи складываются
## T5  источник без защиты (starter): состояние OVERLOAD, но не TRIPPED
## T6  КЗ: trip("polarity") даёт SHORT, reset возвращает OK
## T7  нагрузка сети: Вт и признак перегрузки
## T8  порт с освобождённым владельцем убирается
## P1  PGM: источник по умолчанию, метки 1–10, set_command, память выводов, «все выводы»
## P2  аварийный стоп источника и защита раздельны (Q8)
## P3  register_source: свободный источник забирается, второй создаётся с метками 11–20, отпущенный возвращается
## P4  кнопка «Сеть»: multi мертв без сети, starter нет
## P5  PGM + порт: перегрузка отключает вывод, сигнал contour_tripped, сброс, повторное срабатывание
## P6  save_state и load_state: команды, estop, защита, второй источник; пустой словарь (старый сейв) даёт нули

var _fails := 0


func check(name: String, ok: bool, info := "") -> void:
	if ok:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name, "  ", info)


func make_source(model: StringName = PowerModels.MULTI, label := 1) -> PowerSource:
	var md := PowerModels.get_model(model)
	var s := PowerSource.new()
	s.model = model
	var o := PowerOutput.new()
	o.label = label
	o.v_max = float(md.v_max)
	o.i_max = float(md.i_max)
	s.outputs.append(o)
	return s


func make_port(net: int, volts: float, amps: float, owner: Object = null) -> PowerPort:
	var p := PowerPort.new()
	p.kind = PowerPort.Kind.MOTOR
	p.net = net
	p.voltage = volts
	p.load_current = amps
	p.owner = owner
	return p


func steps(solver: PowerSolver, src: PowerSource, ports: Array, mains: PowerSupply, n: int, dt := 0.1) -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	for i in n:
		all.append_array(solver.step([src], ports, mains, dt))
	return all


func has_event(events: Array[Dictionary], kind: String) -> bool:
	for e in events:
		if e.kind == kind:
			return true
	return false


func _ready() -> void:
	var solver := PowerSolver.new()
	var mains := PowerSupply.new()

	# --- T1 ---
	var s1 := make_source()
	var o1 := s1.outputs[0]
	o1.command = 50
	check("T1 команда 50 даёт 50", PowerSolver.voltage_of(s1, o1, mains) == 50.0)
	o1.command = -80
	check("T1 отрицательная команда", PowerSolver.voltage_of(s1, o1, mains) == -80.0)
	o1.command = 50
	s1.estop = true
	check("T1 аварийный стоп: 0", PowerSolver.voltage_of(s1, o1, mains) == 0.0)
	s1.estop = false
	PowerSolver.trip(o1, "overload")
	check("T1 защита: 0", PowerSolver.voltage_of(s1, o1, mains) == 0.0)
	PowerSolver.reset(o1)
	mains.on = false
	check("T1 нет сети: multi мертв", PowerSolver.voltage_of(s1, o1, mains) == 0.0)
	var st := make_source(&"starter")
	st.outputs[0].command = 40
	check("T1 нет сети: starter жив", PowerSolver.voltage_of(st, st.outputs[0], mains) == 40.0)
	mains.on = true

	# --- T2 ---
	var s2 := make_source()
	var o2 := s2.outputs[0]
	o2.command = 60
	var ports2: Array = [make_port(1, 60.0, 1.3)]
	var ev2 := steps(solver, s2, ports2, mains, 3)
	check("T2 0.3 с: перегрузка, ещё не отключен", o2.state == PowerOutput.State.OVERLOAD and not o2.tripped, str(o2.state))
	check("T2 ток вывода 1.3 А", is_equal_approx(o2.current, 1.3), str(o2.current))
	ev2.append_array(steps(solver, s2, ports2, mains, 3))
	check("T2 0.6 с: вывод отключен", o2.tripped and o2.trip_reason == "overload", "tripped=%s" % o2.tripped)
	check("T2 событие trip", has_event(ev2, "trip"))
	check("T2 напряжение 0 после отключения", PowerSolver.voltage_of(s2, o2, mains) == 0.0)

	# --- T3 ---
	var s3 := make_source()
	var ports3: Array = [make_port(1, 60.0, 2.5)]
	s3.outputs[0].command = 60
	steps(solver, s3, ports3, mains, 1)
	check("T3 2.5 А при лимите 1 А: отключен сразу", s3.outputs[0].tripped)

	# --- T4 ---
	var s4 := make_source()
	s4.outputs[0].command = 60
	var ports4: Array = [make_port(1, 60.0, 0.9)]
	steps(solver, s4, ports4, mains, 10)
	check("T4 0.9 А: норма", s4.outputs[0].state == PowerOutput.State.OK and not s4.outputs[0].tripped)
	ports4.append(make_port(1, 60.0, 0.6))
	steps(solver, s4, ports4, mains, 3)
	check("T4 два порта в одной цепи: 1.5 А, перегрузка", is_equal_approx(s4.outputs[0].current, 1.5) and s4.outputs[0].state == PowerOutput.State.OVERLOAD, str(s4.outputs[0].current))
	ports4[0].net = 2
	steps(solver, s4, ports4, mains, 1)
	check("T4 порт в другой цепи не считается", is_equal_approx(s4.outputs[0].current, 0.6), str(s4.outputs[0].current))

	# --- T5 ---
	var s5 := make_source(&"starter")
	s5.outputs[0].command = 100
	var ports5: Array = [make_port(1, 100.0, 3.0)]
	steps(solver, s5, ports5, mains, 20)
	check("T5 starter без защиты: перегрузка, но не отключен", s5.outputs[0].state == PowerOutput.State.OVERLOAD and not s5.outputs[0].tripped, str(s5.outputs[0].state))

	# --- T6 ---
	var o6 := PowerOutput.new()
	PowerSolver.trip(o6, "polarity")
	check("T6 КЗ полярности: SHORT", o6.tripped and o6.state == PowerOutput.State.SHORT)
	PowerSolver.reset(o6)
	check("T6 сброс: OK", not o6.tripped and o6.state == PowerOutput.State.OK and o6.trip_reason == "")
	PowerSolver.trip(o6, "conflict")
	check("T6 конфликт выводов: SHORT", o6.state == PowerOutput.State.SHORT)

	# --- T7 ---
	var s7 := make_source()
	s7.outputs[0].command = 100
	var m7 := PowerSupply.new()
	m7.capacity_w = 60.0
	steps(solver, s7, [make_port(1, 100.0, 1.0)], m7, 1)
	check("T7 100 % · 1 А = 12 Вт", is_equal_approx(m7.load_w, 12.0), str(m7.load_w))
	check("T7 запас по мощности: перегрузки сети нет", not m7.overloaded)
	m7.capacity_w = 10.0
	steps(solver, s7, [make_port(1, 100.0, 1.0)], m7, 1)
	check("T7 лимит 10 Вт: сеть перегружена", m7.overloaded)

	# --- T8 ---
	var s8 := make_source()
	s8.outputs[0].command = 50
	var dead := Node.new()
	var ports8: Array = [make_port(1, 50.0, 0.5, dead)]
	dead.free()
	steps(solver, s8, ports8, mains, 1)
	check("T8 порт освобожденного владельца убран", ports8.is_empty())

	# --- P1 ---
	PGM.reset_state()
	check("P1 есть источник по умолчанию", PGM.sources.size() == 1)
	check("P1 метки 1–10", PGM.all_labels() == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], str(PGM.all_labels()))
	PGM.set_command(1, 50)
	PGM.set_command(2, 30)
	check("P1 память: вывод 1 = 50, вывод 2 = 30", PGM.get_power(1) == 50.0 and PGM.get_power(2) == 30.0)
	check("P1 производное power_pwm совпадает", PGM.power_pwm[1]["voltage"] == 50 and PGM.power_pwm[2]["voltage"] == 30)
	PGM.set_command(-1, 20)
	check("P1 «все выводы» двигает все", PGM.get_power(1) == 20.0 and PGM.get_power(2) == 20.0 and PGM.get_power(10) == 20.0)
	PGM.set_power_pwm(3, -40)
	check("P1 оболочка set_power_pwm", PGM.get_power(3) == -40.0)
	PGM.set_command(1, 500)
	check("P1 команда обрезается по v_max", PGM.get_power(1) == 100.0)

	# --- P2 ---
	PGM.reset_state()
	PGM.set_command(1, 50)
	PGM.emergency_stop(true)
	check("P2 стоп: напряжение 0", PGM.get_power(1) == 0.0 and PGM.power_pwm[1]["is_stopped"])
	check("P2 стоп: команда сохранена", PGM.get_output(1).command == 50)
	PGM.emergency_stop(false)
	check("P2 снятие стопа возвращает прежнее", PGM.get_power(1) == 50.0)
	PGM.trip_contour(1, "polarity")
	check("P2 защита: напряжение 0", PGM.get_power(1) == 0.0)
	PGM.emergency_stop(true)
	PGM.emergency_stop(false)
	check("P2 стоп и снятие стопа защиту не сбрасывают", PGM.get_output(1).tripped)
	PGM.reset_output(1)
	check("P2 reset_output возвращает питание", not PGM.get_output(1).tripped and PGM.get_power(1) == 50.0)

	# --- P3 ---
	PGM.reset_state()
	var panel_a := Node.new()
	var panel_b := Node.new()
	var panel_c := Node.new()
	var sa := PGM.register_source(PowerModels.MULTI, panel_a)
	check("P3 первая панель забрала свободный источник", PGM.sources.size() == 1 and sa == PGM.sources[0])
	var sb := PGM.register_source(PowerModels.MULTI, panel_b)
	check("P3 вторая панель: новый источник", PGM.sources.size() == 2 and sb != sa)
	check("P3 метки второго 11–20", sb.labels()[0] == 11 and sb.labels()[9] == 20, str(sb.labels()))
	PGM.set_command(11, 35)
	check("P3 вывод 11 работает", PGM.get_power(11) == 35.0 and PGM.get_power(1) == 0.0)
	PGM.unregister_source(sa)
	var sc := PGM.register_source(PowerModels.MULTI, panel_c)
	check("P3 смена панели: источник тот же, не дублируется", sc == sa and PGM.sources.size() == 2)
	PGM.set_command(-1, 10, sb)
	check("P3 «все» только в пределах источника", PGM.get_power(11) == 10.0 and PGM.get_power(1) == 0.0)
	PGM.emergency_stop(true, sb)
	check("P3 стоп одного источника: второй работает", PGM.get_power(11) == 0.0 and PGM.get_output(1) != null and not PGM.is_output_stopped(1))
	PGM.emergency_stop(false)
	PGM.remove_source(sb)
	check("P3 remove_source убирает метки", PGM.get_output(11) == null and PGM.sources.size() == 1)
	PGM.unregister_source(sc)
	panel_a.free()
	panel_b.free()
	panel_c.free()

	# --- P4 ---
	PGM.reset_state()
	PGM.set_command(1, 50)
	PGM.set_mains(false)
	check("P4 сети нет: multi мертв", PGM.get_power(1) == 0.0 and PGM.is_output_stopped(1))
	PGM.set_mains(true)
	check("P4 сеть включена: как было", PGM.get_power(1) == 50.0)

	# --- P5 ---
	PGM.reset_state()
	PGM.set_command(1, 60)
	var trips := [0]
	var on_trip := func(_l, _r): trips[0] += 1
	PGM.contour_tripped.connect(on_trip)
	var port := make_port(1, 60.0, 1.3, self)
	PGM.register_port(port)
	for i in 3:
		PGM._step_solver(0.1)
	check("P5 0.3 с: перегрузка", PGM.get_output(1).state == PowerOutput.State.OVERLOAD and not PGM.get_output(1).tripped)
	for i in 3:
		PGM._step_solver(0.1)
	check("P5 0.6 с: вывод отключен", PGM.get_output(1).tripped and PGM.get_power(1) == 0.0)
	check("P5 сигнал contour_tripped ушёл один раз", trips[0] == 1, str(trips[0]))
	PGM.reset_output(1)
	check("P5 сброс: питание вернулось", not PGM.get_output(1).tripped and PGM.get_power(1) == 60.0)
	port.voltage = 60.0
	for i in 6:
		PGM._step_solver(0.1)
	check("P5 причина не устранена: сработало снова", PGM.get_output(1).tripped)
	PGM.contour_tripped.disconnect(on_trip)
	PGM.unregister_port(port)

	# --- P6 ---
	PGM.reset_state()
	var extra_owner := Node.new()
	var s_extra := PGM.register_source(PowerModels.MULTI, extra_owner)   # забирает свободный по умолчанию (sources.size() == 1)
	var s_second := PGM.register_source(PowerModels.MULTI, self)
	PGM.set_command(1, 45)
	PGM.set_command(2, -30)
	PGM.set_command(11, 70)
	s_extra.selected = 2
	PGM.trip_contour(2, "overload")
	PGM.emergency_stop(true, s_second)
	PGM.set_mains(false)
	var saved := PGM.save_state()
	check("P6 сейв содержит 2 источника", (saved.sources as Array).size() == 2, str(saved.keys()))
	PGM.set_mains(true)
	PGM.reset_state()
	PGM.remove_source(s_second)
	PGM.load_state(saved)
	check("P6 загрузка: команды", PGM.get_output(1).command == 45 and PGM.get_output(2).command == -30 and PGM.get_output(11).command == 70)
	check("P6 загрузка: второй источник создан", PGM.sources.size() == 2 and PGM.get_source_of(11) != null)
	check("P6 загрузка: защита", PGM.get_output(2).tripped and PGM.get_output(2).trip_reason == "overload")
	check("P6 загрузка: estop второго", PGM.get_source_of(11).estop and PGM.get_power(11) == 0.0)
	check("P6 загрузка: сеть выключена", not PGM.mains.on)
	check("P6 загрузка: выбранный вывод", PGM.get_source_of(1).selected == 2)
	var sig := [0]
	var on_loaded := func(): sig[0] += 1
	PGM.state_loaded.connect(on_loaded)
	PGM.load_state(saved)
	PGM.state_loaded.disconnect(on_loaded)
	check("P6 сигнал state_loaded", sig[0] == 1)
	PGM.reset_state()
	PGM.load_state({})
	check("P6 старый сейв без power_state: нули и ошибок нет", PGM.get_power(1) == 0.0 and PGM.mains.on)
	var old_owner_free := PGM.get_source_of(1)
	if old_owner_free:
		PGM.unregister_source(old_owner_free)
	extra_owner.free()
	PGM.reset_state()

	print("--------")
	print("power_solver_test: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit()
