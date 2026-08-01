class_name C_TrainDraggable extends IDraggable

##################################
## Библиотека действий. Она живет на объекте всегда.
##################################
## способность двигать ентити вагон, когда включено C_Drag 
## компонент двигает сущность по евенту из ентити
##
## Управление перетаскиванием и посадкой вагона на рельсы

var initial_transform: Transform3D
var drag_offset := Vector3.ZERO
var is_snapped_to_track := false

# Ссылки на текущий трак, если мы над ним
var current_track_entity: Entity = null
var current_curve_offset: float = 0.0


func on_drag_started(_data: Dictionary) -> void:

	initial_transform = entity.global_transform
	
	# Берем смещение по X/Z, чтобы мышь не центрировалась жестко по пивоту вагона
	var raw_offset = entity.global_position - _data.pos
	drag_offset = Vector3(raw_offset.x, 0.0, raw_offset.z)
	
	# TODO: Здесь нужно выключить гравитацию/физику вагона
	# Например: send_event("on_physics_suspend") или дернуть C_Kinematics

func on_drag_moved(_data: Dictionary) -> void:
	printt('3',_data)
	var mouse_pos: Vector3 = _data.pos
	var collider = _data.get("collider") # Ожидаем, что тул передает ноду коллизии
	
	is_snapped_to_track = false
	current_track_entity = null
	
	# 1. Проверяем, над траком ли мы (Слой 3)
	if collider and collider is Area3D:
		var track_entity = _find_entity_from_collider(collider)
		if track_entity and track_entity.has_comp(C_Path):
			_snap_to_track(track_entity, mouse_pos)
			return
			
	# 2. Если мы не над траком, просто тащим вагон по воздуху/земле
	_apply_free_movement(mouse_pos)

func on_drag_ended(_data: Dictionary) -> void:
	if is_snapped_to_track and current_track_entity:
		# Успешная посадка на рельсы
		# Передаем данные в тележки (C_Chassis), чтобы они закрепились на кривой
		entity.send_event("on_train_snapped", {
			"track": current_track_entity,
			"offset": current_curve_offset
		})
	else:
		# Бросили мимо рельсов — включаем физику Godot (RigidBody)
		entity.send_event("on_train_derailed")

# ==========================================
# Логика Снаппинга
# ==========================================

func _snap_to_track(track_entity: Entity, world_mouse_pos: Vector3) -> void:
	var path_comp = track_entity.get_comp(C_Path)
	if not path_comp or not path_comp.path_node:
		_apply_free_movement(world_mouse_pos)
		return
		
	var path_node: Path3D = path_comp.path_node
	var curve: Curve3D = path_comp.curve
	
	# 1. Переводим мировую позицию мыши в локальную систему координат трака
	var local_mouse_pos = path_node.to_local(world_mouse_pos)
	
	# 2. Ищем ближайшую точку на сплайне
	current_curve_offset = curve.get_closest_offset(local_mouse_pos)
	var local_snap_pos = curve.sample_baked(current_curve_offset)
	
	# 3. Возвращаем локальную точку сплайна обратно в мировые координаты
	var world_snap_pos = path_node.to_global(local_snap_pos)
	
	# 4. Получаем вектор направления (касательную) для поворота вагона
	# sample_baked_with_rotation может быть нестабилен на стыках, лучше считать разницу
	var look_offset = clamp(current_curve_offset + 0.1, 0.0, curve.get_baked_length())
	var local_look_pos = curve.sample_baked(look_offset)
	var world_look_pos = path_node.to_global(local_look_pos)
	
	# 5. Применяем трансформацию к сущности вагона
	entity.global_position = world_snap_pos
	
	# Если мы не в самом конце кривой, поворачиваем вагон по направлению рельса
	if world_snap_pos.distance_squared_to(world_look_pos) > 0.001:
		entity.look_at(world_look_pos, Vector3.UP)
		
	is_snapped_to_track = true
	current_track_entity = track_entity

func _apply_free_movement(world_mouse_pos: Vector3) -> void:
	# Свободное таскание над столом. Плюс небольшое поднятие по Y, чтобы показать, что он "в руке"
	entity.global_position = world_mouse_pos + drag_offset + Vector3(0, 1.0, 0)
	# Сбрасываем поворот в ноль (или сохраняем текущий)
	entity.rotation = Vector3.ZERO

# ==========================================
# Хелперы
# ==========================================

func _find_entity_from_collider(node: Node) -> Entity:
	var current = node
	while current:
		if current is Entity:
			return current
		current = current.get_parent()
	return null
	
	
	
	
