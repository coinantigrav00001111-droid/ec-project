class_name DragTool extends Node

var controller: ToolController
var target_entity: Entity

var initial_transform: Transform3D # Для возврата
var drag_offset := Vector3.ZERO
var current_rot := Vector3.ZERO # Храним углы для точности
const ROT_STEP := 15.0 # Градусы

#################################################
func enter():
	if not target_entity: 
		controller.switch_tool(controller.select_tool)
		return
		
	initial_transform = target_entity.global_transform # Запоминаем "где взяли"
	target_entity.add_component(C_Blocked.new())
	target_entity.add_component(C_Drag.new())
	
	# ... (слои и прочее) ...
	var dragger = target_entity.get_comp(C_Draggable)
	# Инициализируем оффсет один раз
	var hit = controller.get_mouse_ray(1 | 4)
	if hit:
		dragger.drag_offset = target_entity.global_position - hit.position


func process_tick(_delta):
	var hit = controller.get_mouse_ray(1 )
	if hit:
		target_entity.get_comp(C_Draggable).update_drag(hit.position, hit.normal)

func handle_input(_event: InputEvent):
	var dragger = target_entity.get_comp(C_Draggable)
	if Input.is_action_just_pressed("key_q"): dragger.add_rotation("y", 15)
	if Input.is_action_just_pressed("key_e"): dragger.add_rotation("y", -15)
	if Input.is_action_just_pressed("key_r"): dragger.add_rotation("x", 15)
	if Input.is_action_just_pressed("key_f"): dragger.add_rotation("x", -15)
	# Дроп и переход в селекттул
	if Input.is_action_just_released("lmb"):
		_drop_object()
		
		
		
func _drop_object():
	# Возвращаем в рабочий слой (например, 3-й)
	# Это делает компонент C_Visual
	#controller.build_tool._set_collision_layer_recursive(target_entity, 1 << 2)
	
	var block_comp = target_entity.get_comp(C_Blocked)
	
	if block_comp and block_comp.is_blocked:
		# ТРЕБОВАНИЕ: Возвращаем в исходную позицию
		target_entity.global_transform = initial_transform
		# Сбрасываем углы в C_Draggable, чтобы они не остались от неудачного драга
		target_entity.get_comp(C_Draggable).rotation_euler = initial_transform.basis.get_euler()
	
	target_entity.remove_component(C_Blocked)
	
	target_entity.remove_component(C_Drag)
	controller.switch_tool(controller.select_tool)
	
	
func exit():
	if target_entity:
		target_entity.remove_component(C_Drag)
		# Blocked удаляем или оставляем в зависимости от того, прошел ли дроп
	target_entity = null
#####################################################

#func enter0():
	#if not target_entity: 
		#controller.switch_tool(controller.select_tool)
		#return
		#
	#initial_transform = target_entity.global_transform # Запоминаем "где взяли"
	#target_entity.add_component(C_Drag.new())
	#
	## Используем наш метод из Entity
	##if not target_entity.has_comp(C_Blocked):
		##target_entity.add_component(C_Blocked.new())
	#
	## Считаем оффсет один раз при входе
	#var hit = controller.get_mouse_ray()
	#if hit:
		#drag_offset = target_entity.global_position - hit.position






#func process_tick0(_delta):
	#var hit = controller.get_mouse_ray(1 | 4)
	#if hit:
		#var target_pos = hit.position + drag_offset
		#
		##target_entity.global_transform = controller.align_to_surface(target_pos, hit.normal)
		##TODO  это замена верхней строки. Функции разные, эта не ложит по нормали, однако верхняя ложит не точно
		#_update_transform(hit.position , hit.normal)



	


## Замена align_to_surface, возможно и не нужна
#func _update_transform(pos: Vector3, normal: Vector3):
	#var target_pos = pos + drag_offset
	#
	## Формируем базис: сначала выравниваем по нормали (если нужно), 
	## а затем накладываем ручное вращение
	#var basis = Basis.from_euler(current_rot)
	#
	## Если это трак, он должен "лежать" на поверхности
	## (Здесь можно добавить твой align_to_surface)
#
	#target_entity.global_transform = Transform3D(basis, target_pos)
	#''' Если включить, то не работает вращение
		#Не обнуляется current_rot при смене селектеда
		#Разве не draggable должен вращать, как в билдтулзе? '''
	##target_entity.global_transform = controller.align_to_surface(target_entity.global_transform.origin, normal)
	#
	## 3. Чек на Blocked (заглушка под будущие коллизии)
	#_check_collisions()
