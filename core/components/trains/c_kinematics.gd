class_name C_Kinematics extends ICapability

####################
## Способность, Библиотека действий. Она живет на объекте всегда.
####################
## Рассчитывает физику на рельсах и триггерит крушения
## (Динамика вагона): * Ответственность: Масса, инерция, трение, длина свободного хода
##Считает продольные колебания. Если скорость превышает лимит в повороте — генерирует событие on_derailed (сход), после чего отключает привязку к сплайну и включает физику Godot (RigidBody).


# Заполняются в редакторе в pat_setting при создании ентити 
var mass: float  # Кг
var max_grip: float # Максимальная удерживающая сила реборды
var roll_resistance: float # Трение качения

# --- НОВЫЕ ПАРАМЕТРЫ ---
var longitudinal_grip: float = 3.0 #  срыва колес в пробуксовку
var min_curve_radius: float = 0.0 # минимальный проходимый радиус

#"Rotation Limits (YAW)"
var max_yaw_deg: float = 25.0    # Максимальный угол поворота тележки
var yaw_spring: float = 5.0      # Сила возвратной пружины (стремление выровняться по оси кузова)

#"Suspension (Travel & Play)"
var vertical_travel_y: float = 0.05 #Вертикальный ход пружин(для имитации просадки на стыках)
var lateral_play_x: float = 0.02 #Люфт колесной пары в колее (для поперечной раскачки)
var suspension_stiffness: float = 10.0 # Жесткость амортизаторов

var max_tractive_force: float = 0.0 # Максимальная сила тяги мотора (Н) # TODO в c_engine она есть
var max_theoretical_speed: float = 0.0  # Максимальная скорость # TODO в c_engine она есть
var has_engine: bool = false
var current_speed: float = 0.0 # Метры в секунду вдоль сплайна
var wheel_surface_speed : float = 0.0 # Линейная скорость колес не на рельсах

## μ бокового скольжения колёс и скольжения лежащим корпусом
var slide_friction: float = 0.1

## μ юза локо с заблокированными колёсами (нет тяги). Общая для рельс и стола.
var locked_wheel_friction: float = 3.0


# Физикс тело вагона
var rb : RigidBody3D

# Флаг объект тащат мышью
var is_dragging: bool = false 


func on_added():
	rb = get_comp(C_TrainVisual).rb
	# FIXME масса в конфиге идентити должна ставиться реальная в граммах. А при создании вагона делать ее х10 для устойчивости движка. Или пока как есть - ставить х10
	rb.mass = mass

	# Всё трение считаем сами (_assist_ground_friction), контактное трение движка выключаем.
	# contact_monitor нужен, чтобы знать, касается ли вагон поверхности.
	rb.contact_monitor = true
	rb.max_contacts_reported = 4
	var pm: PhysicsMaterial
	if rb.physics_material_override:
		pm = rb.physics_material_override.duplicate() # сохраняем bounce из сцены
	else:
		pm = PhysicsMaterial.new()
	pm.friction = 0.0
	rb.physics_material_override = pm


# Реакция на появление компонентов в ентити
func on_component_added(_type: Script):
		if _type == C_Ghost: # Для срабатывания сеттингов откл физику
			rb.freeze = true
			rb.top_level = false



## из C_TrainDraggable в начале\конце  драга прилетает  {'on': false, 'freeze': false}
## Энергию после броска гасит трение (_assist_ground_friction), без хаков с alignment.
func on_is_dragging(_data: Dictionary) -> void:
	if rb:
		rb.freeze = _data.freeze  # Физика вкл\выкл 
		is_dragging = _data.on    # Флаг драга
		
		if not is_dragging:
			# damp действует и на вертикаль, поэтому линейный = 0 (калибровка падения)
			rb.linear_damp = 0.0
			rb.angular_damp = 0.3
		else:
			wheel_surface_speed = 0.0



## Пинок. "+" = носом вперёд. Параметры события (необязательные):
## angle - поворот направления пинка вокруг Y (рад), height - высота приложения над ЦМ
func on_train_kicked(data: Dictionary) -> void:
	var chassis = get_comp(C_Chassis)
	if not chassis or chassis.is_on_rails:
		return

	var power = data.get("power_kick", 0.0)
	if power == 0.0 or not rb:
		return

	var fwd := -rb.global_basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		return

	kick_impulse({
		"dir": fwd.normalized().rotated(Vector3.UP, data.get("angle", 0.0)),
		"impulse": power * RailPhysics.KICK_IMPULSE_K, # J [Н*с], dv = J / m - как на рельсах
		"height": data.get("height", 0.0),             # 0 = на уровне ЦМ
	})


## Импульс J вдоль dir, приложенный на высоте height над ЦМ (height > 0 даёт момент и кувырок)
func kick_impulse(d: Dictionary) -> void:
	var dir: Vector3 = d.get("dir", Vector3.ZERO)
	var J: float = d.get("impulse", 0.0)
	if dir.length_squared() < 0.0001 or J == 0.0:
		return

	rb.freeze = false
	rb.sleeping = false
	rb.apply_impulse(dir.normalized() * J, Vector3.UP * d.get("height", 0.0))



func _physics_process(delta: float) -> void:

	# 1. Если физика выключена (вагон на рельсах или это гост), выходим
	if not rb or rb.freeze:
		return

	if not rb.top_level: 
		rb.top_level = true

	# 2. РЕЖИМ ПЕРЕТАСКИВАНИЯ (Драг мышью)
	if is_dragging:
		if rb.sleeping: 
			rb.sleeping = false

		var damp_mouse = 30.0 # 5 - soft, 30.0 - hard
		var limit_speed_to_mouse = 80.0 # ~180 км/ч
		
		# --- Линейная скорость ---
		var diff = entity.global_position - rb.global_position
		rb.linear_velocity = (diff * damp_mouse).limit_length(limit_speed_to_mouse)

		# --- Угловая скорость ---
		var diff_x = angle_difference(rb.global_rotation.x, entity.global_rotation.x)
		var diff_y = angle_difference(rb.global_rotation.y, entity.global_rotation.y)
		var diff_z = angle_difference(rb.global_rotation.z, entity.global_rotation.z)
		
		var target_angular = (Vector3(diff_x, diff_y, diff_z) * damp_mouse).limit_length(10.0)
		rb.angular_velocity = rb.angular_velocity.lerp(target_angular, limit_speed_to_mouse * delta)

	# 3. РЕЖИМ СВОБОДНОГО ПАДЕНИЯ / СХОДА С РЕЛЬС (Физика Godot)
	else:
		var chassis = get_comp(C_Chassis)
		# Если шасси нет или вагон НЕ на рельсах — работает чистая физика
		if not chassis or not chassis.is_on_rails:

			if not rb.sleeping:
				# 3.1. Синхронизируем Entity за падающим RigidBody
				entity.global_position = rb.global_position
				entity.global_basis = rb.global_basis
				
				# 3.2. ‼️Вертикальный ассист (HO-масштаб)
				_assist_vertical(true)
				
				# 3.3. Трение колёс/корпуса (то же, что на рельсах: кулоновское)
				_assist_ground_friction(delta)
				
				# 3.4. Скорость вращения колёс (для боги)
				_update_wheel_speed()



# Вертикальный ассист (HO-масштаб). Проверка движения, чтобы не колбасило в движении
func _assist_vertical(_check_move := true):
	
	## ‼️тест падения с 20м эталон ‼️ : ~0,2с и средняя скорость ~1 м/с. 
	var scale_factor = RailPhysics.VERTICAL_SCALE # ~0,217с и средняя скорость ~0,92 м/с. 
	
	# Формула учитывает массу, потому что пихаем вниз		
	var extra_gravity = Vector3.DOWN * mass * 9.81 * (scale_factor - 1.0)
	
	if _check_move:
		# Если не двигается, то и не считаем
		var is_falling_down = rb.linear_velocity.length() > 0.01
		if 	 !is_falling_down:
			return
			
	rb.apply_central_force(extra_gravity)



## Колёса на столе: вдоль оси качение (та же формула, что в C_Chassis), поперёк скольжение.
## Сила прикладывается в точках контакта тележек, поэтому рыскание получается само.
func _assist_ground_friction(delta: float) -> void:
	if delta <= 0.0 or rb.get_contact_count() == 0:
		return # в воздухе трения нет

	var v := rb.linear_velocity
	var v_h := Vector3(v.x, 0.0, v.z)
	if v_h.length() < 0.01 and rb.angular_velocity.length() < 0.01:
		return # даём телу уснуть

	# Лежит на боку/крыше: скользит корпусом
	if rb.global_basis.y.dot(Vector3.UP) < 0.7:
		var spd := v_h.length()
		if spd > 0.01:
			var dv := minf(slide_friction * RailPhysics.G_SLIDE * delta, spd)
			rb.apply_central_force(-v_h / spd * (dv / delta) * mass)
		return

	# На колёсах
	var bogie_comp := get_comp(C_Bogie) as C_Bogie
	if not bogie_comp or bogie_comp.bogies_data.is_empty():
		return

	var fwd := -rb.global_basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		return
	fwd = fwd.normalized()
	var side := Vector3.UP.cross(fwd)

	# Локо без тяги: колёса стоят. В шасси в этом случае roll_res = longitudinal_grip, здесь так же
	var mu_long := locked_wheel_friction if entity.has_comp(C_Engine) else roll_resistance
	var share := mass / float(bogie_comp.bogies_data.size())

	for b in bogie_comp.bogies_data:
		var r_wheel: float = b.config.wheel_pair_position.y if b.config else 0.7
		# Точка контакта тележки с поверхностью относительно origin тела (ЦМ ≈ origin)
		var rel: Vector3 = (b.pivot.global_position - rb.global_basis.y * r_wheel) - rb.global_position
		var v_p := v + rb.angular_velocity.cross(rel)

		var a_long := RailPhysics.friction_dv(v_p.dot(fwd), mu_long, RailPhysics.G_ROLL, delta) / delta
		var a_lat := RailPhysics.friction_dv(v_p.dot(side), slide_friction, RailPhysics.G_SLIDE, delta) / delta
		rb.apply_force((fwd * a_long + side * a_lat) * share, rel)



func _update_wheel_speed() -> void:
	if entity.has_comp(C_Engine):
		wheel_surface_speed = 0.0 # Колеса стоят, локо скользит юзом
	else:
		# только продольная составляющая: боковой юз колёса не крутит
		wheel_surface_speed = rb.linear_velocity.dot(-rb.global_basis.z)



## Обработка физики схода.
func on_derailed(_data: Dictionary) -> void:
	if not rb: return
	
	# 1. Подтягиваем физику к кузову
	rb.global_transform = entity.global_transform
	rb.freeze = false # Отвязываемся от сплайна
	rb.sleeping = false
	
	# 2. Передаем импульс движения
	rb.linear_velocity = _data.current_velocity_3d

	# 3. Трение считаем сами, damp не используем (он портит калибровку падения)
	rb.linear_damp = 0.0
	rb.angular_damp = 0.3
		
	var rot = 0.3
	rb.angular_velocity = Vector3(randf_range(-rot, rot), randf_range(-rot, rot), randf_range(-rot, rot))



## Сброс высоты и вращения в дефолт (вызывается из DragTool по кнопке)
func on_drag_reset(_data: Dictionary) -> void:

	await get_tree().physics_frame
	if is_instance_valid(rb):
		# 1. Сбрасываем углы в ноль
		rb.rotation = Vector3.ZERO

	# 2. Принудительно сбрасываем локальный трансформ самой сущности, 
	# чтобы визуально она сразу выровнялась до следующего тика on_drag_moved
	entity.rotation = Vector3.ZERO


# Прилетает при ручном вращении ентити из драгабле
func on_force_rotate_physics(data: Dictionary) -> void:
	if not rb:
		return
	if not is_inside_tree():
		rb.global_basis = data.basis   # без ожидания, физика ещё не активна
		return
	await get_tree().physics_frame
	if is_instance_valid(rb):
		rb.global_basis = data.basis

# TODO Побочное замечание: в _snap_to_track каждый тик драга вызывается on_force_rotate_physics с await. Это создаёт новую корутину на каждый кадр, пока вагон над траком. Работает, но можно вместо этого один раз за кадр писать rb.global_basis напрямую, когда вагон в драге: физика всё равно управляется скоростями в _physics_process. Это отдельная оптимизация, не срочная.

# Мы не на рельсах, только это тут интересует
# Если это Локомотив, скорость не будет приходить от C_Engine.
# Если вагон — от C_Coupler (тяга соседнего вагона).
func on_speed_changed(data: Dictionary) -> void:
	current_speed = data.get("speed", 0.0)
