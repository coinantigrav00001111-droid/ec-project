class_name BuildTool extends Node

##########################
## Установка объектов
##########################
## Создает гост размещает его объекты 


var controller: ToolController

var ghost_setting: EntitySetting
var ghost : Entity

var rmb_pressed_pos := Vector2.ZERO

# Параметры вращения
const ROT_STEP := 45.0 # Градусы



## 💡 Функция передачи инструкций в логику игры из UI. Запускается в билдконтроллере по кнопке
func enter():
	if ghost: ghost.queue_free()
	
	ghost = controller.entity_factory.create_from_setting(ghost_setting)
	ghost.name = 'ghost'
	controller.entities_root.add_child(ghost)
	ghost.add_component(C_Ghost.new())

	
	# ДЕРГАЕМ ПАНЕЛЬ!
	controller.info_panel.set_target(ghost)
	controller.entity_debugger.set_target(ghost)


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
		_place_real_object()



func _place_real_object():
	if ghost.has_comp(C_Blocked): return # Не строим, если гост красный
		
	var real_ent = controller.entity_factory.create_from_setting(ghost_setting)
	real_ent.global_transform = ghost.global_transform
	controller.entities_root.add_child(real_ent)
	
	real_ent.name = ghost_setting.name # имя ентити берется из сеттинга госта
	
	# 💥 Тул больше не ищет компоненты. Он приказывает Госту клонировать стейт:
	ghost.send_event("on_clone_state_to", {"target": real_ent})



func process_tick(_delta):
	var hit = controller.get_mouse_ray(1)
	if hit and ghost:

		var snap_data = controller.snap_service.find_snap(ghost, hit.position)
		# Отправляем приказ в сущность. Оттуда C_Draggable сам разберется
		ghost.send_event("on_drag_moved", {
			"pos": hit.position,
			"normal": hit.normal,
			"snap": snap_data
		})
		
	#INFO ДЕРГАЕМ ПАНЕЛЬ! пока не трогаем, не то место наверное
	#controller.info_panel.set_target(ghost)


## Выставляет всем дочерним нодам-коллизиям слой
func _set_collision_layer_recursive(node: Node, layer: int):
	if node is CollisionObject3D:
		node.collision_layer = layer
	for child in node.get_children():
		_set_collision_layer_recursive(child, layer)


## Выполняется при выходе из инстр.
func exit():
	if ghost:
		ghost.queue_free()
		ghost = null
	# Очищаем селекта в UI (null)
	controller._on_build_selected(null)
	# ОЧИЩАЕМ ПАНЕЛЬ!
	controller.info_panel.set_target(null)

	#инспектор
	await get_tree().process_frame # ждем кадр до удаления
	controller.entity_debugger.set_target(ghost)
