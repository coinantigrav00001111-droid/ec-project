class_name C_Chassis extends ICapability

####################
## Способность, Библиотека действий. Она живет на объекте всегда.
####################
## Читает Curve3D трака и вычисляет свои координаты на сплайне.
## Cчитается позиция Вагон как "хорда" на кривой. Запрашивает у кривой трака две точки:
## distance_travelled + front_bogie_offset (Позиция передних колес).
## distance_travelled + rear_bogie_offset (Позиция задних колес).
## Центр вагона (global_position Entity) = Середина между этими двумя точками (Front + Rear) / 2.
## Поворот вагона (Basis/LookAt) = Вектор направления от задней тележки к передней.


var front_bogie_offset: float = 2.5 # Расстояние от центра до передней тележки
var rear_bogie_offset: float  = -2.5 # Расстояние от центра до задней тележки

# Тело вагона
var rb :RigidBody3D
var current_track: Entity = null
var current_spline_offset: float = 0.0 # Смещение.точка на сплайне
var is_on_rails: bool = false
var is_flipped := false


# --- Новые переменные для движения ---
var current_speed: float = 0.0       # Текущая скорость вдоль сплайна
var current_velocity_3d: Vector3 = Vector3.ZERO # Чистая скорость вагона в пространстве 
var friction_decel: float = 0.5      # Затухание скорости (трение)



func on_added():
	rb = get_comp(C_TrainVisual).instance
	pass



# Слушаем событие пинка
func on_train_kicked(data: Dictionary) -> void:
	if not is_on_rails:		return
	
	var power = data.get("power", 0.0)
	# Если вагон перевернут относительно сплайна, инвертируем скорость качения
	if is_flipped:
		current_speed -= power
	else:
		current_speed += power




'''
в повер траке есть это:
# разворот пути относительно эталонного(клип-трак - эталон)
var is_flipped :bool = false 
'''


func _physics_process(delta: float) -> void:
	if not is_on_rails or not is_instance_valid(current_track):
		entity.send_event('on_speed_changed', {'speed': 0.0})
		return

	var path_comp = current_track.get_comp(C_Path)
	if not path_comp or not path_comp.curve or not path_comp.path_node:
		return

	if current_speed != 0.0:
		#var movement_direction = -1.0 if is_flipped else 1.0
		current_spline_offset += current_speed * delta
		current_speed = move_toward(current_speed, 0.0, friction_decel * delta)

	if current_speed == 0.0:
		return

	var track_length = path_comp.curve.get_baked_length()

	# 1. ПРОВЕРЯЕМ ПЕРЕХОД ЦЕНТРА НА НОВЫЙ ТРАК
	if current_spline_offset > track_length:
		if not _try_switch_track(true, track_length): return
	elif current_spline_offset < 0.0:
		if not _try_switch_track(false, track_length): return

	# 2. ВЫЧИСЛЯЕМ ПОЗИЦИИ ТЕЛЕЖЕК (они могут быть на разных траках!)
	var front_global = _get_bogie_global_pos(current_track, current_spline_offset + front_bogie_offset)
	var rear_global = _get_bogie_global_pos(current_track, current_spline_offset + rear_bogie_offset)

	# Если функция вернула INF, значит тележка съехала в пустоту -> СХОД С РЕЛЬС
	if front_global == Vector3.INF or rear_global == Vector3.INF:
		entity.send_event("on_derailed", {})
		return

# 3. ВЫЧИСЛЯЕМ 3D-ВЕКТОР ДВИЖЕНИЯ ВДОЛЬ ТРАКА
	var track_dir = (front_global - rear_global).normalized()
	# Чистая скорость вагона в пространстве (куда бы он ни смотрел)
	current_velocity_3d = track_dir * current_speed
	
	
	# 3. ДВИГАЕМ КУЗОВ
	var base_pos = (front_global + rear_global) / 2.0
	var track_h = Vector3(0, Global.settings.get_track_height(), 0) 
	entity.global_position = base_pos + track_h
	
	# 5. ПОВОРАЧИВАЕМ КУЗОВ С УЧЕТОМ IS_FLIPPED
	if front_global.distance_to(rear_global) > 0.001:
		var up_vec = path_comp.path_node.global_transform.basis.y
		# Если вагон развернут, его нос смотрит противоположно вектору трака
		var wagon_forward = -track_dir if is_flipped else track_dir
		
		entity.global_transform.basis = Basis.looking_at(wagon_forward, up_vec)
	## TODO Если когда-нибудь в игре появятся рельсы, идущие под горку (наклонные сплайны), вагоны начнут визуально "проседать" в рельс. В таком случае нужно будет прибавлять высоту вдоль локального вектора UP самого трака: path_comp.path_node.global_transform.basis.y * suspension_height)
	

	# Убеждаемся, что кузов отвязан от ентити
	if not rb.top_level: rb.top_level = false

	if is_on_rails:	# ФИЗИЧЕСКИЙ ДРАГ: RigidBody догоняет Entity (курсор)
		rb.global_transform = entity.global_transform




# ==========================================
# ХЕЛПЕРЫ ДЛЯ ПЕРЕХОДА ПО ТРАКАМ
# ==========================================
	
func _try_switch_track(is_exiting_end: bool, current_length: float) -> bool:
	var socket_comp = current_track.get_comp(C_Socket)
	var next_track = socket_comp.get_neighbor_at(is_exiting_end) if socket_comp else null
	
	if not is_instance_valid(next_track):
		entity.send_event("on_derailed", {})
		return false
		
	# Выясняем, как пристыкован новый трак (поляризация)
	var next_path = next_track.get_comp(C_Path)
	var next_start_pos = next_path.path_node.to_global(next_path.curve.sample_baked(0.0))
	var path_comp = current_track.get_comp(C_Path)
	var exit_pos = path_comp.path_node.to_global(path_comp.curve.sample_baked(current_length if is_exiting_end else 0.0))
	
	var entered_from_start = exit_pos.distance_to(next_start_pos) < 0.1
	var next_length = next_path.curve.get_baked_length()
	
	# Бесшовно переносим стейт с учетом разворота рельсов
	if is_exiting_end: 
		if entered_from_start:
			current_spline_offset -= current_length
		else:
			current_spline_offset = next_length - (current_spline_offset - current_length)
			is_flipped = not is_flipped
			current_speed = -current_speed
	else: 
		if entered_from_start:
			current_spline_offset = -current_spline_offset
			is_flipped = not is_flipped
			current_speed = -current_speed
		else:
			current_spline_offset = next_length + current_spline_offset
			
	current_track = next_track
	return true



func _get_bogie_global_pos(base_track: Entity, offset: float) -> Vector3:
	var path_comp = base_track.get_comp(C_Path)
	var track_length = path_comp.curve.get_baked_length()

	if offset >= 0.0 and offset <= track_length:
		return path_comp.path_node.to_global(path_comp.curve.sample_baked(offset))

	# Тележка за краем - ищем её на соседе
	var is_exiting_end = offset > track_length
	var socket_comp = base_track.get_comp(C_Socket)
	var next_track = socket_comp.get_neighbor_at(is_exiting_end) if socket_comp else null
	
	if not is_instance_valid(next_track):
		return Vector3.INF
		
	var next_path = next_track.get_comp(C_Path)
	var next_start_pos = next_path.path_node.to_global(next_path.curve.sample_baked(0.0))
	var exit_pos = path_comp.path_node.to_global(path_comp.curve.sample_baked(track_length if is_exiting_end else 0.0))
	
	var entered_from_start = exit_pos.distance_to(next_start_pos) < 0.1
	var remaining_offset = offset - track_length if is_exiting_end else -offset
	
	var final_offset = remaining_offset if entered_from_start else next_path.curve.get_baked_length() - remaining_offset
	return next_path.path_node.to_global(next_path.curve.sample_baked(final_offset))
	






## ===================================================
func on_drag_started(_data: Dictionary) -> void:
	# Как только игрок схватил вагон, отключаем математику рельс и сбрасываем скорость
	is_on_rails = false
	current_speed = 0.0
	

	
#"track","offset","is_flipped"
# Ловит евент от C_TrainDraggable при успешном дропе на рельс
func on_train_snapped(data: Dictionary) -> void:
	
	current_track = data.get("track")
	current_spline_offset = data.get("offset", 0.0) # Смещение на сплайне
	is_on_rails = true
	is_flipped = data.is_flipped 
	
	## Выключаем физику Godot, отдаемся математике
	if rb:
		await  get_tree().process_frame
		rb.freeze = true


# Если это Локомотив, скорость будет приходить от C_Engine.
# Если вагон — от C_Coupler (тяга соседнего вагона).
func on_speed_changed(data: Dictionary) -> void:
	current_speed = data.get("speed", 0.0)
	#_check_derailment()
	
	"""где on_speed_changed должна быть!"""
	
# Событие схода с рельс (от C_Kinematics или столкновения)
func on_derailed(_data: Dictionary) -> void:
	printt ('derailed')
	if not is_on_rails: return
	is_on_rails = false
	current_track = null
	
	# Отвязываемся от сплайна
	if rb:
		rb.freeze = false
