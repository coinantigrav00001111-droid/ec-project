class_name C_TrainDraggable extends IDraggable

##################################
## Библиотека действий. Она живет на объекте всегда.
##################################
## способность двигать ентити вагон, когда включено C_Drag 
## компонент двигает сущность по евенту из ентити
##
## Управление перетаскиванием и посадкой вагона на рельсы

var initial_transform: Transform3D
var drag_offset := Vector3.ZERO # Смещение ентити



# Ссылки на текущий трак, если мы над ним
var current_track: Entity = null
var current_curve_point: float = 0.0 # Смещение на кривой
var is_snapped_to_track := false # Флаг привязки к траку
var is_flipped_on_track := false # Флаг: смотрит ли вагон мордой к началу трака


func on_drag_started(_data: Dictionary) -> void:
	initial_transform = entity.global_transform

	var track_h = Vector3(0,  Global.settings.get_track_height() + 0.15, 0) 
	if entity.global_position.y < 0.9:
		drag_offset = Vector3.ZERO + track_h # приподняли на старте повыше трака
	else:
		drag_offset.y = 0.15
	
	# Проверяем, если евент из билд моде, то смещения мыши не будет
	var _build_mode =  true if _data.has('build') and _data.build else false
	if not _build_mode :
		# Берем смещение по X/Z, чтобы мышь не центрировалась жестко по пивоту вагона
		var raw_offset = entity.global_position - _data.position

		# в билд тоже приподняли на старте 
		drag_offset.x = raw_offset.x
		drag_offset.z = raw_offset.z
	
	# ⚡Сигнал в trainvisual о смене слоя
	entity.send_event("on_select_layer", {'enabled':true})
	
	await get_tree().process_frame # Сначала выставляем все, потом вкл физику
	
	#⚡ включаем физику вагона - дернуть C_Kinematics
	entity.send_event("on_is_dragging", {'on':true, 'freeze': false})



func on_drag_moved(_data: Dictionary) -> void:

	var mouse_pos: Vector3 = _data.position
	var collider = _data.get("collider") # Ожидаем, что тул передает ноду коллизии
	
	is_snapped_to_track = false
	current_track = null
	
	# 1. Проверяем, над траком ли мы (Слой 3)
	if collider and (collider.collision_layer == Global.active_layers(['tracks'])):
		var track_entity = _find_entity_from_collider(collider)
		if track_entity :
			_snap_to_track(track_entity, mouse_pos)
			return
			
	# 2. Если мы не над траком, просто тащим ентити по воздуху/земле
	_apply_free_movement(mouse_pos)



func on_drag_ended(_data: Dictionary) -> void:
	if is_snapped_to_track and current_track:
		# Успешная посадка на рельсы
		# Передаем данные в тележки (C_Chassis), чтобы они закрепились на кривой
		entity.send_event("on_train_snapped", {
			"track": current_track,
			"offset": current_curve_point,
			"is_wagon_flipped": is_flipped_on_track # Передаем разворот
		})
	else:
		# Бросили мимо рельсов — включаем физику Godot (RigidBody)
		#entity.send_event("on_train_derailed")
		pass
	
	# Отключаем флаг в физикс
	entity.send_event("on_is_dragging", {'on': false, 'freeze': false})
	rotation_euler = entity.rotation


# Реакция на поворот ентити кнопками
func on_rotate_input(data: Dictionary):
	
	var rad = deg_to_rad(data.amount)
	if data.axis == "y": rotation_euler.y += rad
	if data.axis == "x": rotation_euler.x += rad
	
	# 1. Применяем поворот к  сущности
	entity.global_basis = Basis.from_euler(rotation_euler)
	
	# 2. Отправляем приказ физике подтянуть кузов
	entity.send_event("on_force_rotate_physics", {"basis": entity.global_basis})



func on_lift_input(data: Dictionary):
	# высота драга мышью
	drag_offset.y +=data.step



# ==========================================
# Логика Снаппинга
# ==========================================
### ==========================================
### Логика Снаппинга
### ==========================================

func _snap_to_track(track_entity: Entity, world_mouse_pos: Vector3) -> void:
	var path_comp = track_entity.get_comp(C_Path)
	if not path_comp or not path_comp.path_node or not path_comp.curve:
		_apply_free_movement(world_mouse_pos)
		return

	var path_node = path_comp.path_node
	var curve = path_comp.curve


	# 1. Находим ближайшую точку на кривой в локальных координатах
	var local_mouse_pos = path_node.to_local(world_mouse_pos)
	current_curve_point = curve.get_closest_offset(local_mouse_pos)

	# 2. Получаем Transform3D точки на кривой, чтобы узнать касательную (tangent)
	var curve_point_transform = curve.sample_baked_with_rotation(current_curve_point)
	var global_point_pos = path_node.to_global(curve_point_transform.origin)

	# 3. Вычисляем глобальный вектор направления сплайна. -Z
	var track_forward = (path_node.global_transform.basis * -curve_point_transform.basis.z).normalized()
	
	# 4. Проверяем сонаправленность ТОЛЬКО при первой посадке на трак
	if not is_snapped_to_track or current_track != track_entity: 
		var wagon_forward = -entity.global_transform.basis.z     
		is_flipped_on_track = wagon_forward.dot(track_forward) < 0
		
	# 5. Разворачиваем итоговый вектор привязки, если вагон смотрит назад
	var final_forward = track_forward
	if is_flipped_on_track:
		final_forward = -track_forward

	# 6. Устанавливаем позицию и выравниваем базис (поворот).Прибавляем высоту от drag_offset
	entity.global_position = global_point_pos + Vector3(0,  Global.settings.get_track_height(), 0) 
	
	# Защита от коллинеарности с вектором UP (если рельсы идут строго вертикально)
	if abs(final_forward.dot(Vector3.UP)) < 0.99:
		entity.global_transform.basis = Basis.looking_at(final_forward, Vector3.UP)

	# 7. Отправляем приказ физике подтянуть кузов
	entity.send_event("on_force_rotate_physics", {"basis": entity.global_basis})
	
	# Сохраняем стейт
	current_track = track_entity
	is_snapped_to_track = true




	# Свободное таскание над столом.
func _apply_free_movement(world_mouse_pos: Vector3) -> void:
	# transform не бьет ошибку если ентити не в дереве еще
	#entity.position = world_mouse_pos + drag_offset

	entity.transform.origin = world_mouse_pos + drag_offset
	# 🛠️ Обязательно обнуляем стейт, когда вагон сорвался с рельсов
	is_snapped_to_track = false # 🛠️
	current_track = null        # 🛠️
	
	#get_node('/root/GameRoot/UI/Labeltest').text = 'free'



# ==========================================
# Хелперы
# ==========================================

func _find_entity_from_collider(node: Node) -> Entity:
	var current = node
	while current:
		if current is Entity: return current
		current = current.get_parent()
	return null
	
	## --- Блок синхронизации состояния (Клонирование) ---

var rotation_euler := Vector3.ZERO # Храним тут, чтобы не терять при смене тулзов

# Вызывается у Госта в момент клонирования(отдаем данные). см build_tool 
func on_clone_state_to(_data: Dictionary) -> void:
	var target_entity: Entity = _data.target
	#rotation_euler = target_entity.global_transform.basis.get_euler()
	# Гост кричит в новую сущность: "Прими мои настройки драга!"
	target_entity.send_event("on_receive_draggable_state", {
		"global_transform": target_entity.global_transform
		})


# Вызывается у Реального объекта в момент клонирования (принимаем данные). см build_tool 
func on_receive_draggable_state(data: Dictionary) -> void:
	if data.has("global_transform"):
		entity.global_transform = data.global_transform


	
	
