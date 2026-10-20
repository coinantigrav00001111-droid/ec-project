class_name SelectTool extends Node

##########################
## Выбор и Ховер объектов
##########################

var controller: ToolController
var hovered_entity: Entity
var selected_entity: Entity

# Флаги для инпута

var clicked_entity: Entity = null

var lmb_start_pos := Vector2.ZERO
var rmb_start_pos := Vector2.ZERO

# флаги точек флекс-трака
var lmb_consumed := false   # нажатие забрал компонент (ручка / добавление изгиба)
var rmb_consumed := false
var handle_dragging := false

func enter():

	if selected_entity and controller.to_drag:
		#INFO ДЕРГАЕМ ПАНЕЛЬ!
		controller.info_panel.set_target(selected_entity)
		controller.to_drag = false
		_start_drag(selected_entity)

		




func process_tick(_delta):
	if handle_dragging and selected_entity:
		selected_entity.send_event("on_handle_drag", controller.get_mouse_ray_vec())
	else:
		_update_hover()
	$"../../UI/ModeLabel".text = name



func handle_input(event: InputEvent):
	# --- ПКМ: Обработка (Отмена vs Камера) ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			rmb_start_pos = event.position
			rmb_consumed = _try_handle_remove()
		else:
			if rmb_consumed:
				rmb_consumed = false
				return
			if rmb_start_pos.distance_to(event.position) < 5:
				_clear_selection()
		return

	# --- ЛКМ: Нажатие ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			lmb_start_pos = event.position
			lmb_consumed = _try_handle_press()
			if lmb_consumed:
				return
			clicked_entity = _get_entity_under_mouse()
			if clicked_entity:
				set_selection(clicked_entity)
		else:
			if lmb_consumed:
				if handle_dragging and selected_entity:
					selected_entity.send_event("on_handle_released", {})
				handle_dragging = false
				lmb_consumed = false
				return
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

	if selected_entity and Input.is_action_just_pressed("ui_graph_delete"):
		selected_entity.kill_me() #entity сама почистит за собой
		#selected_entity.free()
		#INFO ДЕРГАЕМ ПАНЕЛЬ!
		controller.info_panel.set_target(null)
		
	if selected_entity and Input.is_action_just_pressed("ui_page_up"):
		selected_entity.send_event("on_train_kicked", {"power_kick": 10.0}) # Пинок силой 10m\s
	if selected_entity and Input.is_action_just_pressed("ui_page_down"):
		selected_entity.send_event("on_train_kicked", {"power_kick": -10.0}) # Пинок силой 10m\s



func _get_entity_under_mouse() -> Entity:
	# Слой земли(1), траков(3), трейна(5), селектеда(11)- 11 это гост!
	
	#var hit = controller.get_mouse_ray((1 << 0) | (1 << 2) |(1 << 4)| (1 << 10)) 
	var hit = controller.get_mouse_ray(Global.active_layers(['ground','tracks','trains','ghost'])) 
	if hit and hit.collider:
		return _find_entity(hit.collider)
	return null



func set_selection(entity_to_select: Entity):

	if selected_entity == entity_to_select: return 
	if selected_entity: 
		# ⚡Сигнал в c_path или trainvisual о смене слоя
		selected_entity.send_event("on_select_layer", {'enabled':false})
		selected_entity.remove_component(C_Selected)
		#selected_entity = null # из старого, убрать? 
	selected_entity = entity_to_select
	
	if selected_entity:
		selected_entity.add_component(C_Selected.new())
		# ⚡Сигнал в visual о смене слоя
		selected_entity.send_event("on_select_layer", {'enabled':true})
		
	#INFO ДЕРГАЕМ ПАНЕЛЬ!
	controller.info_panel.set_target(selected_entity)




func _start_drag(target: Entity):
	controller.drag_tool.target_entity = target
	controller.switch_tool(controller.drag_tool)



# ---- HOVER ---
func _update_hover():
	# (1 << 0) | (1 << 2) | (1 << 10)
	# Слои земля, трак, вагон
	var result = controller.get_mouse_ray(Global.active_layers(['ground','tracks','trains','ghost'])) 
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



## Flex
## ЛКМ: ручка или Shift+клик по кривой выбранного flex. Тул компонентов не знает
func _try_handle_press() -> bool:
	if not selected_entity:
		return false
	# выбранный объект лежит на слое ghost (on_select_layer), поэтому ghost тоже в маске
	var hit = controller.get_mouse_ray(Global.active_layers(['handles', 'tracks', 'ghost']))
	if hit.is_empty():
		return false
	var data := {"collider": hit.collider, "position": hit.position,
			"shift": Input.is_key_pressed(KEY_SHIFT), "consumed": false, "drag": false}
	selected_entity.send_event("on_pointer_pressed", data)
	handle_dragging = data.drag
	return data.consumed


func _try_handle_remove() -> bool:
	if not selected_entity:
		return false
	var hit = controller.get_mouse_ray(Global.active_layers(['handles']))
	if hit.is_empty():
		return false
	var data := {"collider": hit.collider, "consumed": false}
	selected_entity.send_event("on_handle_remove", data)
	return data.consumed
	
	


# Снимает селекшн при лкм пкм без драга
func _clear_selection():
	if selected_entity: 
		selected_entity.remove_component(C_Selected)
		# ⚡Сигнал в visual о смене слоя
		selected_entity.send_event("on_select_layer", {'enabled':false})
	selected_entity = null
	
	#INFO ОЧИЩАЕМ ПАНЕЛЬ! +
	controller.info_panel.set_target(null)



func _find_entity(node):
	var curr = node
	while curr:
		if curr is Entity: return curr
		curr = curr.get_parent()
	return null



# при выходе из селекта чистим 
func exit(_to_drag : bool = false):
	
	if selected_entity: 
		selected_entity.remove_component(C_Hovered)
		if !_to_drag: # если выход не в драг, то убираем селект полностью
			_clear_selection()
			#INFO Очищаем панель
			controller.info_panel.set_target(null) 
		
	if hovered_entity:
		if is_instance_valid(hovered_entity):
			hovered_entity.remove_component(C_Hovered)
		hovered_entity = null
	
	handle_dragging = false
