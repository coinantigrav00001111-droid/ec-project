extends Node

# D4 (ATTN_10 §10.9): новый файл
## Тест графа проводки (DeviceGraph) на клеммах без сцены физики.
## Запуск: открыть tests/device_graph_test.tscn и нажать F6. Результат в Output: строки PASS / FAIL и итог.
## G1 клемма без провода: wired = false
## G2 провод от вывода 3 к клипу: wired, reachable, label 3, flip нет
## G3 провод со скруткой: flip = true
## G4 вывод 5 и вывод 2 на одном клипе: берётся меньшая метка (2)
## G5 провод ведёт в клемму устройства без выхода: wired, но reachable = false
## G6 устройство с внутренней связью и переворотом (реверсор) плюс скрутка: чётность складывается (flip = false)
## G7 цепочка устройство -> устройство доходит до источника
## G8 источник не проводит дальше: ток не идёт через вывод в другой вывод
## G10 via: устройства на пути попадают в ответ в порядке от клипа к источнику
## G9 PowerTerminal.can_connect / refuse_reason: тип, роль, занятость

var _fails := 0
var _nodes: Array[Node] = []


func check(name: String, ok: bool, info := "") -> void:
	if ok:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name, "  ", info)


func term(role: PowerTerminal.Role, label := 0, kind := PowerTerminal.Kind.TRACK) -> PowerTerminal:
	var t := PowerTerminal.new()
	t.role = role
	t.output_label = label
	t.kind = kind
	add_child(t)
	_nodes.append(t)
	return t


func _ready() -> void:
	# G1
	var g := DeviceGraph.new()
	var clip := term(PowerTerminal.Role.SINK)
	check("G1 без провода wired = false", not g.drive(clip).wired)

	# G2
	var out3 := term(PowerTerminal.Role.SRC, 3)
	g.add_wire(out3, clip, false)
	var r := g.drive(clip)
	check("G2 провод к выводу: wired, reachable, метка 3", r.wired and r.reachable and r.label == 3 and not r.flip, str(r))

	# G3
	g.clear()
	g.add_wire(out3, clip, true)
	r = g.drive(clip)
	check("G3 скрутка: flip", r.reachable and r.flip, str(r))

	# G4
	g.clear()
	var out5 := term(PowerTerminal.Role.SRC, 5)
	var out2 := term(PowerTerminal.Role.SRC, 2)
	g.add_wire(out5, clip, false)
	g.add_wire(out2, clip, false)
	r = g.drive(clip)
	check("G4 два вывода: берётся меньшая метка", r.label == 2, str(r))

	# G5
	g.clear()
	var dev_in := term(PowerTerminal.Role.DEV_IN)
	g.add_wire(dev_in, clip, false)
	r = g.drive(clip)
	check("G5 тупик: wired без reachable", r.wired and not r.reachable, str(r))

	# G6
	g.clear()
	var d_out := term(PowerTerminal.Role.DEV_OUT)
	var d_in := term(PowerTerminal.Role.DEV_IN)
	d_out.link_fn = func(_t): return [{"terminal": d_in, "flip": true}]
	d_in.link_fn = func(_t): return [{"terminal": d_out, "flip": true}]
	g.add_wire(d_out, clip, false)
	g.add_wire(out3, d_in, false)
	r = g.drive(clip)
	check("G6 реверсор переворачивает", r.reachable and r.label == 3 and r.flip, str(r))
	g.clear()
	g.add_wire(d_out, clip, true)
	g.add_wire(out3, d_in, false)
	r = g.drive(clip)
	check("G6 реверсор и скрутка гасят друг друга", r.reachable and not r.flip, str(r))

	# G7
	g.clear()
	var d2_out := term(PowerTerminal.Role.DEV_OUT)
	var d2_in := term(PowerTerminal.Role.DEV_IN)
	d2_out.link_fn = func(_t): return [{"terminal": d2_in, "flip": false}]
	d2_in.link_fn = func(_t): return [{"terminal": d2_out, "flip": false}]
	g.add_wire(d_out, clip, false)
	g.add_wire(d2_out, d_in, false)
	g.add_wire(out5, d2_in, false)
	r = g.drive(clip)
	check("G7 два устройства подряд", r.reachable and r.label == 5 and r.flip, str(r))

	# G8
	g.clear()
	g.add_wire(out5, clip, false)
	g.add_wire(out2, out5, false)   # некорректный провод вывод-вывод: ток через источник не идёт
	r = g.drive(clip)
	check("G8 источник не проводит дальше", r.label == 5, str(r))

	# G10
	g.clear()
	var dev_a := Node.new()
	var dev_b := Node.new()
	_nodes.append(dev_a)
	_nodes.append(dev_b)
	d_out.link_fn = func(_t): return [{"terminal": d_in, "flip": false, "via": dev_a}]
	d2_out.link_fn = func(_t): return [{"terminal": d2_in, "flip": false, "via": dev_b}]
	g.add_wire(d_out, clip, false)
	g.add_wire(d2_out, d_in, false)
	g.add_wire(out5, d2_in, false)
	r = g.drive(clip)
	check("G10 via по порядку", r.reachable and r.via.size() == 2 and r.via[0] == dev_a and r.via[1] == dev_b, str(r))
	g.clear()
	g.add_wire(out3, clip, false)
	check("G10 без устройств via пуст", g.drive(clip).via.is_empty())

	# G9
	var up := term(PowerTerminal.Role.SRC, 1)
	var down := term(PowerTerminal.Role.SINK)
	var up2 := term(PowerTerminal.Role.SRC, 2)
	var sup := term(PowerTerminal.Role.SINK, 0, PowerTerminal.Kind.SUPPLY)
	check("G9 источник к клипу можно", PowerTerminal.can_connect(up, down))
	check("G9 два источника нельзя", not PowerTerminal.can_connect(up, up2) and PowerTerminal.refuse_reason(up, up2) != "")
	check("G9 разные типы нельзя", not PowerTerminal.can_connect(up, sup))
	check("G9 одна и та же клемма нельзя", not PowerTerminal.can_connect(up, up))

	print("ИТОГ: ", "ВСЕ PASS" if _fails == 0 else "FAIL x%d" % _fails)
	for n in _nodes:
		n.queue_free()
