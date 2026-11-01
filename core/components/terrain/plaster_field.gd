class_name PlasterField extends RefCounted

# XX claude-terra 13.5 G1 (новый файл)
#######################
## Ядро гипсового бинта (ATTN_13 §13.5). Чистые функции над массивами высот, без сцены и узлов.
#######################
## Поле это прямоугольная сетка ячеек (w x d), индекс j * w + i. h: высота ступеней в центре ячейки (мир, Y).
## Оболочка S это верхняя огибающая ступеней: S >= h везде. Пандус идёт от верхней ступени вниз с уклоном
## «run ю на слой» (run = 0: ячейка не сглаживается). Подъём над ступенью ограничен max_up, поэтому обрыв выше
## слоя остаётся обрывом с одним слоем пандуса у подошвы. Закреплённые ячейки (ложе трака) получают S = h
## через мягкую маску: коэффициент f (0 закреплено, 1 свободно).
## Пандус считается двумя проходами «шаблона» (chamfer), каждый проход вперёд и назад, по 4 соседям.

## Подъём ниже этого считаем нулевым (оболочку не рисуем, иначе она мерцает вровень с ступенью), ю
const MIN_RAISE := 0.02
const DIAG := 1.41421356


## Оболочка. Все массивы длиной w * d. cell: сторона ячейки (ю), T: высота слоя, max_up: наибольший подъём (ю)
static func smooth(h: PackedFloat32Array, run: PackedFloat32Array, f: PackedFloat32Array, w: int, d: int,
		cell: float, T: float, max_up: float) -> PackedFloat32Array:
	var s := h.duplicate()
	for _i in 2:
		_sweep(s, h, run, w, d, cell, T, max_up, true)
		_sweep(s, h, run, w, d, cell, T, max_up, false)
	var out := PackedFloat32Array()
	out.resize(w * d)
	for i in w * d:
		out[i] = h[i] + (s[i] - h[i]) * f[i]
	return out


static func _sweep(s: PackedFloat32Array, h: PackedFloat32Array, run: PackedFloat32Array, w: int, d: int,
		cell: float, T: float, max_up: float, forward: bool) -> void:
	var dirs: Array[Vector3i]   # (dx, dz, диагональ 0/1)
	if forward:
		dirs = [Vector3i(-1, 0, 0), Vector3i(-1, -1, 1), Vector3i(0, -1, 0), Vector3i(1, -1, 1)]
	else:
		dirs = [Vector3i(1, 0, 0), Vector3i(1, 1, 1), Vector3i(0, 1, 0), Vector3i(-1, 1, 1)]
	var j0 := 0 if forward else d - 1
	var j1 := d if forward else -1
	var dj := 1 if forward else -1
	var i0 := 0 if forward else w - 1
	var i1 := w if forward else -1
	var di := 1 if forward else -1
	var j := j0
	while j != j1:
		var i := i0
		while i != i1:
			var idx := j * w + i
			var r := run[idx]
			if r > 0.0:
				var drop := T / r * cell   # падение высоты на шаг по стороне ячейки
				var best := s[idx]
				for dir in dirs:
					var nx := i + dir.x
					var nz := j + dir.y
					if nx < 0 or nx >= w or nz < 0 or nz >= d:
						continue
					var cand := s[nz * w + nx] - drop * (DIAG if dir.z == 1 else 1.0)
					if cand > best:
						best = cand
				s[idx] = minf(best, h[idx] + max_up)
			i += di
		j += dj


## Мягкая маска закрепления: pin (0/1) размывается двумя проходами по радиусу r ячеек.
## Результат: 0 внутри закреплённого, 1 вдали, между ними плавно
static func pin_factor(pin: PackedByteArray, w: int, d: int, r: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(w * d)
	for i in w * d:
		a[i] = float(pin[i])
	if r > 0:
		a = box_blur(a, w, d, r)
		a = box_blur(a, w, d, r)
	for i in w * d:
		a[i] = 1.0 - clampf(a[i] * 2.0, 0.0, 1.0)
	return a


## Размытие окном (2r + 1) по строкам и столбцам, за краем значение краевой ячейки
static func box_blur(a: PackedFloat32Array, w: int, d: int, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(w * d)
	var n := float(2 * r + 1)
	for j in d:
		for i in w:
			var sum := 0.0
			for k in range(-r, r + 1):
				sum += a[j * w + clampi(i + k, 0, w - 1)]
			tmp[j * w + i] = sum / n
	var out := PackedFloat32Array()
	out.resize(w * d)
	for j in d:
		for i in w:
			var sum := 0.0
			for k in range(-r, r + 1):
				sum += tmp[clampi(j + k, 0, d - 1) * w + i]
			out[j * w + i] = sum / n
	return out


## Нормаль оболочки в ячейке (центральные разности, на краю односторонние)
static func normal(s: PackedFloat32Array, w: int, d: int, i: int, j: int, cell: float) -> Vector3:
	var xl := s[j * w + maxi(i - 1, 0)]
	var xr := s[j * w + mini(i + 1, w - 1)]
	var zl := s[maxi(j - 1, 0) * w + i]
	var zr := s[mini(j + 1, d - 1) * w + i]
	var dx := float(mini(i + 1, w - 1) - maxi(i - 1, 0)) * cell
	var dz := float(mini(j + 1, d - 1) - maxi(j - 1, 0)) * cell
	var gx := (xr - xl) / maxf(dx, 0.0001)
	var gz := (zr - zl) / maxf(dz, 0.0001)
	return Vector3(-gx, 1.0, -gz).normalized()
