class_name FlexSolver extends RefCounted

# XX claude-terra (новый файл)
########################
## Решатель формы flex-трака. Чистая математика, без нод. Локальная плоскость начала:
## x - вправо, f (forward) - вперед (в мире это -Z). Точки Vector2(x, f).
########################


class Limits:
	var r_min := 32.0     # = min_curve_radius вагонов
	var l_min := 10.0
	var l_max := 90.0
	var max_grade := 0.045


## Свободный конец: дуга, касательная к началу. Решается в замкнутом виде, конец "упирается" в пределы.
## Возвращает {points, radii, length, radius}
static func arc_to(target: Vector2, lim: Limits, step := 1.0) -> Dictionary:
	var f := maxf(target.y, 0.5)                      # цель за спиной не берем: дуга < 180°
	var side := signf(target.x) if target.x != 0.0 else 1.0
	var phi := atan2(absf(target.x), f)               # половина угла дуги
	phi = minf(phi, lim.l_max / (2.0 * lim.r_min))    # круче r_min за l_max не получить
	var sinc := sin(phi) / phi if phi > 1e-4 else 1.0
	# L = chord / sinc;  R = chord / (2 sin phi);  отсюда пределы хорды
	var c_lo := maxf(lim.l_min * sinc, 2.0 * lim.r_min * sin(phi))
	var c_hi := lim.l_max * sinc
	var chord := clampf(Vector2(target.x, f).length(), c_lo, c_hi)
	var L := chord / sinc
	var R := chord / (2.0 * sin(phi)) if phi > 1e-4 else INF

	var pts := PackedVector2Array()
	var n := maxi(2, ceili(L / step) + 1)
	for i in n:
		var t := L * i / (n - 1)
		if is_inf(R):
			pts.append(Vector2(0.0, t))
		else:
			var a := t / R
			pts.append(Vector2(side * R * (1.0 - cos(a)), R * sin(a)))
	return {"points": pts, "radii": radii(pts), "length": L, "radius": R}


## Цепочка кривых Эрмита через точки wp (начало, изгибы, конец).
## t0/t1 - единичные касательные на концах, k - масштаб амплитуды
static func hermite_chain(wp: Array[Vector2], t0: Vector2, t1: Vector2, k: float, step := 1.0) -> PackedVector2Array:
	var tans: Array[Vector2] = []
	for i in wp.size():
		if i == 0:
			tans.append(t0)
		elif i == wp.size() - 1:
			tans.append(t1)
		else:
			tans.append((wp[i + 1] - wp[i - 1]).normalized())
	var out := PackedVector2Array()
	for i in wp.size() - 1:
		var d := wp[i].distance_to(wp[i + 1])
		var m0 := tans[i] * d * k
		var m1 := tans[i + 1] * d * k
		var n := maxi(2, ceili(d / step))
		for j in n:
			var u := float(j) / n
			var u2 := u * u
			var u3 := u2 * u
			out.append((2.0 * u3 - 3.0 * u2 + 1.0) * wp[i] + (u3 - 2.0 * u2 + u) * m0
					+ (-2.0 * u3 + 3.0 * u2) * wp[i + 1] + (u3 - u2) * m1)
	out.append(wp[wp.size() - 1])
	return out


## Перебирает k и берет вариант с наибольшим минимальным радиусом.
## Возвращает {points, radii, k, min_radius, length, valid}
static func best_chain(wp: Array[Vector2], t0: Vector2, t1: Vector2, lim: Limits, step := 1.0) -> Dictionary:
	var best := {}
	var best_r := -1.0
	for k in [0.33, 0.4, 0.5, 0.6]:
		var pts := hermite_chain(wp, t0, t1, k, step)
		var r := radii(pts)
		var min_r := INF
		for v in r:
			min_r = minf(min_r, v)
		if min_r > best_r:
			best_r = min_r
			best = {"points": pts, "radii": r, "k": k, "min_radius": min_r}
	var L := path_length(best.points)
	best["length"] = L
	best["valid"] = best_r >= lim.r_min and L >= lim.l_min and L <= lim.l_max
	return best


## Радиус на каждой точке: описанная окружность по трем соседним. INF на прямых
static func radii(p: PackedVector2Array) -> PackedFloat32Array:
	var r := PackedFloat32Array()
	r.resize(p.size())
	r.fill(INF)
	for i in range(1, p.size() - 1):
		var a := p[i].distance_to(p[i - 1])
		var b := p[i + 1].distance_to(p[i])
		var c := p[i + 1].distance_to(p[i - 1])
		var area2 := absf((p[i] - p[i - 1]).cross(p[i + 1] - p[i - 1]))   # = 2·площадь
		if area2 > 1e-5:
			r[i] = a * b * c / (2.0 * area2)
	if p.size() > 2:
		r[0] = r[1]
		r[p.size() - 1] = r[p.size() - 2]
	return r


static func path_length(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in range(1, p.size()):
		s += p[i].distance_to(p[i - 1])
	return s


## Высота: кубический Эрмит по длине s. m0/m1 - уклоны на концах (для свободного конца 0)
static func y_at(s: float, L: float, y0: float, y1: float, m0: float, m1: float) -> float:
	if L < 0.001:
		return y0
	var u := s / L
	var u2 := u * u
	var u3 := u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * y0 + (u3 - 2.0 * u2 + u) * L * m0 \
			+ (-2.0 * u3 + 3.0 * u2) * y1 + (u3 - u2) * L * m1


## Уклон dy/ds в точке s
static func grade_at(s: float, L: float, y0: float, y1: float, m0: float, m1: float) -> float:
	if L < 0.001:
		return 0.0
	var u := s / L
	var u2 := u * u
	return ((6.0 * u2 - 6.0 * u) * y0 + (3.0 * u2 - 4.0 * u + 1.0) * L * m0
			+ (-6.0 * u2 + 6.0 * u) * y1 + (3.0 * u2 - 2.0 * u) * L * m1) / L


## Плоские точки (x, f) + профиль высоты -> Curve3D в локальных осях Entity (вперед = -Z).
## Возвращает {curve, max_grade, length}. max_grade сравнивать с Limits.max_grade
static func to_curve3d(pts: PackedVector2Array, y0: float, y1: float, m0: float, m1: float) -> Dictionary:
	var L := path_length(pts)
	var n := pts.size()
	var p3: Array[Vector3] = []
	var s := 0.0
	var max_g := 0.0
	for i in n:
		if i > 0:
			s += pts[i].distance_to(pts[i - 1])
		p3.append(Vector3(pts[i].x, y_at(s, L, y0, y1, m0, m1), -pts[i].y))
		max_g = maxf(max_g, absf(grade_at(s, L, y0, y1, m0, m1)))
	var curve := Curve3D.new()
	for i in n:
		var prev := p3[maxi(i - 1, 0)]
		var nxt := p3[mini(i + 1, n - 1)]
		var h := (nxt - prev) / (3.0 if (i == 0 or i == n - 1) else 6.0)
		curve.add_point(p3[i], -h, h)
	return {"curve": curve, "max_grade": max_g, "length": L}
