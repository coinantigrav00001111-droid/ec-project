class_name C_PolygonDraw extends Component

# XX claude-terra 13.2 B2 (новый файл)
#######################
## Состояние. Рисование контура листа пенопласта кликами. Живет только на призраке (BuildTool, DRAW_POLYGON).
#######################
## Фазы:
##  1. Маркер (drawing = false): призрак это маленький лист-метка, ездит за курсором как обычный лист
##     (C_TerrainDraggable: сетка, уровень R/F, магнит к траку). Первый клик = первая вершина.
##  2. Рисование (drawing = true): Entity стоит на месте, yaw = 0, вершины хранятся в локальных координатах (XZ).
##     Курсор ведет BuildTool по горизонтальной плоскости на высоте призрака (D5). Призма показывается на лету,
##     когда замкнутый контур годен (C_Contour.validate), поверх нее ломаная и кресты вершин.
##  3. Дубль (preshaped = true): контур уже готов (клон состояния последнего листа), рисовать нечего.
## Закрытие (try_close): контур чистится, Origin переносится в центр габарита на сетке (D2), точки остаются целыми.
## Состояние на реальный лист переносит C_TerrainDraggable.on_clone_state_to (points, levels).
## Режим полосы (13.2 B5, strip = true, BuildBehavior.DRAW_STRIP): клики ставят точки ОСИ, контур листа = ось, смещённая
## на полширины в обе стороны (Geometry2D.offset_polyline, стык MITER, торцы прямые). Заканчивается клик по последней точке
## или Enter, ширина [ и ]. Лист не помнит ось и ширину: после постановки правится ручками контура (B3).
## Тул вызывает методы компонента напрямую: begin, add_vertex, undo_vertex, try_close, set_cursor, elevate, add_levels, add_width.

const COL_OK := Color(1.0, 0.85, 0.3)
const COL_BAD := Color(1.0, 0.3, 0.3)
const COL_CLOSE := Color(0.4, 1.0, 0.5)
const COL_DIM := Color(0.8, 0.8, 0.8, 0.6)
const COL_CURSOR := Color(0.5, 0.9, 1.0)
## Наибольшее число точек оси полосы (контур полосы почти вдвое больше: C_Contour.MAX_POINTS)
const MAX_AXIS := 30
const WIDTH_MIN := 2.0
const WIDTH_MAX := 40.0
const WIDTH_DEFAULT := 6.0

## Режим полосы: вершины это ось, а не контур
var strip := false
## Ширина полосы, ю (только strip). Меняется add_width, предел WIDTH_MIN..WIDTH_MAX
var width := WIDTH_DEFAULT
## Первый клик сделан, вершины ставятся
var drawing := false
## Контур готов (дубль): рисовать нечего
var preshaped := false
## Вершины, локальные координаты Entity (x = X, y = Z), на сетке
var verts := PackedVector2Array()
## Курсор, локальные координаты, на сетке
var cursor := Vector2.ZERO
## Почему нельзя поставить вершину в точке курсора ("" - можно)
var vertex_reason := ""
## Почему нельзя закрыть контур ("" - можно). Только для замкнутого контура (курсор на первой вершине)
var close_reason := ""

var _layer: C_TerrainLayer
var _contour: C_Contour
var _marker := PackedVector2Array()   # контур-маркер до первого клика
var _shown := PackedVector2Array()    # контур, который сейчас построен как призма на призраке
var _has_cursor := false
var _strip_why := ""                  # почему не вышел контур полосы (петля, дыра, мало точек)
var _mi: MeshInstance3D
var _imm: ImmediateMesh
var _note: TrackNote.Line


func on_added() -> void:
	name = 'C_PolygonDraw'
	_layer = get_comp(C_TerrainLayer) as C_TerrainLayer
	_contour = get_comp(C_Contour) as C_Contour
	if _contour:
		_marker = _contour.points.duplicate()


func on_removed() -> void:
	if is_instance_valid(_mi):
		_mi.queue_free()
	if _note:
		_note.queue_free()
		_note = null


## --- Управление (вызывает BuildTool) ---

## Первый клик: первая вершина в точке маркера. Origin встаёт на сетку, yaw сбрасывается (D2)
func begin() -> void:
	if drawing or preshaped or _layer == null or _contour == null:
		return
	var step: float = Global.settings.terrain_grid_step
	var p := entity.global_position
	entity.global_transform = Transform3D(Basis.IDENTITY,
			Vector3(snappedf(p.x, step), p.y, snappedf(p.z, step)))
	verts = PackedVector2Array([Vector2.ZERO])
	cursor = Vector2.ZERO
	_has_cursor = false
	_shown = PackedVector2Array()
	drawing = true
	if _layer.mesh_node:
		_layer.mesh_node.visible = false   # маркер не нужен, призма появится, когда контур станет годным
	_ensure_preview()
	_refresh()


## Курсор мыши (мировая точка на плоскости призрака). Позиция привязывается к сетке
func set_cursor(world: Vector3) -> void:
	if not drawing:
		return
	var step: float = Global.settings.terrain_grid_step
	var o := entity.global_position
	var c := Vector2(snappedf(world.x, step) - o.x, snappedf(world.z, step) - o.z)
	if _has_cursor and c.is_equal_approx(cursor):
		return
	cursor = c
	_has_cursor = true
	_refresh()


## Курсор стоит на первой вершине (полоса: на последней точке оси) и вершин хватает: клик заканчивает рисунок
func is_closing() -> bool:
	if not drawing:
		return false
	var step: float = Global.settings.terrain_grid_step
	if strip:
		return verts.size() >= 2 and cursor.distance_to(verts[verts.size() - 1]) < step * 0.5
	return verts.size() >= 3 and cursor.distance_to(verts[0]) < step * 0.5


## Поставить вершину в точке курсора. false: нельзя (причина в vertex_reason)
func add_vertex() -> bool:
	if not drawing or is_closing() or vertex_reason != "":
		return false
	verts.append(cursor)
	_refresh()
	return true


## Убрать последнюю вершину. Когда вершин не осталось, возврат к маркеру
func undo_vertex() -> void:
	if not drawing:
		return
	verts.remove_at(verts.size() - 1)
	if verts.is_empty():
		_back_to_marker()
	else:
		_refresh()


## Закрыть контур. true: контур годен, Origin перенесен в центр габарита, призрак можно ставить
func try_close() -> bool:
	if not drawing or verts.size() < (2 if strip else 3) or _contour == null or _layer == null:
		return false
	var shape := verts
	if strip:
		shape = _strip_outline(verts)
	var fin := C_Contour.cleaned(shape) if not shape.is_empty() else shape
	var why := C_Contour.validate(fin) if not fin.is_empty() else _strip_why
	if why == "":
		_contour.set_points(fin)
		if _overlaps():
			why = "Налезает на другой лист"
	if why != "":
		_shown = PackedVector2Array()   # контур мог быть заменён на fin: пусть _refresh построит призму заново
		_refresh()   # вернуть вид контура с курсором
		_show_message(why)
		return false
	# Origin в центр габарита на сетке: локальные точки остаются целыми
	var step: float = Global.settings.terrain_grid_step
	var c := C_Contour.bounds_of(fin).get_center()
	var shift := Vector2(snappedf(c.x, step), snappedf(c.y, step))
	if shift != Vector2.ZERO:
		var moved := PackedVector2Array()
		for v in fin:
			moved.append(v - shift)
		fin = moved
		entity.global_position += Vector3(shift.x, 0.0, shift.y)
	verts = fin
	_contour.set_points(fin)
	_set_invalid(false)
	if is_instance_valid(_mi):
		_mi.visible = false
	if _note:
		_note.visible = false
	return true


## Дубль: контур пришел готовым, фаза рисования не нужна
func set_preshaped() -> void:
	preshaped = true
	drawing = false
	if _layer and _layer.mesh_node:
		_layer.mesh_node.visible = true
	if is_instance_valid(_mi):
		_mi.visible = false
	if _note:
		_note.visible = false


## Уровень призрака во время рисования (R/F, Shift+R/F, PgUp/PgDn), в слоях
func elevate(levels: int) -> void:
	var T: float = Global.settings.layer_height
	entity.global_position.y = maxf(0.0, entity.global_position.y + float(levels) * T)
	if drawing:
		_shown = PackedVector2Array()   # перекрытие и высота ломаной пересчитать
		_refresh()


## Ширина полосы (клавиши [ и ]), ю. Только в режиме полосы
func add_width(delta: float) -> void:
	if not strip:
		return
	width = clampf(snappedf(width + delta, 0.5), WIDTH_MIN, WIDTH_MAX)
	if drawing:
		_shown = PackedVector2Array()   # контур пересобрать
		_refresh()


## Толщина (Ctrl+R/F), в слоях. Работает и у маркера
func add_levels(delta: int) -> void:
	if _layer == null:
		return
	_layer.set_levels(_layer.levels + delta)
	if drawing:
		_refresh()
	else:
		_layer.update_validity()


## --- Внутреннее ---

func _back_to_marker() -> void:
	drawing = false
	verts = PackedVector2Array()
	_shown = PackedVector2Array()
	_has_cursor = false
	if _contour:
		_contour.set_points(_marker)
	if _layer and _layer.mesh_node:
		_layer.mesh_node.visible = true
	if is_instance_valid(_mi):
		_mi.visible = false
	if _note:
		_note.visible = false
	_set_invalid(false)
	if _layer:
		_layer.update_validity()


## Пересчитать причины, призму, подсветку и подпись после любого изменения
func _refresh() -> void:
	if not drawing or _contour == null or _layer == null:
		return
	var closing := is_closing()
	# chain: вершины контура (полигон) или точки оси (полоса), с курсором в конце, пока рисунок не заканчивается
	var chain := verts.duplicate()
	if not closing:
		chain.append(cursor)

	# 1. вершину в точке курсора ставить можно?
	vertex_reason = ""
	if not closing:
		if verts.size() >= (MAX_AXIS if strip else C_Contour.MAX_POINTS):
			vertex_reason = "Больше %d вершин" % (MAX_AXIS if strip else C_Contour.MAX_POINTS)
		else:
			vertex_reason = C_Contour.validate_chain(chain)

	# 2. замкнутый контур годен: показываем призму, иначе только линии. У полосы контур строится из оси
	var poly := chain
	var poly_reason := ""
	if strip:
		poly = _strip_outline(chain)
		poly_reason = _strip_why if poly.is_empty() else C_Contour.validate(poly)
	else:
		poly_reason = C_Contour.validate(chain)
	var overlap := false
	if poly_reason == "":
		if _shown != poly:
			_contour.set_points(poly)
			_shown = poly.duplicate()
		overlap = _overlaps()
		_layer.mesh_node.visible = true
	else:
		_shown = PackedVector2Array()
		_layer.mesh_node.visible = false
	close_reason = ""
	if closing:
		close_reason = "Налезает на другой лист" if (poly_reason == "" and overlap) else poly_reason

	# 3. подсветка и подпись
	var msg := close_reason if closing else vertex_reason
	if not closing and msg == "" and overlap:
		msg = "Налезает на другой лист"
	var bad := msg != ""
	var info := msg
	if strip and not closing and not bad and poly_reason != "" and chain.size() >= 2:
		info = poly_reason   # ось годна, а полоса пока нет: подсказка белым, не отказ
	_set_invalid(bad)
	_redraw(closing, bad)
	_update_note(poly_reason == "", info, bad)


## Контур полосы по оси: смещение на полширины в обе стороны. Пустой массив: не вышло (причина в _strip_why)
func _strip_outline(axis: PackedVector2Array) -> PackedVector2Array:
	_strip_why = ""
	if axis.size() < 2:
		_strip_why = "Нужно минимум 2 точки оси"
		return PackedVector2Array()
	var res := Geometry2D.offset_polyline(axis, width * 0.5, Geometry2D.JOIN_MITER, Geometry2D.END_BUTT)
	if res.size() != 1:
		_strip_why = "Полоса образует петлю или дыру"
		return PackedVector2Array()
	var out: PackedVector2Array = res[0]
	for i in out.size():
		out[i] = Vector2(snappedf(out[i].x, 0.001), snappedf(out[i].y, 0.001))   # без хвостов плавающей точки в сейве
	return out


func _overlaps() -> bool:
	return not TGM.layers_overlapping(_layer.world_polygon(), _layer.base_y(), _layer.top_y(), entity).is_empty()


func _set_invalid(on: bool) -> void:
	if on and not entity.has_comp(C_Invalid):
		entity.add_component(C_Invalid.new())
	elif not on and entity.has_comp(C_Invalid):
		entity.remove_component(C_Invalid)


func _ensure_preview() -> void:
	if is_instance_valid(_mi):
		_mi.visible = true
		return
	_imm = ImmediateMesh.new()
	_mi = MeshInstance3D.new()
	_mi.name = "PolygonPreview"
	_mi.mesh = _imm
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	_mi.material_override = m
	entity.add_child(_mi)
	_note = TrackNote.line(entity, &"draw", 0)


## Ломаная и кресты вершин на высоте верха призмы
func _redraw(closing: bool, bad: bool) -> void:
	if _imm == null:
		return
	_imm.clear_surfaces()
	var T: float = Global.settings.layer_height
	var y := float(maxi(1, _layer.levels)) * T + 0.1
	var col := COL_BAD if bad else COL_OK

	var line := verts.duplicate()
	if strip:
		if not closing:
			line.append(cursor)   # полоса: ось не замыкается
	else:
		line.append(verts[0] if closing else cursor)
	if line.size() >= 2:
		_imm.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for p in line:
			_vtx(p, y, col)
		_imm.surface_end()

	_imm.surface_begin(Mesh.PRIMITIVE_LINES)
	if not strip and not closing and verts.size() >= 2:   # замыкающая линия, как выйдет контур
		_vtx(cursor, y, COL_DIM)
		_vtx(verts[0], y, COL_DIM)
	for i in verts.size():
		# полигон: первая вершина, сюда клик замыкает; полоса: последняя точка, сюда клик заканчивает
		var target := i == (verts.size() - 1 if strip else 0)
		var ok := target and verts.size() >= (2 if strip else 3)
		_cross(verts[i], y, 0.7 if ok else 0.35, COL_CLOSE if ok else col)
	if not closing:
		_cross(cursor, y, 0.5, COL_CURSOR)
	_imm.surface_end()


func _vtx(p: Vector2, y: float, c: Color) -> void:
	_imm.surface_set_color(c)
	_imm.surface_add_vertex(Vector3(p.x, y, p.y))


func _cross(p: Vector2, y: float, r: float, c: Color) -> void:
	_vtx(p + Vector2(-r, 0.0), y, c)
	_vtx(p + Vector2(r, 0.0), y, c)
	_vtx(p + Vector2(0.0, -r), y, c)
	_vtx(p + Vector2(0.0, r), y, c)


## Подпись над курсором: вершины, слои, уровень, площадь и причина отказа
func _update_note(shaped: bool, msg: String, bad: bool) -> void:
	if _note == null:
		return
	var T: float = Global.settings.layer_height
	var text := "Вершин %d · Слоёв %d · Ур. %d" % [verts.size(), _layer.levels, roundi(entity.global_position.y / T)]
	if strip:
		text = "Точек %d · Ширина %.1f · Слоёв %d · Ур. %d" % [verts.size(), width, _layer.levels, roundi(entity.global_position.y / T)]
	if shaped:
		text += " · %.0f ю²" % _contour.area()
	if msg != "":
		text += "\n" + msg
	_note.text = text
	_note.modulate = COL_BAD if bad else Color.WHITE
	_note.position = Vector3(cursor.x, float(maxi(1, _layer.levels)) * T + 2.5, cursor.y)
	_note.visible = true


## Разовое сообщение при отказе закрыть контур (затирается следующим _refresh)
func _show_message(msg: String) -> void:
	if _note:
		_note.text = msg
		_note.modulate = COL_BAD
		_note.visible = true
