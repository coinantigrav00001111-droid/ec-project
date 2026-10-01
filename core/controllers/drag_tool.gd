class_name DragTool extends Node

#########################
## Инструмент перемещения(таскания)
#########################

var controller: ToolController
var target_entity: Entity

const ROT_STEP := 45.0 # Градусы
const LIFT_STEP := 10.0 # Метры

# Флаг позиции пкм
var rmb_pressed_pos := Vector2.ZERO

## Начало драга
func enter():
	if not target_entity:
		controller.switch_tool(controller.select_tool)
		return

	# Вешаем стейт (для визуала)
	target_entity.add_component(C_Drag.new())
	
	# Драг начался вот в этой точке
	var hit = controller.get_mouse_ray(Global.active_layers(['ground']))
	# Драг проверит, если евент из билд моде, то смещения мыши не будет
	#hit['build'] = false
	if hit:
		target_entity.send_event("on_drag_started", hit)
		


## ⚡Сигнал(почти) о смене позиции в сущность. Там рзберется драгабл
func process_tick(_delta):
	#var hit = controller.get_mouse_ray((1 << 0) | (1 << 2)|(1 << 4))
	var hit = controller.get_mouse_ray(Global.active_layers(['ground','tracks','trains']))
	if hit:
		# Отправляем приказ в сущность. Оттуда C_Draggable сам разберется.
		target_entity.send_event("on_drag_moved", hit)
		pass
	$"../../UI/ModeLabel".text = name



### Передача инпутов в ентити, tool_controller вызывает
func handle_input(event: InputEvent):
	if Input.is_action_just_pressed("key_q"):
		target_entity.send_event("on_rotate_input", {"axis": "y", "amount": ROT_STEP})
	if Input.is_action_just_pressed("key_e"):
		target_entity.send_event("on_rotate_input", {"axis": "y", "amount": -ROT_STEP})
	if Input.is_action_just_pressed("key_r"):
		target_entity.send_event("on_rotate_input", {"axis": "x", "amount": ROT_STEP})
	if Input.is_action_just_pressed("key_f"):
		target_entity.send_event("on_rotate_input", {"axis": "x", "amount": -ROT_STEP})
	if Input.is_action_just_pressed("ui_home"):
		target_entity.send_event("on_drag_reset", {}) # сбросить состояние
	if Input.is_action_pressed("ui_page_up"):
		target_entity.send_event("on_lift_input", {"step": LIFT_STEP}) 
	if Input.is_action_pressed("ui_page_down"):
		target_entity.send_event("on_lift_input", {"step": -LIFT_STEP}) 
		
	if Input.is_action_just_released("lmb"):
		controller.switch_tool(controller.select_tool)# Драг окончен дропом
	
	#  ПКМ 
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed: # нажали 
			rmb_pressed_pos = event.position
		else: # отпустили
			# Отменяем драг режим если это был короткий клик (не драг камеры)
			if rmb_pressed_pos.distance_to(event.position) < 5:
				controller.switch_tool(controller.select_tool)


## Драг окончен
func exit(_to_drag : bool = false):
	
	if target_entity:
		target_entity.remove_component(C_Drag)
		target_entity.send_event("on_drag_ended", {})
