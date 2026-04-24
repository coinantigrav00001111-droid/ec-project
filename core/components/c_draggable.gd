class_name C_Draggable extends IDraggable

##################################
## Библиотека действий. Она живет на объекте всегда.
##################################
## способность двигать ентити, когда включено C_Drag 


# Настройки, которые мы пробросим из ComponentSettings
#var follow_surface := true
var drag_offset := Vector3.ZERO
var rotation_offset: float = 0.0
var rotation_euler := Vector3.ZERO # Храним тут, чтобы не терять при смене тулзов


func start_drag(hit_pos: Vector3):
	# Запоминаем разницу между позицией сущности и точкой клика
	drag_offset = entity.global_position - hit_pos


func update_drag(target_pos: Vector3, normal: Vector3):
	var basis = _calculate_aligned_basis(normal)
	entity.global_transform = Transform3D(basis, target_pos + drag_offset)


# Вращение 
func _calculate_aligned_basis(normal: Vector3) -> Basis:
	# 1. Берем только поворот (Heading)
	var heading_basis = Basis.from_euler(Vector3(0, rotation_euler.y, 0))
	
	# 2. Выравниваем по нормали (Surface Alignment)
	var y_axis = normal
	var x_axis = y_axis.cross(heading_basis.z).normalized()
	var z_axis = x_axis.cross(y_axis).normalized()
	var aligned_basis = Basis(x_axis, y_axis, z_axis).orthonormalized()
	
	# 3. Накладываем наклон (X-rotation) ПОВЕРХ выровненного базиса
	# Теперь R/F будет наклонять объект относительно склона, а не мира
	return aligned_basis.rotated(x_axis, rotation_euler.x)
	
	
func add_rotation(axis: String, amount_deg: float):
	var rad = deg_to_rad(amount_deg)
	if axis == "y": rotation_euler.y += rad
	if axis == "x": rotation_euler.x += rad	
	##===================================================
	
	



func _get_aligned_basis(normal: Vector3) -> Basis:
	# Простая логика выравнивания Y по нормали
	var y = normal
	var x = Vector3.RIGHT if abs(normal.x) < 0.9 else Vector3.UP
	var z = x.cross(y).normalized()
	x = y.cross(z).normalized()
	return Basis(x, y, z)


func _align_to_surface(pos: Vector3, normal: Vector3) -> Transform3D:
	var up = normal
	var forward = Vector3.BACK if abs(normal.dot(Vector3.BACK)) < 0.95 else Vector3.RIGHT
	var right = forward.cross(up).normalized()
	forward = up.cross(right).normalized()
	return Transform3D(Basis(right, up, forward), pos)
