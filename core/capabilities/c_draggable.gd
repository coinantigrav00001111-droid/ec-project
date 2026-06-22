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
	var snap = data.get("snap", {"is_snapped": false})
	
	if snap.is_snapped:
		print('заглушка')
		pass
		
	else:
		on_drag_moved_stanard(data)


# Движение без снапа
func on_drag_moved_stanard(data: Dictionary) -> void:
	var target_pos: Vector3 = data.pos + drag_offset
	var normal: Vector3 = data.normal

	# 1. Защита от сломанной нормали (иногда бывает на стыках коллизий)
	if normal.is_zero_approx():
		normal = Vector3.UP

	# 2. Базовый вектор направления
	var forward = Vector3.BACK

	# 3. Предохранитель от коллинеарности (Singular Basis)
	# Если нормаль почти параллельна forward, меняем вектор опоры
	if abs(normal.dot(forward)) > 0.99:
		forward = Vector3.RIGHT

	# 4. Вычисляем оси через векторное произведение
	var right = normal.cross(forward).normalized()
	forward = right.cross(normal).normalized()
	
	var aligned_basis = Basis(right, normal, forward)

	# 5. Применяем вращения игрока (храненные в rotation_euler)
	aligned_basis = aligned_basis.rotated(aligned_basis.y, rotation_euler.y)
	aligned_basis = aligned_basis.rotated(aligned_basis.x, rotation_euler.x)

	# 6. Устанавливаем итоговый Transform3D
	entity.global_transform = Transform3D(aligned_basis, target_pos)
#


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
