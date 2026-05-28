class_name BuildTool extends Node

##########################
## Установка объектов
##########################
## Создает гост размещает его объекты 


var controller: ToolController

var ghost_setting: EntitySetting
var ghost : Entity

#var capability: ICapability
#var ghost_offset := Vector3.ZERO
var rmb_pressed_pos := Vector2.ZERO

# Параметры вращения
const ROT_STEP := 15.0 # Градусы

func enter():
	if ghost: 
		ghost.queue_free()
		
	ghost = controller.entity_factory.create_from_setting(ghost_setting)
	controller.entities_root.add_child(ghost)
	ghost.add_component(C_Ghost.new())
	
	# Сигнал: начали драг (хоть это и гост, логика та же)
	#var hit = controller.get_mouse_ray(1)
	#ghost.send_event("on_drag_started", {"pos": hit.position})
	
## 💡 Выполняется при входе в инструмент\ бывшая ‼️(old) btn_object_selected(_setting: EntitySetting):
## Функция передачи инструкций в логику игры из UI. Запускается в билдконтроллере по кнопке
#func enter():
	#if ghost : ghost.queue_free()
	#
	## Снимаем селект при выборе госта
	#controller.select_tool._clear_selection()
	#
	## 1. Создаем сущность компами из EntitySetting (там уже есть C_Visual и C_Draggable)
	#ghost = controller.entity_factory.create_from_setting(ghost_setting)
		#
	## 2. Повесили состояния (State)
	#ghost.add_component(C_Ghost.new()) # Пока ничего не включает
	#ghost.add_component(C_Drag.new()) # Это включает draggable тащить 
	#
	## 3. Рекурсивно меняем слой всем коллизиям призрака на 10 (Bit 9) - ghost
	#_set_collision_layer_recursive(ghost, 1 << 9)
	#
	## 4. Добавили госта в мир
	#controller.entities_root.add_child(ghost) 
	#
	##инспектор
	#controller.entity_debugger.set_target(ghost)

func handle_input(event: InputEvent):
	if not ghost: return

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
		
#func handle_input(event: InputEvent):
	#var dragger = ghost.get_comp(C_Draggable)
	#if not dragger: return
	#
	## Фикс ПКМ (Requirement 1)
	#if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		#if event.pressed:
			#rmb_pressed_pos = event.position
		#else:
			## Отменяем билд только если это был короткий клик (не драг камеры)
			#if rmb_pressed_pos.distance_to(event.position) < 5:
				#controller.switch_tool(controller.select_tool)
				#
	#if Input.is_action_just_pressed("key_q"): dragger.add_rotation("y", 15)
	#if Input.is_action_just_pressed("key_e"): dragger.add_rotation("y", -15)
	#if Input.is_action_just_pressed("key_r"): dragger.add_rotation("x", 15)
	#if Input.is_action_just_pressed("key_f"): dragger.add_rotation("x", -15)
	## Дроп и переход в селекттул
	#if Input.is_action_just_released("lmb"):
		#var block_comp = ghost.get_comp(C_Blocked)
		#if block_comp:
			#print("Нельзя строить здесь!")
			#return # Просто выходим, ничего не спавним
		#_place_real_object()


func _place_real_object():
	if ghost.has_comp(C_Blocked):
		return # Не строим, если гост красный
		
	var real_ent = controller.entity_factory.create_from_setting(ghost_setting)
	real_ent.global_transform = ghost.global_transform
	
	# Копируем углы поворота от госта реальному объекту
	var ghost_dragger = ghost.get_comp(C_Draggable)
	var real_dragger = real_ent.get_comp(C_Draggable)
	if ghost_dragger and real_dragger:
		real_dragger.rotation_euler = ghost_dragger.rotation_euler

	controller.entities_root.add_child(real_ent)
	
	# Если хочешь, чтобы после постройки можно было строить дальше, не выключай тул
	# Иначе - выходим в селект:
	controller.switch_tool(controller.select_tool)
	
#func _place_real_object():
	## Создаем реальный объект БЕЗ компонента C_Ghost
	#var real_ent = controller.entity_factory.create_from_setting(ghost_setting)
	#real_ent.global_transform = ghost.global_transform
	#controller.entities_root.add_child(real_ent) # Спавн его в мир



func process_tick(_delta):
	var hit = controller.get_mouse_ray(1)
	if hit and ghost:
		ghost.send_event("on_drag_moved", {
			"pos": hit.position,
			"normal": hit.normal
		})



## Выставляет всем дочерним нодам-коллизиям слой
func _set_collision_layer_recursive(node: Node, layer: int):
	if node is CollisionObject3D:
		node.collision_layer = layer
	for child in node.get_children():
		_set_collision_layer_recursive(child, layer)


func exit():
	if ghost:
		ghost.queue_free()
		ghost = null
## Выполняется при выходе из инстр.
#func exit():
	#if ghost: ghost.queue_free()
	#ghost = null
	
	#инспектор
	await get_tree().process_frame # ждем кадр до удаления
	controller.entity_debugger.set_target(ghost)
