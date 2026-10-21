class_name C_Contour extends Component

# XX claude-terra (новый файл)
#######################
## Данные. Контур листа пенопласта в плане.
#######################
## Полигон в локальных координатах Entity: Vector2.x = X, Vector2.y = Z (мировая Y у листа не участвует).
## Entity поворачивается только по yaw, поэтому контур остается плоским.
## Сам ничего не рисует: C_TerrainLayer берет полигон и строит меш и коллизию.
## Название как в ATTN_13. Не путать с электрическими контурами (PGM) и подсветкой Outline.

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


## --- Сейв ---
func save_data() -> Dictionary:
	return {"points": points}


func load_data(data: Dictionary) -> void:
	if data.has("points"):
		points = data["points"]
	if entity:
		entity.send_event("on_contour_changed", {})
