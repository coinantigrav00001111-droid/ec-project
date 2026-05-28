class_name C_Draggable extends IDraggable

##################################
## Библиотека действий. Она живет на объекте всегда.
##################################
## способность двигать ентити, когда включено C_Drag 
## компонент двигает сущность по евенту из ентити

var drag_offset := Vector3.ZERO # смещение мыши
var rotation_euler := Vector3.ZERO # Храним тут, чтобы не терять при смене тулзов
var initial_transform: Transform3D # Стартпозиция



## Считает свой оффсет и запоминает стартовую позицию
func on_drag_started(data: Dictionary):
	initial_transform = entity.global_transform
	drag_offset = entity.global_position - data.pos



func on_drag_moved(data: Dictionary) -> void:
	var target_pos: Vector3 = data.pos + drag_offset
	var normal: Vector3 = data.normal

	# 1. Поворот по Y (Heading)
	var heading_basis = Basis.from_euler(Vector3(0, rotation_euler.y, 0))
	
	# 2. Выравнивание по нормали (чтобы трак лежал на холмах)
	var y_axis = normal
	var x_axis = y_axis.cross(heading_basis.z).normalized()
	var z_axis = x_axis.cross(y_axis).normalized()
	var aligned_basis = Basis(x_axis, y_axis, z_axis).orthonormalized()
	
	# 3. Добавляем наклон по X (поверх выровненного базиса)
	var final_basis = aligned_basis.rotated(x_axis, rotation_euler.x)
	
	# 4. Применяем
	entity.global_transform = Transform3D(final_basis, target_pos)



func on_rotate_input(data: Dictionary):
	var rad = deg_to_rad(data.amount)
	if data.axis == "y": rotation_euler.y += rad
	if data.axis == "x": rotation_euler.x += rad



func on_drag_ended(_data: Dictionary):
	# Если мы заблокированы при отпускании — компонент сам себя возвращает на место
	if entity.has_comp(C_Blocked):
		entity.global_transform = initial_transform
		
# --- Блок синхронизации состояния (Клонирование) ---

# Вызывается у Госта (отдаем данные)
func on_clone_state_to(data: Dictionary) -> void:
	var target_entity: Entity = data.target
	
	# Гост кричит в новую сущность: "Прими мои настройки драга!"
	target_entity.send_event("on_receive_draggable_state", {
		"rotation_euler": rotation_euler
		})

# Вызывается у Реального объекта (принимаем данные)
func on_receive_draggable_state(data: Dictionary) -> void:
	if data.has("rotation_euler"):
		rotation_euler = data.rotation_euler
