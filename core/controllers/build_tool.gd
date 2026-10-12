class_name BuildTool extends Node

##########################
## Установка объектов
##########################
## Создает гост по нажатию кнопки, размещает его объекты 


var controller: ToolController

var ghost_setting: EntitySetting # TODO переимновать в entity_setting
var ghost : Entity

var rmb_pressed_pos := Vector2.ZERO

# Параметры вращения
const ROT_STEP := 45.0 # Градусы

#XX claude
func enter():
	if ghost: ghost.queue_free()
	ghost = controller.entity_factory.create_from_setting(ghost_setting)

	match ghost_setting.build_behavior:
		EntitySetting.BuildBehavior.GHOST_PLACE:
			_enter_ghost_place()
		EntitySetting.BuildBehavior.SPAWN_AND_DRAG:
			_enter_spawn_and_drag()


func _enter_ghost_place() -> void:
	controller.entities_root.add_child(ghost)
	ghost.name = 'ghost'
	ghost.add_component(C_Ghost.new())
	ghost.send_event("on_select_layer", {'enabled': true})
	controller.info_panel.set_target(ghost)

# XX claude
func _enter_spawn_and_drag() -> void:
	controller.entities_root.add_child(ghost)      # сначала в дерево
	var hit = controller.get_mouse_ray(_pick_mask())   # XX claude-terra
	if hit:
		ghost.send_event("on_drag_moved", hit)     # теперь get_tree() есть
	controller.select_tool.set_selection(ghost)
	ghost = null
	controller.to_drag = true
	controller.switch_tool(controller.select_tool)
	
func _enter_spawn_and_drag_0() -> void:
	var hit = controller.get_mouse_ray(Global.active_layers(['ground','tracks','trains']))
	if hit:
		ghost.send_event("on_drag_moved", hit)
	controller.entities_root.add_child(ghost)
	controller.select_tool.set_selection(ghost)
	ghost = null
	controller.to_drag = true
	controller.switch_tool(controller.select_tool)


## 💡 Создаем объект. Запускается в билдконтроллере по кнопке
func enter_0():
	if ghost: ghost.queue_free()

	# выбор гост или объект по настройке сеттинга
	ghost = controller.entity_factory.create_from_setting(ghost_setting)
		## 🟡 Классика. Создание госта
	if ghost_setting.category == &'track':
		controller.entities_root.add_child(ghost)
		ghost.name = 'ghost'
		ghost.add_component(C_Ghost.new())
		# ⚡Сигнал в с-path о смене слоя
		ghost.send_event("on_select_layer", {'enabled':true})
		#INFO ДЕРГАЕМ ПАНЕЛЬ!
		controller.info_panel.set_target(ghost)
		
		## 🟡Одиночная постройка. Переход в селект и драг сразу
	elif ghost_setting.category == &'train': 
		# Отправляем в позицию мышки разово, пока не видно тело
		var hit = controller.get_mouse_ray(Global.active_layers(['ground','tracks','trains']))
		if hit:
			ghost.send_event("on_drag_moved", hit)
			
		controller.entities_root.add_child(ghost)
		controller.select_tool.set_selection(ghost)# Задали активный ентити для селект моде
		ghost = null # гост больше не нужен
		controller.to_drag = true # Флаг для селекта, чтобы прокинул сразу в драг
		controller.switch_tool(controller.select_tool) # ушли в селект



func handle_input(event: InputEvent):
	if not ghost: return
	
	#  ПКМ 
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			rmb_pressed_pos = event.position
		else:
			# Отменяем билд режим если это был короткий клик (не драг камеры)
			if rmb_pressed_pos.distance_to(event.position) < 5:
				controller.switch_tool(controller.select_tool)

	# Транслируем намерение покрутить
	if Input.is_action_just_pressed("key_q"):
		ghost.send_event("on_rotate_input", {"axis": "y", "amount": ROT_STEP})
	if Input.is_action_just_pressed("key_e"):
		ghost.send_event("on_rotate_input", {"axis": "y", "amount": -ROT_STEP})
	if Input.is_action_just_pressed("key_r"):
		ghost.send_event("on_rotate_input", {"axis": "x", "amount": ROT_STEP})
	if Input.is_action_just_pressed("key_f"):
		ghost.send_event("on_rotate_input", {"axis": "x", "amount": -ROT_STEP})

	# ЛКМ - Построить
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		
		if ghost.has_comp(C_Blocked):
			return # Не строим, если гост красный (пересекается с чем-то)

		# 1. Спавним реальный объект и получаем ссылку на него
		var spawned_entity = _place_real_object()
		
		if not spawned_entity:
			return
		
		##XX claude
		#if ghost_setting.category == &'train':
			## Одиночная постройка.
#
			## 1. Сбрасываем гост и очищаем текущий стейт билда
			#exit() 
			## 2. Переключаем контроллер на SelectTool
			#controller.switch_tool(controller.select_tool)
			## 3. SelectTool вешает C_Selected на объект и обновляет InfoPanel.
			#controller.select_tool.set_selection(spawned_entity)
			
		#else:
			# 2. Проверяем, зажат ли Shift
			#if Input.is_key_pressed(KEY_SHIFT):
				# SHIFT ЗАЖАТ: Режим серийной стройки.
				# Оставляем гост жить, просто выходим из функции. 
				#pass
			#else:
				 #SHIFT ОТПУЩЕН: Одиночная постройка.
				 #Переходим в режим Select и передаем фокус на новый объект.
				#_exit_to_select_and_focus(spawned_entity)




## Клонирование госта по лкм
func _place_real_object() -> Entity:

	if ghost.has_comp(C_Blocked):# Не строим, если гост красный
		return null
		
	# Запрашиваем у фабрики создание реального объекта на основе настроек госта
	var real_entity = controller.entity_factory.create_from_setting(ghost_setting)
	
	# Ставим реальный объект точно в ту же позицию и поворот, где сейчас гост
	real_entity.global_transform = ghost.global_transform
	
	# Добавляем в дерево (в рут сущностей)
	controller.entities_root.add_child(real_entity)
	
	# 💥 Тул приказывает госту клонировать стейт. draggable выполнит:
	ghost.send_event("on_clone_state_to", {"target": real_entity})
	#real_entity.send_event("on_drag_ended", {})
	return real_entity



# XX claude-terra
func _pick_mask() -> int:
	return Global.active_layers(ghost_setting.get_pick_layers())


func process_tick(_delta):
	#var hit = controller.get_mouse_ray((1 << 0) | (1 << 2)|(1 << 4))
	var hit = controller.get_mouse_ray(_pick_mask())   # XX claude-terra слои из EntitySetting.pick_layers
	
	if hit and ghost:
		# Отправляем приказ в сущность. Оттуда C_TrackDraggable сам разберется
		ghost.send_event("on_drag_moved", hit)

	$"../../UI/ModeLabel".text = name



## Выполняется при выходе из инстр.
func exit(_to_drag : bool = false):
	if ghost:
		ghost.queue_free()
		ghost = null
		
	
	# Очищаем селекта в UI (null)
	controller._on_build_selected(null)
	
	#INFO ОЧИЩАЕМ ПАНЕЛЬ!
	controller.info_panel.set_target(null)



# find_snap перенесен из snap_service. Но он вообще не нужен... пока. Может потом для power 
func _find_snap(dragging_entity: Entity, _mouse_pos: Vector3) -> Dictionary:
	# Если сокеты есть, идем дальше
	var c_socket = dragging_entity.get_comp(C_Socket)
	if not c_socket: 
		return {"is_snapped": false}
	
	var best_snap = {
		"is_snapped": false,
		"target_socket": {
			"position": 0,
			"direction":0
		},
		"dragging_socket": 0
	}
					
	return best_snap
