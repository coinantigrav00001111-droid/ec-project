class_name C_Draggable extends IDraggable

##################################
## Библиотека действий. Она живет на объекте всегда.   
##################################
## способность двигать ентити, когда включено C_Drag 
## компонент двигает сущность по евенту из ентити

@export var snap_break_distance := 9.6 # Дистанция срыва снапа (в метрах)

var drag_offset := Vector3.ZERO # смещение мыши
var rotation_euler := Vector3.ZERO # Храним тут, чтобы не терять при смене тулзов
var initial_transform: Transform3D # Стартпозиция

# Состояние снаппинга
var is_snapped_locked := false # блокировка мыши в снапе
var snapped_entity_transform := Transform3D()




## Считает свой оффсет и запоминает стартовую позицию
func on_drag_started(_data: Dictionary) -> void:

	initial_transform = entity.global_transform
	#TODO это ломает драг повернутого трака на наклонной. Решить вместе с поворотом на краю
	#rotation_euler = entity.global_transform.basis.get_euler() # угол для снапа
	# Берем смещение, но обнуляем Y, чтобы не тащить за собой перепады высот
	var raw_offset = entity.global_position - _data.position
	drag_offset = Vector3(raw_offset.x, 0.0, raw_offset.z)
	
	is_snapped_locked = false

	if entity.has_comp(C_Snapped):
		entity.remove_component(C_Snapped)



# Движение мышью кждый тик
# Обращать внимание на то какие слои хватает рейкаст
func on_drag_moved(_data: Dictionary) -> void:
	# Забираем сырые данные от рейкаста из тулза
	var mouse_pos: Vector3 = _data.position
	var normal: Vector3 = _data.normal
	
	# -Действия для определния вертикальной позиции в точке рейкаста и центра трака-
	# 1. Проецируем drag_offset на плоскость текущей поверхности. Это математический способ отбросить "старую" высоту, сохранив только горизонтальное смещение относительно нормали.
	
	# Сначала считаем, сколько Y содержится в офсете относительно нормали
	var offset_vertical_part = normal * drag_offset.dot(normal)
	
	# Вычитаем вертикальную часть из офсета, получаем "горизонтальный" офсет для текущей плоскости
	var current_plane_offset = drag_offset - offset_vertical_part
	
	# 2. Новая позиция = позиция мыши + очищенный офсет
	var target_pos = mouse_pos + current_plane_offset
	# -- --
	
	if is_snapped_locked and entity.has_comp(C_Snapped):
		# Считаем расстояние от виртуальной позиции мыши до текущей точки снапа
		var distance_to_mouse = target_pos.distance_to(snapped_entity_transform.origin)

		if distance_to_mouse > snap_break_distance:
			# МЫШЬ ОТЪЕХАЛА: срываем снап, убираем компонент-маркер
			entity.remove_component(C_Snapped)
			is_snapped_locked = false
			_apply_regular_movement(target_pos, normal)
		else:
			# МЫШЬ РЯДОМ: Жестко удерживаем трансформ снапа, полностью игнорируя мелкие движения
			entity.global_transform = snapped_entity_transform
	else:
		# Снапа нет — обычное движение по поверхности
		_apply_regular_movement(target_pos, normal)
		pass
	
	
## Обычное движение по поверхности
func _apply_regular_movement(target_pos: Vector3, normal: Vector3) -> void:
	# 1. Берем базовый вектор и крутим только Yaw (Y)
	var base_forward = Vector3.FORWARD.rotated(Vector3.UP, rotation_euler.y)
	
	# 2. Выравниваем по нормали ландшафта
	var up = normal.normalized()
	var right = -up.cross(base_forward).normalized()

	# Защита от коллинеарности
	if abs(up.dot(base_forward)) > 0.99 or right.is_zero_approx():
		right = up.cross(Vector3.RIGHT).normalized()
	var final_forward = right.cross(up).normalized()
	var new_basis = Basis(right, up, final_forward)
	
	# 3. Накручиваем Pitch (X) уже на строго выровненный локальный базис
	# TODO Отменили , потому что на наклонной багует с определением угла.
	# TODO надо поворачивать трак за край.
	
	if rotation_euler.x != 0.0:
		new_basis = new_basis.rotated(new_basis.x, rotation_euler.x)
		#pass
	# 4. Применяем
	entity.global_transform.basis = new_basis
	entity.global_position = target_pos
	
	


## 💡Вызывается из C_Socket при успешной коллизии сокетов
func start_snap(target_global_transform: Transform3D) -> void:
	snapped_entity_transform = target_global_transform
	is_snapped_locked = true # Блокируем обычное влияние мыши
	# Актуализируем углы сразу при снапе. Тогда после в драге снапа угол не возвращается
	rotation_euler = target_global_transform.basis.get_euler()


	
	if not entity.has_comp(C_Snapped):
		entity.add_component(C_Snapped.new()) # Вешаем маркер стейта

	# Мгновенно примагничиваем рельс в идеальную позицию
	entity.global_transform = snapped_entity_transform
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame




func on_drag_ended(_data: Dictionary) -> void:
	# Если рельс заблокирован коллизией балласта при отпускании — возвращаем назад
	if entity.has_comp(C_Blocked):
		entity.global_transform = initial_transform
		
	# Запрашиваем пересчет сети после возврата на исходную
		PGM.request_recalculate()
		
	# При дропе объекта отключаем логику срыва, чтобы рельс остался лежать в точке снапа
	is_snapped_locked = false



func on_rotate_input(data: Dictionary):
	var rad = deg_to_rad(data.amount)
	if data.axis == "y": rotation_euler.y += rad
	if data.axis == "x": rotation_euler.x += rad



## --- Блок синхронизации состояния (Клонирование) ---

# Вызывается у Госта в момент клонирования(отдаем данные). см build_tool 
func on_clone_state_to(data: Dictionary) -> void:
	var target_entity: Entity = data.target
	
	# Гост кричит в новую сущность: "Прими мои настройки драга!"
	target_entity.send_event("on_receive_draggable_state", {
		"rotation_euler": rotation_euler
		})


# Вызывается у Реального объекта в момент клонирования (принимаем данные). см build_tool 
func on_receive_draggable_state(data: Dictionary) -> void:
	if data.has("rotation_euler"):
		rotation_euler = data.rotation_euler



## Сброс высоты и вращения в дефолт (вызывается из DragTool по кнопке)
func on_drag_reset(_data: Dictionary) -> void:
	# 1. Сбрасываем накопленные игроком углы в ноль
	rotation_euler = Vector3.ZERO
	
	# 2. Сбрасываем смещение по высоте
	drag_offset = Vector3.ZERO
	
	# 3. Принудительно сбрасываем локальный трансформ самой сущности, 
	# чтобы визуально она сразу выровнялась до следующего тика on_drag_moved
	entity.rotation = Vector3.ZERO
