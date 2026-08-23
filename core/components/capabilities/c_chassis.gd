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



# В идеале это должно вызываться не в _process, а через системный менеджер поездов, 
# но для инкапсуляции логики компонента пока оставляем так.

func _physics_process(delta: float) -> void:
	if not is_on_rails or not is_instance_valid(current_track):
		# В кинематикс
		entity.send_event('on_speed_changed', {'speed': 0.0})
		return

	var path_comp = current_track.get_comp(C_Path)
	# Проверка path_node
	if not path_comp or not path_comp.curve or not path_comp.path_node:
		return

	# 🚩 Поехали 
	# 1. Применяем скорость (работает для + и -)
	if current_speed != 0.0:
		current_spline_offset += current_speed * delta
		#Двигается from в направлении to на delta величину
		current_speed = move_toward(current_speed, 0.0, friction_decel * delta)

	# 2. Если стоим и нет скорости - экономим ресурсы, не считаем кривые
	if current_speed == 0.0:
		return

	var curve: Curve3D = path_comp.curve
	var path_node = path_comp.path_node 
	var track_length = curve.get_baked_length()

	# 3. ‼️ВРЕМЕННЫЙ ПРЕДОХРАНИТЕЛЬ для одного трака
	# Не даем оффсету выйти за края кривой, чтобы тележки не съехались
	current_spline_offset = clamp(
		current_spline_offset, 
		abs(rear_bogie_offset), 
		track_length - front_bogie_offset
	)
	
	# 4. Находим локальные позиции тележек на кривой
	# TODO надо универсальное определение высоты трака
	var track_h = Vector3(0, GS.TRACK_WITH_BALLAST_HEIGHT, 0) 
	var front_local = curve.sample_baked(current_spline_offset + front_bogie_offset) + track_h
	var rear_local = curve.sample_baked(current_spline_offset + rear_bogie_offset)+ track_h
	
	# 5. 🛠 ПЕРЕВОДИМ В ГЛОБАЛ ЧЕРЕЗ PATH_NODE (Решает проблему телепорта!)
	var front_global = path_node.to_global(front_local)
	
	var rear_global = path_node.to_global(rear_local)

	# 6. Двигаем кузов
	entity.global_position = (front_global + rear_global) / 2.0
	
	# 7. Поворачиваем кузов
	if front_global.distance_to(rear_global) > 0.001:
		# Базис UP берем от глобального трансформа самого path_node
		entity.look_at(front_global, path_node.global_transform.basis.y)
		
	# Убеждаемся, что кузов отвязан от ентити
	if not rb.top_level: rb.top_level = false

	if is_on_rails:	# ФИЗИЧЕСКИЙ ДРАГ: RigidBody догоняет Entity (курсор)
		rb.global_position = entity.global_position




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



# Событие схода с рельс (от C_Kinematics или столкновения)
func on_derailed(_data: Dictionary) -> void:
	printt ('derailed')
	if not is_on_rails: return
	is_on_rails = false
	current_track = null
	
	# Отвязываемся от сплайна
	if rb:
		rb.freeze = false
