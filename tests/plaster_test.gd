extends Node

# XX claude-terra 13.5 G1 (новый файл)
## Тест ядра гипсового бинта: PlasterField (пандус, предел подъёма, закрепление, размытие, нормаль).
## Сцены и TGM не нужно. Запуск: tests/plaster_test.tscn, F6, строки PASS / FAIL в Output.

var _fails := 0


func check(name: String, ok: bool, info := "") -> void:
	if ok:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name, "  ", info)


func near(a: float, b: float, eps := 0.01) -> bool:
	return absf(a - b) <= eps


## Поле w x d, слева (x < edge) высота lo, справа hi. Ячейка 0,5 ю
func step_field(w: int, d: int, edge: int, lo: float, hi: float) -> PackedFloat32Array:
	var h := PackedFloat32Array()
	h.resize(w * d)
	for j in d:
		for i in w:
			h[j * w + i] = lo if i < edge else hi
	return h


func filled(n: int, v: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	a.fill(v)
	return a


func _ready() -> void:
	var w := 40
	var d := 5
	var c := 0.5
	var T := 1.0
	var h := step_field(w, d, 20, 4.0, 5.0)   # низкая ступень 4 слева, высокая 5 справа, край на ячейке 20
	var run := filled(w * d, 2.0)             # 2 ю на слой
	var f := filled(w * d, 1.0)
	var s := PlasterField.smooth(h, run, f, w, d, c, T, 1.0)
	var mid := 2 * w
	check("smooth: оболочка не ниже ступеней", _min_diff(s, h) >= -0.0001, str(_min_diff(s, h)))
	check("smooth: у края низкой стороны подъём почти на слой", s[mid + 19] > 4.7, str(s[mid + 19]))
	check("smooth: пандус спадает вниз по ходу от края", s[mid + 17] < s[mid + 18] and s[mid + 18] < s[mid + 19], "%f %f %f" % [s[mid + 17], s[mid + 18], s[mid + 19]])
	check("smooth: уклон 1 слой на 2 ю = 0,25 на ячейку", near(s[mid + 19] - s[mid + 18], 0.25, 0.02), str(s[mid + 19] - s[mid + 18]))
	check("smooth: пандус кончается за 2 ю (4 ячейки) от края", near(s[mid + 16], 4.0, 0.001) and s[mid + 17] > 4.0, "%f %f" % [s[mid + 16], s[mid + 17]])
	check("smooth: высокая ступень не тронута", near(s[mid + 25], 5.0, 0.0001) and near(s[mid + 20], 5.0, 0.0001))
	check("smooth: далеко от края низкая ступень не тронута", near(s[mid + 3], 4.0, 0.0001))

	# обрыв выше слоя: пандус только на один слой у подошвы
	var hc := step_field(w, d, 20, 0.0, 5.0)
	var sc := PlasterField.smooth(hc, run, f, w, d, c, T, 1.0)
	check("smooth: обрыв 5 слоёв, у подошвы не выше слоя", sc[mid + 19] <= 1.0001 and sc[mid + 19] > 0.7, str(sc[mid + 19]))
	check("smooth: обрыв 5 слоёв, дальше от края оболочка спадает до земли", near(sc[mid + 10], 0.0, 0.001), str(sc[mid + 10]))

	# run = 0: не сглаживается
	var s0 := PlasterField.smooth(h, filled(w * d, 0.0), f, w, d, c, T, 1.0)
	check("smooth: run 0 даёт ступени без изменений", _min_diff(s0, h) == 0.0 and _max_diff(s0, h) == 0.0)

	# крутой пандус (run 1) и пологий (run 4)
	var s1 := PlasterField.smooth(h, filled(w * d, 1.0), f, w, d, c, T, 1.0)
	var s4 := PlasterField.smooth(h, filled(w * d, 4.0), f, w, d, c, T, 1.0)
	check("smooth: run 1 круче run 4 (меньше длина пандуса)", s1[mid + 16] < s4[mid + 16], "%f %f" % [s1[mid + 16], s4[mid + 16]])
	check("smooth: run 4 тянется на 4 ю (8 ячеек)", s4[mid + 13] > 4.0 and near(s4[mid + 12], 4.0, 0.001), "%f %f" % [s4[mid + 13], s4[mid + 12]])

	# закрепление: f = 0 на куске
	var fp := filled(w * d, 1.0)
	for j in d:
		for i in range(14, 20):
			fp[j * w + i] = 0.0
	var sp := PlasterField.smooth(h, run, fp, w, d, c, T, 1.0)
	check("pin: закреплённые ячейки равны ступеням", near(sp[mid + 17], 4.0, 0.0001) and near(sp[mid + 19], 4.0, 0.0001))
	check("pin: вне закреплённых оболочка прежняя", near(sp[mid + 13], s[mid + 13], 0.0001))

	# маска закрепления
	var pin := PackedByteArray()
	pin.resize(w * d)
	for j in d:
		for i in range(10, 20):
			pin[j * w + i] = 1
	var pf := PlasterField.pin_factor(pin, w, d, 2)
	check("pin_factor: внутри 0", near(pf[mid + 15], 0.0, 0.0001), str(pf[mid + 15]))
	check("pin_factor: вдали 1", near(pf[mid + 35], 1.0, 0.0001), str(pf[mid + 35]))
	check("pin_factor: на краю между 0 и 1, монотонно", pf[mid + 20] > pf[mid + 19] and pf[mid + 22] >= pf[mid + 20] and pf[mid + 20] < 1.0 + 0.0001)

	# размытие сохраняет сумму в середине плоского поля
	var flat := filled(w * d, 3.0)
	var bl := PlasterField.box_blur(flat, w, d, 2)
	check("box_blur: плоское поле не меняется", near(bl[mid + 10], 3.0, 0.0001) and near(bl[0], 3.0, 0.0001))

	# нормаль
	var nz := PlasterField.normal(flat, w, d, 10, 2, c)
	check("normal: плоскость смотрит вверх", near(nz.y, 1.0, 0.0001) and near(nz.x, 0.0, 0.0001))
	var nr := PlasterField.normal(s, w, d, 18, 2, c)
	check("normal: на пандусе наклонена к низкой стороне (-X), нормаль.y меньше 1", nr.x < 0.0 and nr.y < 1.0 and nr.y > 0.5, str(nr))

	print("ИТОГО: ", "всё PASS" if _fails == 0 else "FAIL: %d" % _fails)


func _min_diff(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var m := INF
	for i in a.size():
		m = minf(m, a[i] - b[i])
	return m


func _max_diff(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var m := -INF
	for i in a.size():
		m = maxf(m, a[i] - b[i])
	return m
