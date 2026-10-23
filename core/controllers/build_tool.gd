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

# XX claude-terra: 0 - ставим начало flex, 1 - тянем конец
var stretch_phase := 0

# XX claude-terra T6: тоннельный режим (клавиша U). Новые призраки траков получают C_Tunnel, режим запоминается
var tunnel_mode := false


func enter():
	stretch_phase = 0
	if ghost: ghost.queue_free()
	ghost = controller.entity_factory.create_from_setting(ghost_setting)

	match ghost_setting.build_behavior:
		EntitySetting.BuildBehavior.GHOST_PLACE:
			_enter_ghost_place()
		EntitySetting.BuildBehavior.SPAWN_AND_DRAG:
			_enter_spawn_and_drag()
		EntitySetting.BuildBehavior.PLACE_THEN_STRETCH:   # XX claude-terra
			_enter_ghost_place()


func _enter_ghost_place() -> void:
	controller.entities_root.add_child(ghost)
	ghost.name = 'ghost'
	ghost.add_component(C_Ghost.new())
	ghost.send_event("on_select_layer", {'enabled': true})
	if tunnel_mode:   # XX claude-terra T6: у не-траков события никто не слушает
		ghost.send_event("on_tunnel_set", {"on": true})
	controller.info_panel.set_target(ghost)



func _enter_spawn_and_drag() -> void:
	controller.entities_root.add_child(ghost)      # сначала в дерево
	var hit = controller.get_mouse_ray(_pick_mask())   # XX claude-terra
	if hit.is_empty():
		hit = controller.get_mouse_plane_hit()   # кнопка спавна не над столом
	if hit:
		ghost.send_event("on_drag_moved", hit)     # теперь get_tree() есть
	controller.select_tool.set_selection(ghost)
	ghost = null
	controller.to_drag = true
	controller.switch_tool(controller.select_tool)



func handle_input(event: InputEvent):
	if not ghost: return
	
	#  ПКМ 
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			rmb_pressed_pos = event.position
		else:
			# Отменяем билд режим если это был короткий клик (не драг камеры)
			if rmb_pressed_pos.distance_to(event.position) < 5:
				if stretch_phase == 1:   # XX claude-terra: ПКМ в фазе конца - отмена, новый призрак
					enter()
				else:
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
		
	# XX claude-terra T6: тоннельный режим. Трак с флагом может уходить под листы пенопласта
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_U and ghost.has_comp(C_Path):
		tunnel_mode = not tunnel_mode
		ghost.send_event("on_tunnel_set", {"on": tunnel_mode})

	# Переключатель контроля лимитов flex
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		Global.flex_limits = not Global.flex_limits
		ghost.send_event("on_flex_limits_changed", {})
		
		
	# ЛКМ - Построить
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		
		if ghost.has_comp(C_Blocked) or ghost.has_comp(C_Invalid):   # XX claude-terra
			return # Не строим, если гост красный (пересекается с чем-то / невалидная форма)

		# XX claude-terra: flex ставится в две фазы, тул только шлет события
		var _stretch := ghost_setting.build_behavior == EntitySetting.BuildBehavior.PLACE_THEN_STRETCH
		if _stretch and stretch_phase == 0:
			stretch_phase = 1
			ghost.send_event("on_stretch_started", {})
			return
		if _stretch:
			ghost.send_event("on_stretch_ended", {})

		# 1. Спавним реальный объект и получаем ссылку на него
		var spawned_entity = _place_real_object()
		if _stretch and spawned_entity:
			enter()   # новый призрак: можно продолжать от свободного конца
			return
		
		if not spawned_entity:
			return



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
	# XX claude-terra слои из EntitySetting.pick_layers
	var hit = controller.get_mouse_ray(_pick_mask()) 
	
	if hit and ghost:
		# Отправляем приказ в сущность. Оттуда C_TrackDraggable сам разберется
		if stretch_phase == 1:   # XX claude-terra
			ghost.send_event("on_stretch_moved", hit)
		else:
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
