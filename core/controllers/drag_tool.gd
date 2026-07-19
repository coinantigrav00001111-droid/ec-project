class_name DragTool extends Node

#########################
## Инструмент перемещения(таскания)
#########################

var controller: ToolController
var target_entity: Entity

const ROT_STEP := 45.0 # Градусы


## Начало драга
func enter():
	if not target_entity:
		controller.switch_tool(controller.select_tool)
		return
		
	# Вешаем стейт (для визуала)
	target_entity.add_component(C_Drag.new())
	
	# Драг начался вот в этой точке
	var hit = controller.get_mouse_ray(1)
	if hit:
		target_entity.send_event("on_drag_started", {"pos": hit.position})
		
	##инспектор
	#controller.entity_debugger.set_target(target_entity)
#


## ⚡Сигнал(почти) о смене позиции в сущность. Там рзберется драгабл
func process_tick(_delta):
	var hit = controller.get_mouse_ray(1)
	if hit:
		# Проверка снапа больше не нужна, см. build_tool
		#var snap_data = controller.snap_service.find_snap(target_entity, hit.position)
		var snap_data = null
		# Отправляем приказ в сущность. Оттуда C_Draggable сам разберется.
		target_entity.send_event("on_drag_moved", {
			"pos": hit.position,
			"normal": hit.normal,
			"snap": snap_data
		})



### Передача инпутов в ентити, tool_controller вызывает
func handle_input(_event: InputEvent):
	if Input.is_action_just_pressed("key_q"):
		target_entity.send_event("on_rotate_input", {"axis": "y", "amount": ROT_STEP})
	if Input.is_action_just_pressed("key_e"):
		target_entity.send_event("on_rotate_input", {"axis": "y", "amount": -ROT_STEP})
	if Input.is_action_just_pressed("key_r"):
		target_entity.send_event("on_rotate_input", {"axis": "x", "amount": ROT_STEP})
	if Input.is_action_just_pressed("key_f"):
		target_entity.send_event("on_rotate_input", {"axis": "x", "amount": -ROT_STEP})
	
	if Input.is_action_just_released("lmb"):
		_drop_object()



## Драг окончен дропом
func _drop_object():
	target_entity.send_event("on_drag_ended", {})
	controller.switch_tool(controller.select_tool)



## Драг окончен
func exit(_to_drag : bool = false):
	if target_entity:
		target_entity.remove_component(C_Drag)
		target_entity.send_event("on_drag_ended", {})
