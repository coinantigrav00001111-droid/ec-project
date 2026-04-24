class_name SelectTool extends Node

##########################
## Выбор и Ховер объектов
##########################

var controller: ToolController
var hovered_entity: Entity
var selected_entity: Entity

# Флаги для инпута

#var mouse_start_pos := Vector2.ZERO # в инпуте замена на drag = event.accumulate(event)
var clicked_entity: Entity = null

var lmb_start_pos := Vector2.ZERO
var rmb_start_pos := Vector2.ZERO


func enter():
	pass


func process_tick(_delta):
	_update_hover()

	# ‼️ дебаг 
	if selected_entity:
		$"../../Debug/DebugLabel".text = str(selected_entity.name)
	else:
		$"../../Debug/DebugLabel".text = " нет селектед "




func handle_input(event: InputEvent):
	# --- ПКМ: Обработка (Отмена vs Камера) ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			rmb_start_pos = event.position
		else:
			# Снимаем селект ТОЛЬКО если мышь почти не двигалась (это был клик)
			if rmb_start_pos.distance_to(event.position) < 5:
				_clear_selection()
		return

	# --- ЛКМ: Нажатие ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			lmb_start_pos = event.position
			clicked_entity = _get_entity_under_mouse()
			if clicked_entity:
				_set_selection(clicked_entity)
		else:
			# Отпустили ЛКМ: если кликнули в пустоту и не тащили — снимаем выбор
			if not clicked_entity and lmb_start_pos.distance_to(event.position) < 5:
				_clear_selection()
			clicked_entity = null

	# --- ЛКМ: Движение (Переход в Драг) ---
	if event is InputEventMouseMotion and Input.is_action_pressed("lmb"):
		if clicked_entity and clicked_entity == selected_entity:
			# Если протащили достаточно далеко — включаем инструмент перетаскивания
			if lmb_start_pos.distance_to(event.position) > 10:
				_start_drag(clicked_entity)
				clicked_entity = null

#func handle_input(event: InputEvent):
	#var drag = event.accumulate(event)
	#if Input.is_action_just_pressed("rmb"):
		#_clear_selection()
		#return
		#
	## ЛКМ нажата
	#if Input.is_action_just_pressed("lmb"):
		##mouse_start_pos = get_viewport().get_mouse_position()
		#clicked_entity = _get_entity_under_mouse()
		#if clicked_entity:
			#_set_selection(clicked_entity)
			#
	## ЛКМ держим
	#if event is InputEventMouseMotion and Input.is_action_pressed("lmb"):
		#if clicked_entity and clicked_entity == selected_entity:
			#
			##if mouse_start_pos.distance_to(event.position) > 10:
			#if drag:
				#_start_drag(clicked_entity)
				#clicked_entity = null # Чтобы не заходить сюда в каждом кадре движения
	#
	## ЛКМ отпустили
	#if Input.is_action_just_released("lmb"):
		#if not clicked_entity and  !drag: #mouse_start_pos.distance_to(get_viewport().get_mouse_position()) < 5:
			#_clear_selection()
		#clicked_entity = null
#
#

func _get_entity_under_mouse() -> Entity:
	
	# Слой земли(1), траков(3), селектеда(11)
	var hit = controller.get_mouse_ray((1 << 0) | (1 << 2) | (1 << 10)) 
	if hit and hit.collider:
		return _find_entity(hit.collider)
	return null



func _set_selection(entity_to_select: Entity):
	if selected_entity == entity_to_select: return # Уже выбран, ничего не делаем
	
	_clear_selection()
	selected_entity = entity_to_select
	selected_entity.add_component(C_Selected.new())
	
	if controller.entity_debugger:
		controller.entity_debugger.set_target(selected_entity)



func _start_drag(target: Entity):
	controller.drag_tool.target_entity = target
	controller.switch_tool(controller.drag_tool)



# ---- HOVER ---
func _update_hover():
	var result = controller.get_mouse_ray(1 | 4) # Слои мира и объектов
	var new_hover = null
	
	# Наехали на сущность?
	if result and result.collider:
		var entity = _find_entity(result.collider)
		if entity and entity.has_comp(IHoverable):
			new_hover = entity
	
	# Если Новый ховер не такой же как был, то делаем ховером новый
	if hovered_entity != new_hover:
		if hovered_entity: 
			hovered_entity.remove_component(C_Hovered)
		hovered_entity = new_hover
		if hovered_entity: 
			hovered_entity.add_component(C_Hovered.new())
			
			# Инспектор 
			controller.entity_debugger.set_target(hovered_entity)



func _clear_selection():
	if selected_entity: 
		selected_entity.remove_component(C_Selected)
	selected_entity = null




func _find_entity(node):
	var curr = node
	while curr:
		if curr is Entity: return curr
		curr = curr.get_parent()
	return null



func exit():
	if hovered_entity: hovered_entity.remove_component(C_Hovered)
	hovered_entity = null
