class_name TrackProfileTools extends RefCounted

########################
## Профили рельса и балласта (ATTN_20, шаг T4)
########################
## Без интерфейса: пресеты, параметрические генераторы, зеркало, привязка к сетке, геометрические проверки.
## Профиль это ломаная PackedVector2Array (x, y), обход слева направо поверх (по часовой), низ на y = 0.

const RAIL_PRESETS := ["Коробка", "Виньоль"]
const BALLAST_PRESETS := ["Трапеция", "Узкая насыпь", "Широкая насыпь", "Плоская (крутые борта)"]

## Параметры генератора рельса Виньоля: размеры в ю. Высота 0.25 и подошва 0.2 как у «коробки» по умолчанию
const VIGNOLE_DEFAULTS := {
	"height": 0.25,       # полная высота
	"foot_width": 0.2,    # ширина подошвы (это rail_width() стиля, от неё коллизия)
	"foot_height": 0.03,  # толщина края подошвы
	"web_width": 0.035,   # толщина шейки
	"head_width": 0.12,   # ширина головки
	"head_height": 0.07,  # высота головки
}
const TRAPEZOID_DEFAULTS := {
	"bottom_half": 1.6,   # полуширина по низу
	"top_half": 1.1,      # полуширина верха (площадка под шпалой)
	"height": 0.5,
}


# ==========================================
# Генераторы и пресеты
# ==========================================

## Рельс Виньоля: подошва, шейка, головка. 14 точек, симметричный, обход слева направо поверх
static func rail_vignole(params: Dictionary = {}) -> PackedVector2Array:
	var p: Dictionary = VIGNOLE_DEFAULTS.duplicate()
	p.merge(params, true)
	var H := maxf(float(p["height"]), 0.05)
	var fw := maxf(float(p["foot_width"]), 0.02) * 0.5
	var fh := clampf(float(p["foot_height"]), 0.005, H * 0.3)
	var ww := clampf(float(p["web_width"]), 0.005, fw * 1.9) * 0.5
	var hh := clampf(float(p["head_height"]), 0.01, H * 0.6)
	var hw := clampf(float(p["head_width"]), ww * 2.0 + 0.005, fw * 2.0) * 0.5
	var ch := minf(0.02, hw * 0.5)   # фаска верха головки
	var web_foot := fh * 1.6          # где подошва переходит в шейку
	var web_head := maxf(H - hh * 1.4, web_foot + 0.01)   # где шейка переходит в головку
	var head_in := maxf(H - hh * 0.8, web_head + 0.005)
	var head_out := maxf(H - hh * 0.25, head_in + 0.005)
	return PackedVector2Array([
		Vector2(-fw, 0.0), Vector2(-fw, fh), Vector2(-ww, web_foot),
		Vector2(-ww, web_head), Vector2(-hw, head_in), Vector2(-hw, head_out), Vector2(-hw + ch, H),
		Vector2(hw - ch, H), Vector2(hw, head_out), Vector2(hw, head_in),
		Vector2(ww, web_head), Vector2(ww, web_foot), Vector2(fw, fh), Vector2(fw, 0.0)])


static func rail_box(width := 0.2, height := 0.25) -> PackedVector2Array:
	var h := width * 0.5
	return PackedVector2Array([Vector2(-h, 0.0), Vector2(-h, height), Vector2(h, height), Vector2(h, 0.0)])


## Насыпь трапецией
static func ballast_trapezoid(params: Dictionary = {}) -> PackedVector2Array:
	var p: Dictionary = TRAPEZOID_DEFAULTS.duplicate()
	p.merge(params, true)
	var bh := maxf(float(p["bottom_half"]), 0.1)
	var th := clampf(float(p["top_half"]), 0.05, bh)
	var h := maxf(float(p["height"]), 0.02)
	return PackedVector2Array([Vector2(-bh, 0.0), Vector2(-th, h), Vector2(th, h), Vector2(bh, 0.0)])


## Пресет по названию из RAIL_PRESETS или BALLAST_PRESETS
static func preset(kind: String, name: String) -> PackedVector2Array:
	if kind == "rail":
		return rail_vignole() if name == "Виньоль" else rail_box()
	match name:
		"Узкая насыпь":
			return ballast_trapezoid({"bottom_half": 1.3, "top_half": 1.05})
		"Широкая насыпь":
			return ballast_trapezoid({"bottom_half": 2.0, "top_half": 1.4, "height": 0.45})
		"Плоская (крутые борта)":
			return ballast_trapezoid({"bottom_half": 1.55, "top_half": 1.45})
	return ballast_trapezoid()


# ==========================================
# Правка
# ==========================================

## Номер точки-пары при зеркале: i <-> n-1-i (у профиля с нечётным числом точек средняя парна сама себе)
static func mirror_index(i: int, n: int) -> int:
	return n - 1 - i


static func is_symmetric(p: PackedVector2Array, eps := 0.0005) -> bool:
	var n := p.size()
	for i in n:
		var q := p[mirror_index(i, n)]
		if absf(p[i].x + q.x) > eps or absf(p[i].y - q.y) > eps:
			return false
	return true


## Симметрия по правой половине: левая берётся зеркально, средняя точка встаёт на x = 0
static func symmetrize(p: PackedVector2Array) -> PackedVector2Array:
	var n := p.size()
	var out := p.duplicate()
	for i in n:
		var j := mirror_index(i, n)
		if i > j:
			continue
		if i == j:
			out[i] = Vector2(0.0, p[i].y)
		else:
			# ведущая точка та, что правее; вторая отражается от неё
			var lead := i if p[i].x >= p[j].x else j
			var follow := j if lead == i else i
			out[follow] = Vector2(-p[lead].x, p[lead].y)
	return out


static func snap(v: Vector2, step: float) -> Vector2:
	if step <= 0.0:
		return v
	return Vector2(snappedf(v.x, step), snappedf(v.y, step))


## Ближайшая точка на ломаной: {index: номер сегмента (от точки index к index + 1), point: Vector2, dist: float}
static func nearest_on_polyline(p: PackedVector2Array, q: Vector2) -> Dictionary:
	var best := {"index": -1, "point": q, "dist": INF}
	for i in p.size() - 1:
		var c := Geometry2D.get_closest_point_to_segment(q, p[i], p[i + 1])
		var d := c.distance_to(q)
		if d < float(best["dist"]):
			best = {"index": i, "point": c, "dist": d}
	return best


# ==========================================
# Проверки
# ==========================================

## Пары несоседних сегментов, которые пересекаются: [Vector2i(i, j), ...] (номера сегментов)
static func intersections(p: PackedVector2Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var n := p.size() - 1
	for i in n:
		for j in range(i + 2, n):
			if Geometry2D.segment_intersects_segment(p[i], p[i + 1], p[j], p[j + 1]) != null:
				out.append(Vector2i(i, j))
	return out


## Сводка по профилю для подписи в студии: {reversed, below_zero, miny, crossings, width, height}
static func inspect(p: PackedVector2Array) -> Dictionary:
	var info := {"reversed": false, "below_zero": 0, "miny": 0.0, "crossings": [], "width": 0.0, "height": 0.0}
	if p.size() < 2:
		return info
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for v in p:
		lo = lo.min(v)
		hi = hi.max(v)
		if v.y < -0.001:
			info["below_zero"] += 1
	info["miny"] = lo.y
	info["width"] = hi.x - lo.x
	info["height"] = hi.y
	info["reversed"] = p[0].x >= p[p.size() - 1].x
	info["crossings"] = intersections(p)
	return info


## Текст проблем одной строкой, "" если всё в порядке
static func problems_text(p: PackedVector2Array) -> String:
	var info := inspect(p)
	var out := PackedStringArray()
	if p.size() < 2:
		return "нужно минимум 2 точки"
	if info["reversed"]:
		out.append("обход справа налево (нормали вывернуты)")
	if info["below_zero"] > 0:
		out.append("%d точек ниже y = 0" % info["below_zero"])
	if (info["crossings"] as Array).size() > 0:
		out.append("самопересечение (%d)" % (info["crossings"] as Array).size())
	if absf(info["miny"]) > 0.001 and info["below_zero"] == 0:
		out.append("низ профиля на y = %.3f, должен быть 0" % info["miny"])
	return "; ".join(out)
