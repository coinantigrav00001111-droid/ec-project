class_name C_TrackSupport extends ICapability

# XX claude-terra (новый файл)
####################
## Способность. Эстакада под траком.
####################
## Семплирует кривую C_Path, бросает лучи вниз и ставит опоры (ригель + столб), где зазор до земли
## больше GlobalSetting.support_min_clearance. Под чужим траком опоры не ставятся (пролет).
## Владеет MultiMeshInstance3D. НЕ сохраняется: считается из пути и земли.
## Земля = стол или верх листа пенопласта (13.1.3). Лист ставят и убирают под готовым траком:
## пересчет по TGM.terrain_changed сразу, а не через REFRESH_PERIOD.

const DRAG_PERIOD := 0.05    # с, не чаще при движении призрака/трака
const REFRESH_PERIOD := 0.5  # с, фоновая проверка (удалили трак под эстакадой и т.п.)

static var _wood: StandardMaterial3D

var _mmi: MultiMeshInstance3D
var _dirty := true
var _cooldown := 0.3         # после загрузки сейва ждем, пока встанут все коллизии
var _refresh := 0.0
var _last_entity_xf := Transform3D()
var _last_xf: Array[Transform3D] = []


func on_entity_ready() -> void:
	_dirty = true
	_cooldown = 0.3
	TGM.terrain_changed.connect(_on_terrain_changed)   # XX claude-terra T3
	# T5: трак встал, листы под ним пересчитают канаву. Отложено: призрак получает C_Ghost после готовности
	call_deferred("_notify_terrain")


## Лист пенопласта поставлен, сдвинут или убран: земля под опорами могла измениться.
## Не фильтруем по области: событие редкое (дроп, постановка, удаление), пересчет дешевый
func _on_terrain_changed(_aabb: AABB) -> void:
	_dirty = true
	_cooldown = 0.0


func on_drag_ended(_d: Dictionary) -> void:
	_dirty = true
	_cooldown = 0.0
	_notify_terrain()   # T5: трак сдвинули, листам пересчитать канаву


## flex поменял форму
func on_curve_changed(_d: Dictionary) -> void:
	_dirty = true
	_cooldown = 0.0


func _exit_tree() -> void:
	_notify_terrain()   # T5: трак убрали, канава под ним больше не нужна


## T5. Сообщает листам, что плоский трак встал, сдвинулся или убран. Область = контур балласта по высоте трака.
## Призраки и траки в драге не сообщают. Удаляемый трак сообщает (TGM.get_flat_tracks его уже не отдаст)
func _notify_terrain() -> void:
	if not is_instance_valid(TGM) or entity == null or not entity.is_inside_tree():
		return
	if entity.has_comp(C_Ghost) or entity.has_comp(C_Drag):
		return
	var path := get_comp(C_Path) as C_Path
	if path == null or not path.is_flat():
		return
	var fp := path.footprint_world()
	if fp.size() < 3:
		return
	var lo := fp[0]
	var hi := fp[0]
	for p in fp:
		lo = lo.min(p)
		hi = hi.max(p)
	var th: float = Global.settings.get_track_height()
	TGM.notify_changed(AABB(Vector3(lo.x, path.bottom_y(), lo.y), Vector3(hi.x - lo.x, th, hi.y - lo.y)))


func on_component_added(_t: Script) -> void:
	_apply_material()


func on_component_removed(_t: Script) -> void:
	_apply_material()


func _physics_process(delta: float) -> void:
	if not entity or not entity.is_inside_tree() or entity.is_queued_for_deletion():
		return
	_cooldown -= delta
	_refresh += delta
	var xf := entity.global_transform
	if not xf.is_equal_approx(_last_entity_xf):
		_last_entity_xf = xf
		_dirty = true
	elif _refresh >= REFRESH_PERIOD:
		_dirty = true
	if not _dirty or _cooldown > 0.0:
		return
	_dirty = false
	_refresh = 0.0
	_cooldown = DRAG_PERIOD
	_rebuild()


func _rebuild() -> void:
	var path := get_comp(C_Path) as C_Path
	if not path or not path.curve or not path.path_node:
		return
	var gs = Global.settings
	var space := entity.get_world_3d().direct_space_state
	var length := path.curve.get_baked_length()
	var n := maxi(1, ceili(length / gs.support_step))
	var inv := entity.global_transform.affine_inverse()
	var xf: Array[Transform3D] = []

	for i in n + 1:
		var t := path.curve.sample_baked_with_rotation(length * i / n)
		var p := path.path_node.to_global(t.origin)          # низ балласта
		var fwd := path.path_node.global_basis * -t.basis.z
		fwd.y = 0.0
		if fwd.length_squared() < 0.0001:
			continue
		var yaw := Basis.looking_at(fwd.normalized(), Vector3.UP)
		var ground := _ground_y(space, p, path)
		if is_nan(ground) or p.y - ground < gs.support_min_clearance:
			continue
		var col_h := p.y - ground - 0.3
		# ригель под балластом
		xf.append(inv * Transform3D(yaw * Basis.from_scale(Vector3(3.0, 0.3, 0.8)), p - Vector3(0, 0.15, 0)))
		# столб
		if col_h > 0.05:
			xf.append(inv * Transform3D(yaw * Basis.from_scale(Vector3(1.0, col_h, 0.8)),
					Vector3(p.x, ground + col_h * 0.5, p.z)))

	if xf == _last_xf:
		return
	_last_xf = xf
	if xf.is_empty() and not _mmi:
		return
	_ensure_nodes()
	var mm := _mmi.multimesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])


## NAN: под нами чужой трак, значит пролет без опоры. Нет попадания: стол (y = 0).
## Лист пенопласта берем еще и аналитически (TGM.surface_y): луч стартует на 0,02 ниже балласта,
## и если балласт заглублен в лист (в пределах underground_tolerance), старт оказывается внутри
## выпуклого шейпа листа, и луч проходит насквозь. Аналитика не зависит от физического кадра
func _ground_y(space: PhysicsDirectSpaceState3D, p: Vector3, path: C_Path) -> float:
	var q := PhysicsRayQueryParameters3D.create(p - Vector3(0, 0.02, 0), p - Vector3(0, 500, 0),
			Global.active_layers(['ground', 'tracks']))
	q.collide_with_areas = true               # балласт это Area3D
	var own: Array[RID] = []
	if path.ballast_node:
		own.append(path.ballast_node.get_rid())
	if path.head_node:
		own.append(path.head_node.get_rid())
	q.exclude = own
	var hit := space.intersect_ray(q)
	var y := 0.0
	if not hit.is_empty():
		var e := _entity_of(hit.collider)
		if e and e != entity and e.has_comp(C_Path):
			return NAN
		y = hit.position.y
	var tol: float = Global.settings.underground_tolerance
	return maxf(y, TGM.surface_y(p.x, p.z, p.y + tol))


func _ensure_nodes() -> void:
	if _mmi:
		return
	_mmi = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BoxMesh.new()                   # единичный бокс, размер задаем scale'ом
	_mmi.multimesh = mm
	_mmi.name = 'Supports'
	entity.add_child(_mmi)
	_apply_material()


func _apply_material() -> void:
	if not _mmi:
		return
	if not _wood:
		_wood = StandardMaterial3D.new()
		_wood.albedo_color = Color(0.62, 0.45, 0.28)
	_mmi.material_override = _wood
	var vis := get_comp(C_TrackVisual) as C_Visual
	var overlay: Material = null
	if vis and vis.visual_settings:
		if has_comp(C_Blocked):
			overlay = vis.visual_settings.blocked_material
		elif has_comp(C_Ghost):
			overlay = vis.visual_settings.ghost_material
	_mmi.material_overlay = overlay


func _entity_of(n: Node) -> Entity:
	while n:
		if n is Entity:
			return n
		n = n.get_parent()
	return null
