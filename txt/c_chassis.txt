class_name C_Chassis extends ICapability

############################################
## Отвечает за поведение вагона на сплайне
#############################################
# Тело вагона
var rb: RigidBody3D 

var snapped_track: Entity
var current_spline_offset: float = 0.0
var current_speed: float = 0.0
var current_velocity_3d: Vector3 = Vector3.ZERO #скорость вагона в пространстве
var is_on_rails: bool = false # Вагон на рельсах
var is_w_flipped: bool = false # вагон развернут по траку или или нет

# Для дебага вынес в корень, достаточно и в _check_derailment
var centrifugal_force: float

# Значения из инспектора
var bogie_configs: Array[BogieConfig] = []


func on_added():
	rb = get_comp(C_TrainVisual).instance

# ==========================================
# ОБРАБОТКА СОБЫТИЙ
# ==========================================

#track_data: "track"- сам трак,"offset" смещение по сплайну ,"is_flipped" - разворот трака в контуре
# Ловит евент от C_TrainDraggable при успешном дропе на рельс

func on_train_snapped(track_data: Dictionary) -> void:
	snapped_track = track_data.get("track")
	current_spline_offset = track_data.get("offset", 0.0)
	
	# === ВЫЧИСЛЯЕМ is_w_flipped НА МЕСТЕ ===
	#printt(track_data)
	var path_comp = snapped_track.get_comp(C_Path) #if snapped_track else null 
	if path_comp and path_comp.curve:
		# Получаем вектор касательной сплайна в точке посадки
		var curve_transform = path_comp.curve.sample_baked_with_rotation(current_spline_offset)
		var track_forward = (path_comp.path_node.global_basis * -curve_transform.basis.z).normalized()
		
		# Берем текущий вектор морды вагона (который нам выставил драг-тул)
		var wagon_forward = -entity.global_basis.z
		
		# Если вектора смотрят навстречу друг другу — вагон перевернут
		is_w_flipped = wagon_forward.dot(track_forward) < 0
	else:
		is_w_flipped = false

	is_on_rails = true
	
	var bogie_comp = entity.get_comp(C_Bogie)
	if not bogie_comp: 	return
		
	#  Синхронизируем тележки с точкой снапа. Вернется массив с правильными позициями боги
	var b_calc_pos = bogie_comp.set_track_to_bogies_data(track_data, is_w_flipped)
	
	# Обновляем позицию вагона по рассчитанным позициям боги
	if b_calc_pos.is_empty(): 
		return
		
	var front_calc_pos = b_calc_pos.front
	var rear_calc_pos = b_calc_pos.rear

	if front_calc_pos != Vector3.ZERO and rear_calc_pos != Vector3.ZERO:
		entity.global_position = (front_calc_pos + rear_calc_pos) / 2.0

	if rb:
		_assist_rb_to_entity()
		await get_tree().process_frame
		rb.freeze = true
		rb.linear_damp = 2.5
		rb.angular_damp = 2.5



## Как только игрок схватил вагон, отключаем математику рельс и сбрасываем скорость
func on_drag_started0(_data: Dictionary) -> void:
	is_on_rails = false
	current_speed = 0.0



## Слушаем событие пинка
func on_train_kicked0(data: Dictionary) -> void:
	if not is_on_rails: return
	
	var power_kick = data.get("power_kick", 0.0)  * 2 # просто сила пинка
	
	# пинок в попу зависит от установки на траке
	var _sign_power = -1 if is_w_flipped else 1
	
	# смена скорости на рельсах делается здесь, событие не нужно!
	var new_speed = current_speed + _sign_power * power_kick 
	
	# TODO Пересчитывать надо связку roll_resistance, mass, friction, K_DAMP в шасси.
	# при _k =5 и friction = 0.01 движения в шасси и кинемат совпадают!
	on_speed_changed({"speed": new_speed})




### ==========================================
### НОВЫЕ ПЕРЕМЕННЫЕ ДЛЯ СИЛОВОЙ ПАРАДИГМЫ
### ==========================================
var applied_force: float = 0.0  # Постоянная приложенная сила/тяга (от C_Engine или C_Coupler), Н
var impulse_force: float = 0.0  # Разовый импульс силы (от пинка/удара), Н


### ==========================================
### ОБРАБОТКА СОБЫТИЙ СИЛ И ПИНКА
### ==========================================

#### Приём суммарной силы тяги от C_Engine или сцепки C_Coupler
#### Вместо прямой установки скорости теперь принимаем силу в Ньютонах
func on_force_changed(data: Dictionary) -> void:
	applied_force = data.get("force", 0.0)



#### Приём пинка: превращаем силу пинка в разовый импульс силы, а не меняем скорость напрямую
func on_train_kicked(data: Dictionary) -> void:
	if not is_on_rails: 
		return

	var power_kick = data.get("power_kick", 0.0) * 2.0 # Сила пинка
	var _sign_power = -1.0 if is_w_flipped else 1.0

	# Накапливаем импульсную силу, которая применится на ближайшем физическом кадре
	impulse_force += _sign_power * power_kick


#### Сбрасываем накопленные силы при отпускании вагона/старте драга
func on_drag_started(_data: Dictionary) -> void:
	is_on_rails = false
	current_speed = 0.0
	applied_force = 0.0
	impulse_force = 0.0


### ==========================================
### ИНТЕГРАЦИЯ СИЛ И РАСЧЁТ УСКОРЕНИЯ (ФИЗИКА)
### ==========================================

#### Переработанная функция расчёта динамики вагона по II закону Ньютона:
#### a = F_net / m  =>  v = v0 + a * dt
func _assist_speed_correction(delta: float) -> void:
	#var mass = get_wagon_props('mass')
	var mass = rb.mass
	if mass <= 0.0:
		mass = 1.0 # Защита от деления на ноль

	var gravity = 9.8
	var roll_res = get_wagon_props('roll_resistance')

	var incline_factor = 0.0 # Заглушка для уклона сплайна (sin угла)
	# 1. Складываем активные внешние силы (постоянную тягу и разовый импульс)
	var active_force = applied_force + (impulse_force / delta if delta > 0.0 else 0.0)
	impulse_force = 0.0 # Сбрасываем разовый импульс после применения
	#printt('active_force=',active_force)
	
	# 2. Определяем направление движения / сопротивления
	var movement_sign = sign(current_speed)
	if movement_sign == 0.0:
		movement_sign = sign(active_force) # Если стоим, сопротивление направлено против тяги

	# 3. Расчёт сил сопротивления (в Ньютонах)
	# F_friction = m * g * roll_resistance
	var friction_force = mass * gravity * roll_res * movement_sign
	# F_incline = m * g * incline_factor
	var incline_force = mass * gravity * incline_factor

	# 4. Итоговая равнодействующая сила: F_net = F_active - F_friction - F_incline
	var net_force = active_force - friction_force - incline_force

	# 5. Обработка состояния покоя (если сила тяги не преодолевает трение покоя, вагон стоит)
	if abs(current_speed) < 0.01 and abs(active_force) <= abs(friction_force):
		current_speed = 0.0
		return

	# 6. Расчёт ускорения: a = F / m
	var acceleration = net_force / mass

	# 7. Численное интегрирование скорости: v1 = v0 + a * dt
	var new_speed = current_speed + acceleration * delta

	# 8. Защита от "проскакивания" через 0 при торможении только силой трения
	if movement_sign != 0.0 and sign(new_speed) != movement_sign and abs(active_force) < abs(friction_force):
		current_speed = 0.0
	else:
		current_speed = new_speed
		
		
##################################################
##################################################






## Если это Локомотив, скорость будет приходить от C_Engine.
## Если вагон — от пинка выше или C_Coupler (тяга соседнего вагона).
func on_speed_changed(data: Dictionary) -> void:
	current_speed = data.get("speed", 0.0)
	_check_derailment() # проверка схода



## Проверка схода. Такая же есть в кинематикс, зачем?
func _check_derailment() -> void:
	if  not is_on_rails: return
		
	var bogie_comp = entity.get_comp(C_Bogie)
	if not bogie_comp or bogie_comp.bogies_data.is_empty(): return
		
	# Берем переднюю тележку для проверки
	var front_bogie = bogie_comp.bogies_data[0]
	var actual_track = front_bogie.current_track
	
	# СЦЕНАРИЙ 1.1: Рельсы кончились
	if not is_instance_valid(actual_track):
		entity.send_event("on_derailed", {"reason": "end_of_track", "current_velocity_3d": current_velocity_3d})
		return
		
	# СЦЕНАРИЙ 1.2: Нет пути
	var path_comp = actual_track.get_comp(C_Path)
	if not path_comp: 
		entity.send_event("on_derailed", {"reason": "no_path", "current_velocity_3d": current_velocity_3d})
		return # отсутствие ноды path это сход
	
	# --- НОВЫЙ СЦЕНАРИЙ 1.5: Непроходимый (слишком крутой) радиус ---
	# Проверяем, не является ли трак кривой, и есть ли у нее радиус
	if abs(path_comp.deg) > 0.01:
		var min_allowed_radius = get_wagon_props('min_curve_radius')

		# Если радиус рельса меньше минимально допустимого для вагона
		if path_comp.radius < min_allowed_radius:
			entity.send_event("on_derailed", {"reason": "tight_curve", "radius": path_comp.radius, "current_velocity_3d": current_velocity_3d})
			return
			
	# Если угол поворота близок к нулю (прямая), сход от центробежной силы невозможен
	if abs(path_comp.deg) < 0.01: 
		centrifugal_force = 0.0
		return

	# СЦЕНАРИЙ 2: Превышение скорости в повороте, если реборда не держит центробежную силу - сход	
	# Формула центробежной силы из архитектуры: F = (m * v^2) / r
	centrifugal_force = (get_wagon_props('mass') * pow(current_speed, 2)) / path_comp.radius
	
	if centrifugal_force > get_wagon_props('max_grip'):
		entity.send_event("on_derailed", {"reason": "hi speed", "force": centrifugal_force, "current_velocity_3d": current_velocity_3d})
		return




# Событие схода с рельс. Здесь определяем флаги шасси. В кинематикс сделает физику
func on_derailed(_data: Dictionary) -> void:
	
	if not is_on_rails: return
	is_on_rails = false
	snapped_track = null



# ==========================================
# ФИЗИЧЕСКИЙ ЦИКЛ
# ==========================================
func _physics_process(delta: float) -> void:
	if not is_on_rails: return

	var bogie_comp = entity.get_comp(C_Bogie)
	if not bogie_comp: return
	
	# 1. Проверяем состояние тележек на рельсах
	if bogie_comp.is_derailed:
		entity.send_event("on_derailed", {"reason": "bogie derailed", "current_velocity_3d": current_velocity_3d})
		return
		
	# 2. Проверяем состояние вагона в движении
	_check_derailment() 
	_assist_speed_correction(delta)

	# 3. Заставляем тележки пересчитать позиции
	var b_calc_pos = bogie_comp.calculate_next_positions(delta, current_speed)#, is_w_flipped)
	var front_calc_pos = b_calc_pos["front"]
	var rear_calc_pos = b_calc_pos["rear"]

	# 4. Обновляем актуальный трак 	
	for bogie_data in bogie_comp.bogies_data:
		snapped_track = bogie_data.current_track
		if bogie_data.current_track: 
			continue

		
	
		
	if front_calc_pos == Vector3.ZERO or rear_calc_pos == Vector3.ZERO:
		entity.send_event("on_derailed", {"reason": "front end calc_pos failed", "current_velocity_3d": current_velocity_3d})
		return

	# Запоминаем позицию до перемещения
	var previous_pos = entity.global_position

	# 3. Позиционируем вагон как хорду (по центру между тележками)
	entity.global_position = (front_calc_pos + rear_calc_pos) / 2.0

	# Вычисляем фактический вектор 3D-скорости
	if delta > 0.0:
		current_velocity_3d = (entity.global_position - previous_pos) / delta

	# 4. ПОВОРОТ КУЗОВА: вычисляем направляющий вектор от задней к передней
	var forward_dir = (front_calc_pos - rear_calc_pos).normalized()
	
	# Защита от схлопывания точек (если дистанция вдруг стала нулевой)
	if forward_dir.length_squared() > 0.001:
		# Выравниваем локальный -Z (морду) по вектору движения
		entity.global_basis = Basis.looking_at(forward_dir, Vector3.UP)
	
	# 5. Подтягиваем ригид к ентити
	_assist_rb_to_entity()
	
	#printt(is_w_flipped)


# ==========================================
# ВСПОМОГАТЕЛЬНЫЕ АССИСТ-ФУНКЦИИ (HELPERS)
# ==========================================
func _assist_speed_correction0(delta: float) -> void:
	if abs(current_speed) < 0.01:
		current_speed = 0.0
		return
		
	var roll_res = get_wagon_props('roll_resistance') # Добавить в C_Chassis по аналогии с mass
	var gravity = 9.8 # Константа проекта
	var incline_factor = 0.0 # Заглушка для уклона сплайна (позже берем из Y-вектора трака)
	
	# Расчет ускорения (замедления)
	var deceleration = (roll_res * gravity) + (incline_factor * gravity)
	var speed_sign = sign(current_speed)
	
	# Отнимаем скорость, но не позволяем ей перевернуться через ноль
	var new_speed = abs(current_speed) - (deceleration * delta)
	current_speed = max(0.0, new_speed) * speed_sign
	
	
	
# ФИЗИЧЕСКИЙ ДРАГ: RigidBody догоняет Entity (курсор)
func _assist_rb_to_entity() -> void:
	# Убеждаемся, что кузов отвязан от ентити
	if not rb.top_level: rb.top_level = false

	if is_on_rails:	
		rb.global_transform = entity.global_transform


	
	
# Получаем массу вагона из кинематикс(или откуда надо)
func get_wagon_props(_p: String) -> float:
	var _res = null
	match _p:
		'mass' :_res = entity.get_comp(C_Kinematics).mass
		'max_grip' :_res = entity.get_comp(C_Kinematics).max_grip
		'roll_resistance' : _res = entity.get_comp(C_Kinematics).roll_resistance
		# Добавляем новые:
		'longitudinal_grip': _res = entity.get_comp(C_Kinematics).longitudinal_grip
		'min_curve_radius': _res = entity.get_comp(C_Kinematics).min_curve_radius
		'max_tractive_force': _res = entity.get_comp(C_Kinematics).max_tractive_force
		'max_theoretical_speed': _res = entity.get_comp(C_Kinematics).max_theoretical_speed
	return _res



func save_data() -> Dictionary:
	return {
		'comp_path':get_script().resource_path,		# "res://core/components/c_power_clip.gd"
		'comp_name':get_script().resource_path.get_file().get_basename(),
		#'snapped_track': snapped_track,
		'current_spline_offset':current_spline_offset,
		#'is_on_rails':is_on_rails, # Вагон на рельсах
		#'is_w_flipped':is_w_flipped # вагон развернут по траку или или нет
	}



func load_data(_data: Dictionary) -> void:
	# Только смещение на сплайне, остальное вычисляется при спавне
	if _data.has("current_spline_offset"):
		current_spline_offset = _data.current_spline_offset



## Вызывается из SaveManager после того, как все объекты расставлены
func restore_snap_after_load() -> void:
	
	var bogie_comp = entity.get_comp(C_Bogie) as C_Bogie
	if not bogie_comp or bogie_comp.bogies_data.is_empty():
		return
		
	# Берем датчик (RayCast3D) первой тележки
	var first_bogie = bogie_comp.bogies_data[0]
	first_bogie.raycast.force_raycast_update() # Принудительно обновляем луч

	if first_bogie.raycast.is_colliding():
		var collider = first_bogie.raycast.get_collider()
		var track_entity = _find_entity_from_collider(collider)
		
		# Имитируем успешный дроп на рельс, используя сохраненный оффсет
		#вар1
		if track_entity:
			
			on_train_snapped({
				"track": track_entity,
				"offset": current_spline_offset
			})
	
		# вар 2  он не работает
		#var drag_comp = entity.get_comp(C_TrainDraggable)
		#if drag_comp and track_entity:
			#drag_comp._snap_to_track(track_entity, entity.global_position)




### Хелпер для подъема по дереву (такой же, как используется в сокетах трака)
func _find_entity_from_collider(node: Node) -> Entity:
	var current = node
	while current:
		if current is Entity:
			return current
		current = current.get_parent()
	return null
