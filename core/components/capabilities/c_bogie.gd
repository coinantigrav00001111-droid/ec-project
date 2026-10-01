class_name C_Bogie extends ICapability

class BogieData:
	var id: int
	var config: BogieConfig 	# конфиг конкретного боги из identity
	var pivot: Node3D              # Корневая нода тележки (из сцены)
	var raycast: RayCast3D          # Датчик рельса под тележкой
	var current_track: Entity
	var track_distance: float = 0.0
	var calculated_global_pos: Vector3
	var calculated_global_basis: Basis
	#var is_front: bool = false # уже не надо

var is_derailed: bool = false






# Сами боги, их id, конфиги из TrainVisual перекидываются сюда
var bogies_data: Array[BogieData] = []


func on_added() -> void:
	#Собираем массив данных боги
	var identity = entity.get_comp(C_Identity)
	var bogie_configs
	if identity:
		bogie_configs = identity.get_config('bogie_configs')	

	# Принимаем контроль боги из визуала
	var comp = entity.get_comp(C_TrainVisual)
	var bogie_nodes = comp.bogie_nodes
	
	# Формируем массив данных боги 
	for i in range(bogie_nodes.size()):
		var bogie = bogie_nodes[i]
		_create_bogies_data(i, bogie_configs[i], bogie)
	
	# Сортировка от первой тележки к последней
	bogies_data.sort_custom(func(a, b): return a.pivot.position.z < b.pivot.position.z)



func _create_bogies_data(_id: int, _config: BogieConfig, bogie:Node3D) -> void:
	
	var data = BogieData.new()
	data.id = _id
	data.config = _config
	data.pivot = bogie
	data.raycast = bogie.get_node('RayCast3D')
	#data.is_front = bogie.position.z < 0.0
	data.calculated_global_pos = bogie.position

	bogies_data.append(data)


# ==========================================
# ПУБЛИЧНЫЙ ИНТЕРФЕЙС / API
# ==========================================
#"track","offset","is_flipped"
# Вызывается из шасси при посадке вагона на рельс. Готовит данные боги дата к снапу вагона
# Возвращает массив расчетных позиций боги Первая - фронт, последняя - реар
func set_track_to_bogies_data(track_data: Dictionary, w_flipped: bool) -> Dictionary:
	is_derailed = false
	var track = track_data.get("track")
	var offset = track_data.get("offset", 0.0)
	
	if not is_instance_valid(track) or not track.has_comp(C_Path): return {}
		
	var path_comp = track.get_comp(C_Path)
	var curve_len = path_comp.curve.get_baked_length()
	
	for bogie in bogies_data:
		bogie.current_track = track
		
		# Если вагон посажен мордой против сплайна (w_flipped = true), 
		# передняя тележка (у которой Z < 0) должна оказаться ближе к началу сплайна (0.0).
		var placement_dir = 1.0 if w_flipped else -1.0
		var initial_dist = offset + (bogie.pivot.position.z * placement_dir)
		
		bogie.track_distance = clampf(initial_dist, 0.0, curve_len)
		
		# Сразу обновляем глобальные позиции (с учетом словаря из прошлого шага)
		_assist_update_calc_global_pos(bogie)# , w_flipped) 
		
	# Возвращаем словарь крайних точек для хорды
	if bogies_data.size() > 0:
		return {
			"front": bogies_data.front().calculated_global_pos,
			"rear": bogies_data.back().calculated_global_pos
		}
	return {}




## Главный шаг расчета позиций в physics_process
# Не используется - is_w_flipped - разворот вагона по отношению к траку не имеет значения - он будет двигаться по полярности питания. 
# Направление расчитывается от флипа трака относительно направления питания контура
func calculate_next_positions(delta: float, speed: float)  -> Dictionary:#, is_w_flipped: bool)  -> Dictionary:
	var bogies_pos = {}
	#var bogies_pos = [] # массив расчетных позиций боги
	if is_derailed: return bogies_pos
	
	for bogie in bogies_data:
		_assist_move_bogie(bogie, delta, speed)
		_assist_check_transition(bogie)
		_assist_update_calc_global_pos(bogie)

	# Независимо от того, 2 оси у нас или 5, кузов строится по первой и последней:
	return {
		"front": bogies_data.front().calculated_global_pos,
		"rear": bogies_data.back().calculated_global_pos
		}




# ==========================================
# ВСПОМОГАТЕЛЬНЫЕ АССИСТ-ФУНКЦИИ (HELPERS)
# ==========================================

## Математический шаг по сплайну с учетом is_flipped трака
func _assist_move_bogie(bogie: BogieData, delta: float, speed: float) -> void:
	if not is_instance_valid(bogie.current_track): return
	# Формула: 
	# 1️⃣ если вагон развернут, локальное смещение тележки НЕ инвертируется относительно сплайна
	# 2️⃣ если трак  развернут, локальное смещение тележки инвертируется относительно сплайна
	# Разворот трака держит C_PowerTrack
	var power_track = bogie.current_track.get_comp(C_PowerTrack)

	# Учитываем инверсию  трака 
	var  dir_sign = 1.0
	if power_track:
		dir_sign =-1.0 if power_track.is_flipped else 1.0
		
	bogie.track_distance += speed * delta * dir_sign 




#### Резервный переход через границы/сокеты (если рейкаст на мгновение потерял рельс)
func _assist_check_transition(bogie: BogieData) -> void:
	if not is_instance_valid(bogie.current_track): return
	
	var path_comp = bogie.current_track.get_comp(C_Path)
	var curve_len = path_comp.curve.get_baked_length()

	# 1. Тележка в пределах текущего сплайна — переход не нужен
	if bogie.track_distance >= 0.0 and bogie.track_distance <= curve_len:
		return 
	
	# 2. Вычисляем "перебег" (overflow) в зазоре
	var is_exiting_end = bogie.track_distance > curve_len
	var overflow = bogie.track_distance - curve_len if is_exiting_end else bogie.track_distance
	
	# 3. Получаем крайнюю точку и глобальный вектор вылета (касательную)
	var edge_offset = curve_len if is_exiting_end else 0.0
	
	
	var edge_transform = path_comp.curve.sample_baked_with_rotation(edge_offset)
	var edge_global_pos = path_comp.path_node.to_global(edge_transform.origin)
	
	# В Godot вперед - это -Z
	var global_forward = (path_comp.path_node.global_basis * -edge_transform.basis.z).normalized()
	if not is_exiting_end:
		global_forward = -global_forward # Инвертируем, если вылетели с нулевой отметки
		
	# Экстраполируем глобальную позицию тележки в воздухе над зазором
	var extrapolated_pos = edge_global_pos + (global_forward * abs(overflow))

	# 4. Стреляем рейкастом для поиска нового рельса
	if is_instance_valid(bogie.raycast):
		# Смещаем луч чуть вперед по вектору, чтобы "перепрыгнуть" пустоту зазора (~0.2)
		var look_ahead_pos = extrapolated_pos + (global_forward * 0.1)
		
		var sensor_pos = bogie.raycast.global_position
		bogie.raycast.global_position = look_ahead_pos + Vector3(0, sensor_pos.y, 0) # Ставим над рельсом
		#bogie.raycast.target_position = Vector3(0, -1.0, 0)
		bogie.raycast.force_raycast_update()

		if bogie.raycast.is_colliding():
			var hit_entity = _find_entity_from_collider(bogie.raycast.get_collider())
			
			# Если нащупали новый трак
			if is_instance_valid(hit_entity) and hit_entity != bogie.current_track and hit_entity.has_comp(C_Path):
				var next_path = hit_entity.get_comp(C_Path)
				
				# Переводим глобальную точку полета в локальную систему нового трака
				var local_hit_pos = next_path.path_node.to_local(extrapolated_pos)
				
				# Проецируем на новую кривую. Это автоматически решает все стыки (1-0, 0-1)
				bogie.current_track = hit_entity
				bogie.track_distance = next_path.curve.get_closest_offset(local_hit_pos)
				return
	
	# 5. Если улетели за пределы толерантности зазора (0.4м) и ничего не нащупали — дерейл
	if abs(overflow) > 0.4:
		is_derailed = true



#### Получение глобальной координаты на сплайне с поддержкой экстраполяции над зазором
func _assist_sample_pos_with_extrapolation(path_comp: C_Path, distance: float, curve_len: float) -> Vector3:
	if distance >= 0.0 and distance <= curve_len:
		var transform_baked = path_comp.curve.sample_baked_with_rotation(distance)
		return path_comp.path_node.to_global(transform_baked.origin)
	else:
		var is_exiting_end = distance > curve_len
		var overflow = distance - curve_len if is_exiting_end else distance
		var edge_offset = curve_len if is_exiting_end else 0.0
		
		var edge_transform = path_comp.curve.sample_baked_with_rotation(edge_offset)
		var edge_global_pos = path_comp.path_node.to_global(edge_transform.origin)
		
		var global_forward = (path_comp.path_node.global_basis * -edge_transform.basis.z).normalized()
		if not is_exiting_end:
			global_forward = -global_forward
			
		return edge_global_pos + (global_forward * abs(overflow))



#### Обновление позиций и доворот (YAW) ноды тележки по хорде колесных пар
func _assist_update_calc_global_pos(bogie: BogieData) -> void:
	if not is_instance_valid(bogie.current_track): return
	
	var path_comp = bogie.current_track.get_comp(C_Path)
	var curve_len = path_comp.curve.get_baked_length()
	var track_h = bogie.current_track.get_comp(C_Identity).get_config('height', 0.0)
	var wp_z = bogie.config.wheel_pair_position.z  if bogie.config else 0.0
	
	if wp_z > 0.001:
		# Двухосная тележка: считаем крайние точки колесных пар (front/rear)
		var front_pos = _assist_sample_pos_with_extrapolation(path_comp, bogie.track_distance + wp_z, curve_len)
		var rear_pos = _assist_sample_pos_with_extrapolation(path_comp, bogie.track_distance - wp_z, curve_len)
		
		# Центр тележки — точка посередине между осями
		bogie.calculated_global_pos = (front_pos + rear_pos) / 2.0
		bogie.calculated_global_pos.y += track_h
		
		# Поворот pivot тележки строго по вектору между осями
		var forward_dir = (front_pos - rear_pos).normalized()
		if is_instance_valid(bogie.pivot) and forward_dir.length_squared() > 0.001:
			bogie.pivot.global_basis = Basis.looking_at(forward_dir, Vector3.UP)
	else:
		# Одноосная тележка: расчет по центральной точке
		bogie.calculated_global_pos = _assist_sample_pos_with_extrapolation(path_comp, bogie.track_distance, curve_len)
		bogie.calculated_global_pos.y += track_h
		
		if is_instance_valid(bogie.pivot):
			var transform_baked = path_comp.curve.sample_baked_with_rotation(clampf(bogie.track_distance, 0.0, curve_len))
			var global_forward = (path_comp.path_node.global_basis * -transform_baked.basis.z).normalized()
			if global_forward.length_squared() > 0.001:
				bogie.pivot.global_basis = Basis.looking_at(global_forward, Vector3.UP)



func _find_entity_from_collider(collider: Node) -> Entity:
	var curr: Node = collider
	while curr:
		if curr is Entity: return curr as Entity
		curr = curr.get_parent()
	return null
#
