class_name C_TerrainLayer extends C_Visual

# XX claude-terra (новый файл)
###################################
## Визуал и физика листа пенопласта. Сцены нет: все ноды строятся в коде (как C_FlexVisual).
###################################
## Лист = призма: контур C_Contour в плане на высоту levels * layer_height.
## Origin Entity = низ листа, поэтому лист на столе стоит на y = 0, а лист на листе на его верху.
##  - меш: верх, низ и стенки (SurfaceTool), нормали плоские;
##  - коллизия: StaticBody3D на слое ground, контур раскладывается на выпуклые куски;
##  - призрак (C_Ghost) и драг (C_Drag): тело уезжает на слой ghost, иначе луч драга попадет в сам лист
##    (так же, как у трака в C_Path.on_select_layer). Выбор слой не меняет: выбранный лист остается землей;
##  - событие terrain_changed в TGM: лист поставлен, сдвинут, удален, поменял форму.
## Сейв: levels. Контур сохраняет C_Contour, поза лежит в transform Entity.

## Толщина в слоях (GlobalSetting.layer_height). Целое, минимум 1
var levels := 1

var mesh_node: MeshInstance3D
var body: StaticBody3D

var _shapes: Array[CollisionShape3D] = []
var _last_aabb := AABB()
static var _mat_raw: StandardMaterial3D


## Базовый C_Visual.on_added инстанцирует сцену; у листа сцены нет
func on_added() -> void:
	instance = Node3D.new()
	instance.name = 'Foam'
	entity.add_child(instance)

	mesh_node = MeshInstance3D.new()
	mesh_node.name = 'Mesh'
	instance.add_child(mesh_node)

	body = StaticBody3D.new()
	body.name = 'Body'
	instance.add_child(body)
	_apply_collision_layers()

	parts = PartRegistry.build(instance)
	_collect_meshes()
	_on_instance_ready()


func on_entity_ready() -> void:
	entity.add_to_group(TGM.GROUP)
	_rebuild()
	update_visual()


func on_contour_changed(_d: Dictionary) -> void:
	_rebuild()


func on_component_added(type: Script) -> void:
	super(type)
	if type == C_Ghost or type == C_Drag:
		_apply_collision_layers()


func on_component_removed(type: Script) -> void:
	super(type)
	if type == C_Ghost or type == C_Drag:
		_apply_collision_layers(type)


## Драг начался: лист уходит с места (C_Drag уже висит, get_layers() его не отдаст), землю под ним надо пересчитать
func on_drag_started(_d: Dictionary) -> void:
	_notify()


## Лист окончательно встал (шлет C_TerrainDraggable после проверки перекрытия и возможного возврата
## на исходное место). Не on_drag_ended: порядок компонентов не гарантирует, что откат уже сделан
func on_terrain_moved(_d: Dictionary) -> void:
	_notify()


func _exit_tree() -> void:
	super()
	# лист удален: сообщаем старую область (призрака не учитываем)
	if is_instance_valid(TGM) and _last_aabb.size != Vector3.ZERO and entity and not entity.has_comp(C_Ghost):
		TGM.notify_changed(_last_aabb)


## --- Слои коллизии ---

## removing: тип компонента, который прямо сейчас снимается (has_comp на него еще может отвечать true)
func _apply_collision_layers(removing: Script = null) -> void:
	if body == null:
		return
	var floating := (has_comp(C_Ghost) and removing != C_Ghost) or (has_comp(C_Drag) and removing != C_Drag)
	body.collision_layer = Global.active_layers(['ghost']) if floating else Global.active_layers(['ground'])
	body.collision_mask = 0   # статическое тело само ничего не ищет


## --- Построение ---

func _rebuild() -> void:
	if mesh_node == null:
		return
	var contour := get_comp(C_Contour) as C_Contour
	if contour == null or contour.points.size() < 3:
		return
	var pts := contour.normalized_points()
	var h = float(maxi(1, levels)) * Global.settings.layer_height

	var tris := Geometry2D.triangulate_polygon(pts)
	if tris.is_empty():
		push_warning("[C_TerrainLayer] контур не триангулируется (вырожденный или самопересекающийся), лист не построен")
		mesh_node.mesh = null
		_clear_shapes()
		return

	mesh_node.mesh = _build_mesh(pts, tris, h)
	_build_collision(pts, h)
	_notify()


func _build_mesh(pts: PackedVector2Array, tris: PackedInt32Array, h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(_material())

	# верх и низ
	for i in range(0, tris.size(), 3):
		var a := pts[tris[i]]
		var b := pts[tris[i + 1]]
		var c := pts[tris[i + 2]]
		_tri(st, Vector3(a.x, h, a.y), Vector3(b.x, h, b.y), Vector3(c.x, h, c.y), Vector3.UP)
		_tri(st, Vector3(a.x, 0.0, a.y), Vector3(b.x, 0.0, b.y), Vector3(c.x, 0.0, c.y), Vector3.DOWN)

	# стенки. pts обходится против часовой (area > 0), наружу от ребра d это (d.y, -d.x)
	var n := pts.size()
	for i in n:
		var p0 := pts[i]
		var p1 := pts[(i + 1) % n]
		var d := p1 - p0
		if d.length_squared() < 0.000001:
			continue
		var outward := Vector3(d.y, 0.0, -d.x).normalized()
		var a0 := Vector3(p0.x, 0.0, p0.y)
		var a1 := Vector3(p1.x, 0.0, p1.y)
		var b0 := Vector3(p0.x, h, p0.y)
		var b1 := Vector3(p1.x, h, p1.y)
		_tri(st, a0, a1, b1, outward)
		_tri(st, a0, b1, b0, outward)

	return st.commit()


## Треугольник, лицевая сторона которого смотрит в nrm. Лицевая грань в Godot идет по часовой стрелке:
## при взгляде на лицевую сторону векторное произведение (b-a)x(c-a) смотрит от наблюдателя, то есть против nrm
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, nrm: Vector3) -> void:
	if (b - a).cross(c - a).dot(nrm) > 0.0:
		var t := b
		b = c
		c = t
	st.set_normal(nrm)
	st.add_vertex(a)
	st.set_normal(nrm)
	st.add_vertex(b)
	st.set_normal(nrm)
	st.add_vertex(c)


func _build_collision(pts: PackedVector2Array, h: float) -> void:
	_clear_shapes()
	var pieces: Array = Geometry2D.decompose_polygon_in_convex(pts)
	if pieces.is_empty():
		pieces = [pts]   # разбить не вышло: пробуем контур целиком (если он выпуклый, это сработает)
	for piece: PackedVector2Array in pieces:
		var v := PackedVector3Array()
		for p: Vector2 in piece:
			v.append(Vector3(p.x, 0.0, p.y))
			v.append(Vector3(p.x, h, p.y))
		var shape := ConvexPolygonShape3D.new()
		shape.points = v
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		_shapes.append(cs)


func _clear_shapes() -> void:
	for cs in _shapes:
		if is_instance_valid(cs):
			cs.queue_free()
	_shapes.clear()


func _material() -> Material:
	if _mat_raw == null:
		_mat_raw = StandardMaterial3D.new()
		_mat_raw.albedo_color = Color(0.93, 0.62, 0.72)   # розовый пенопласт
		_mat_raw.roughness = 1.0
	return _mat_raw


## --- Геометрия для запросов TGM ---

## Нижняя отметка листа в мире (origin Entity = низ листа)
func base_y() -> float:
	return entity.global_position.y


## Толщина листа, ю
func height() -> float:
	var T: float = Global.settings.layer_height
	return float(maxi(1, levels)) * T


## Верхняя отметка листа в мире
func top_y() -> float:
	return base_y() + height()


## Контур листа в мире: Vector2(x = X, y = Z), обход против часовой стрелки
func world_polygon() -> PackedVector2Array:
	var res := PackedVector2Array()
	var contour := get_comp(C_Contour) as C_Contour
	if contour == null:
		return res
	var xf := entity.global_transform
	for p in contour.normalized_points():
		var w := xf * Vector3(p.x, 0.0, p.y)
		res.append(Vector2(w.x, w.z))
	return res


## Лист не должен занимать то же место, что другой лист (D6): иначе C_Invalid (красный призрак,
## BuildTool не ставит, DragTool откатит). Вызывает C_TerrainDraggable после каждого движения
func update_validity() -> void:
	var bad := not TGM.layers_overlapping(world_polygon(), base_y(), top_y(), entity).is_empty()
	if bad and not has_comp(C_Invalid):
		entity.add_component(C_Invalid.new())
	elif not bad and has_comp(C_Invalid):
		entity.remove_component(C_Invalid)


## --- Помощники ---

## Мировая область листа (по четырем сторонам призмы), для terrain_changed
func _world_aabb(pts: PackedVector2Array, h: float) -> AABB:
	var xf := entity.global_transform
	var box := AABB(xf * Vector3(pts[0].x, 0.0, pts[0].y), Vector3.ZERO)
	for p in pts:
		box = box.expand(xf * Vector3(p.x, 0.0, p.y))
		box = box.expand(xf * Vector3(p.x, h, p.y))
	return box


func _notify() -> void:
	if not is_instance_valid(TGM) or entity == null or not entity.is_inside_tree() or entity.has_comp(C_Ghost):
		return
	var contour := get_comp(C_Contour) as C_Contour
	if contour == null or contour.points.size() < 3:
		return
	var h = float(maxi(1, levels)) * Global.settings.layer_height
	# сообщаем и старую область: лист мог сдвинуться, там земля тоже изменилась
	var old := _last_aabb
	_last_aabb = _world_aabb(contour.normalized_points(), h)
	TGM.notify_changed(_last_aabb if old.size == Vector3.ZERO else old.merge(_last_aabb))


## --- Сейв ---
func save_data() -> Dictionary:
	return {"levels": levels}


func load_data(data: Dictionary) -> void:
	levels = maxi(1, int(data.get("levels", levels)))
	_rebuild()
