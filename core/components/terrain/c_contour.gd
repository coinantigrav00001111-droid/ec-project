class_name C_Contour extends Component

# XX claude-terra (новый файл)
#######################
## Данные. Контур листа пенопласта в плане.
#######################
## Полигон в локальных координатах Entity: Vector2.x = X, Vector2.y = Z (мировая Y у листа не участвует).
## Entity поворачивается только по yaw, поэтому контур остается плоским.
## Сам ничего не рисует: C_TerrainLayer берет полигон и строит меш и коллизию.
## Название как в ATTN_13. Не путать с электрическими контурами (PGM) и подсветкой Outline.

## XX claude-terra 13.2 B1. Пределы допустимого контура (D3). Больше вершин: больше выпуклых кусков коллизии
const MAX_POINTS := 64
## Наименьшая площадь листа, ю²
const MIN_AREA := 1.0
## Наименьшее ребро, ю (равно шагу сетки terrain_grid_step по умолчанию)
const MIN_EDGE := 1.0
## Допуск при сравнении координат и углов
const EPS := 0.0001

var points := PackedVector2Array()


## Прямоугольник size (X, Z) с центром в начале координат Entity
func set_rect(size: Vector2) -> void:
	var h := size * 0.5
	set_points(PackedVector2Array([
		Vector2(-h.x, -h.y), Vector2(h.x, -h.y),
		Vector2(h.x, h.y), Vector2(-h.x, h.y)]))


func set_points(p: PackedVector2Array) -> void:
	points = p
	if entity:
		entity.send_event("on_contour_changed", {})


## Площадь со знаком (формула шнурков): > 0, если обход против часовой стрелки в плоскости (x, y)
static func signed_area(p: PackedVector2Array) -> float:
	var s := 0.0
	var n := p.size()
	for i in n:
		var a := p[i]
		var b := p[(i + 1) % n]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


## Копия точек с обходом против часовой стрелки (area > 0). Все построения идут от нее
func normalized_points() -> PackedVector2Array:
	var p := points.duplicate()
	if p.size() >= 3 and signed_area(p) < 0.0:
		p.reverse()
	return p


## --- XX claude-terra 13.2 B1. Геометрия и проверка контура ---

## Ограничивающий прямоугольник точек p (пустой Rect2 для пустого массива)
static func bounds_of(p: PackedVector2Array) -> Rect2:
	if p.is_empty():
		return Rect2()
	var lo := p[0]
	var hi := p[0]
	for v in p:
		lo = lo.min(v)
		hi = hi.max(v)
	return Rect2(lo, hi - lo)


func bounds() -> Rect2:
	return bounds_of(points)


## Габарит в плане (X, Z)
func size() -> Vector2:
	return bounds_of(points).size


## Площадь, ю² (всегда положительная)
func area() -> float:
	return absf(signed_area(points))


## Четыре вершины, стороны вдоль осей X и Z (прямоугольный лист из пресета)
static func is_rect_points(p: PackedVector2Array) -> bool:
	if p.size() != 4:
		return false
	for i in 4:
		var a := p[i]
		var b := p[(i + 1) % 4]
		if absf(a.x - b.x) > EPS and absf(a.y - b.y) > EPS:
			return false
	return absf(absf(signed_area(p)) - bounds_of(p).get_area()) <= EPS * 100.0


func is_rect() -> bool:
	return is_rect_points(points)


## Контур без повторяющихся подряд вершин и без вершин на прямой между соседями.
## Порядок обхода не меняется
static func cleaned(p: PackedVector2Array) -> PackedVector2Array:
	var res := p.duplicate()
	var changed := true
	while changed and res.size() >= 3:
		changed = false
		var n := res.size()
		for i in n:
			var prev := res[(i + n - 1) % n]
			var cur := res[i]
			var nxt := res[(i + 1) % n]
			var d1 := cur - prev
			var d2 := nxt - cur
			# повтор (cur совпал с prev) или вершина на прямой, в том числе острие "туда и обратно"
			if d1.length() <= EPS or absf(d1.cross(d2)) <= EPS * d1.length() * d2.length():
				res.remove_at(i)
				changed = true
				break
	return res


## Причина, по которой лист с таким контуром построить нельзя (D3), или пустая строка, если контур годен.
## Проверяет: число вершин, длину рёбер, возвраты ребра назад и самопересечения (включая касание), площадь
static func validate(p: PackedVector2Array, max_points: int = MAX_POINTS) -> String:
	var n := p.size()
	if n < 3:
		return "Меньше 3 вершин"
	if n > max_points:
		return "Больше %d вершин" % max_points
	var edges := _edge_problem(p, true)
	if edges != "":
		return edges
	# площадь последней: у самопересекающегося контура она ничего не значит ("бабочка" может дать 0)
	if absf(signed_area(p)) < MIN_AREA:
		return "Площадь меньше %.0f ю²" % MIN_AREA
	return ""


## XX claude-terra 13.2 B2. Незамкнутая цепочка вершин (рисование): те же правила для рёбер, но замыкающего ребра нет
## и число вершин и площадь не проверяются. Пустая строка: цепочку можно продолжать
static func validate_chain(p: PackedVector2Array) -> String:
	return _edge_problem(p, false)


## Проверка рёбер: короткие, возврат назад, пересечения и касания несоседних рёбер.
## closed = true: контур замкнут (последняя вершина соединена с первой)
static func _edge_problem(p: PackedVector2Array, closed: bool) -> String:
	var n := p.size()
	var m := n if closed else n - 1   # число рёбер
	for i in m:
		if p[i].distance_to(p[(i + 1) % n]) < MIN_EDGE - EPS:
			return "Ребро короче %.1f ю" % MIN_EDGE
	# соседние рёбра: коллинеарные и направленные навстречу друг другу накладываются
	var pairs := n if closed else n - 2
	for i in pairs:
		var a := p[i]
		var b := p[(i + 1) % n]
		var c := p[(i + 2) % n]
		var d1 := b - a
		var d2 := c - b
		if absf(d1.cross(d2)) <= EPS * d1.length() * d2.length() and d1.dot(d2) < 0.0:
			return "Ребро идёт назад"
	# несоседние рёбра не должны пересекаться и касаться
	for i in m:
		var a0 := p[i]
		var a1 := p[(i + 1) % n]
		for j in range(i + 2, m):
			if closed and i == 0 and j == m - 1:
				continue   # последнее ребро соседнее с первым
			if Geometry2D.segment_intersects_segment(a0, a1, p[j], p[(j + 1) % n]) != null:
				return "Самопересечение"
	return ""


## --- Сейв ---
func save_data() -> Dictionary:
	return {"points": points}


func load_data(data: Dictionary) -> void:
	if data.has("points"):
		points = data["points"]
	if entity:
		entity.send_event("on_contour_changed", {})
