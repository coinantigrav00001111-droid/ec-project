class_name C_FlexHandle extends ICapability

####################
## Способность. Ручки изгибов flex. Владеет Area3D-сферами (слой handles), видны только у выбранного flex.
####################
## LMB по ручке - драг по горизонтальной плоскости ручки. Shift+LMB по кривой - новый изгиб.
## ПКМ по ручке - удалить. Данные изгибов хранит C_FlexShape, тут только ввод и ноды.

const RADIUS := 1.2
const PICK_RADIUS := 1.8
const LIFT := 1.2        # ручка над рельсом

static var _mat: StandardMaterial3D

var _shape: C_FlexShape
var _handles: Array[Area3D] = []
var _drag := -1
var _drag_y := 0.0


func on_entity_ready() -> void:
	_shape = get_comp(C_FlexShape) as C_FlexShape
	_sync()


func on_component_added(_t: Script) -> void:
	_sync()


func on_component_removed(_t: Script) -> void:
	if _drag >= 0 and not has_comp(C_Selected):
		_end_drag()
	_sync()


func on_bends_changed(_d: Dictionary) -> void:
	_sync()


func _is_active() -> bool:
	return has_comp(C_Selected) and not has_comp(C_Ghost) and not has_comp(C_Drag)


func _sync() -> void:
	if _shape == null:
		return
	var n = _shape.bends.size()
	while _handles.size() < n:
		_handles.append(_make_handle())
	while _handles.size() > n:
		var old: Area3D = _handles.pop_back()
		old.queue_free()
	if _drag >= n:
		_drag = -1
	var show := _is_active()
	var layer := Global.active_layers(['handles']) if show else 0
	for i in n:
		var h := _handles[i]
		h.visible = show
		if h.collision_layer != layer:   # слой меняем только при отличии (TDD, пересборка физики)
			h.collision_layer = layer
		if show:
			h.position = _shape.bend_local(i) + Vector3(0.0, LIFT, 0.0)


func _make_handle() -> Area3D:
	if not _mat:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.albedo_color = Color(1.0, 0.65, 0.1)
		_mat.no_depth_test = true
		_mat.render_priority = 10
	var a := Area3D.new()
	a.name = "FlexHandle"
	a.collision_layer = 0
	a.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = PICK_RADIUS
	cs.shape = sp
	a.add_child(cs)
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = RADIUS
	m.height = RADIUS * 2.0
	mi.mesh = m
	mi.material_override = _mat
	a.add_child(mi)
	entity.add_child(a)
	return a


# ==========================================
# Ввод (шлет SelectTool, словарь data общий: consumed / drag пишем в него)
# ==========================================

func on_pointer_pressed(d: Dictionary) -> void:
	if d.get("consumed", false) or _shape == null or not _is_active():
		return
	var col = d.get("collider")
	var i := -1
	if col is Area3D:
		i = _handles.find(col)	
	if i >= 0:
		_drag = i
		_drag_y = _handles[i].global_position.y
		entity.send_event("on_bend_edit_begin", {})
		d["consumed"] = true
		d["drag"] = true
		return
	if d.get("shift", false) and col is Node and _entity_of(col) == entity:
		entity.send_event("on_bend_add", {"position": d.position})
		d["consumed"] = true


func on_handle_drag(d: Dictionary) -> void:
	if _drag < 0:
		return
	var from: Vector3 = d.from
	var dir: Vector3 = d.dir
	if absf(dir.y) < 0.001:
		return
	var t := (_drag_y - from.y) / dir.y
	if t < 0.0:
		return
	var l: Vector3 = entity.to_local(from + dir * t)
	entity.send_event("on_bend_moved", {"index": _drag, "pos": Vector2(l.x, -l.z)})


func on_handle_released(_d: Dictionary) -> void:
	_end_drag()


func on_handle_remove(d: Dictionary) -> void:
	if not _is_active():
		return
	var col = d.get("collider")
	var i := -1
	if col is Area3D:
		i = _handles.find(col)
	if i >= 0:
		d["consumed"] = true
		entity.send_event("on_bend_remove", {"index": i})


func _end_drag() -> void:
	if _drag >= 0:
		_drag = -1
		entity.send_event("on_bend_edit_end", {})


func _entity_of(n: Node) -> Entity:
	while n:
		if n is Entity:
			return n
		n = n.get_parent()
	return null
