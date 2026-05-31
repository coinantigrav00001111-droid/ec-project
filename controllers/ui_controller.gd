#class_name UIController extends Node3D
#
##########################
### UIController\ToolController класс коннектор UI с игровой логикой\ Главный управлятель логики
##########################
#
#@export_category('GUIDE Input')
##@export var lmb_pressed_action:GUIDEAction
#
#
#
#@onready var GR: GameRoot = $".."
#@onready var mode_controller: ModeController = $"../UI/ModeController"
#@onready var info_controller: InfoController = $"../UI/InfoController"
#@onready var build_controller: BuildController = $"../UI/BuildController"
#@onready var entity_factory: EntityFactory = $"../EntityFactory"
#@onready var world: World = $"../World"
#
#@onready var entity_debugger: EntityController = $"../Debug/EntityDebugger"
#
#
#
#var current_setting: EntitySetting
#var current_ghost: Entity
#
## ⚡Сигнал обновляем инфу
#signal update_info
##signal update_debug_info
#
#
### Слои коллижн 
##const LAYER_GROUND = 1 << 0   # Layer 1
##const LAYER_TRACK  = 1 << 3   # Layer 4
##const LAYER_WAGON  = 1 << 4   # Layer 5
##const LAYER_GHOST  = 1 << 9   # Layer 10
##const LAYER_SELECT  = 1 << 10   # Layer 11
#
#
## --Флаги--
#var ghost_offset: Vector3 # Смещение госта в центр под мышь при появлении
#
#var drag_cam = false # по пкм(камера)
#var is_dragging := false # по лкм (драг)
#
#var hovered_entity: Entity
#var selected_entity: Entity
#
#var delta_cursor : Vector3 #смещение мышки от центра выбранного трака
#var hit_pos = Vector3.ZERO # лкм нажата здесь
#
#
#
#func _ready() -> void:
	## ⚡Сигнал из моде контроллера
	#mode_controller.current_mode_changed.connect(on_current_mode_changed)
	## ‼️(old)⚡Сигнал выбота объекта по кнопке
	##build_controller.object_selected.connect(btn_object_selected)
#
#
	#
#func _unhandled_input(event: InputEvent) -> void:
	#
	## ------LMB-------
	#if Input.is_action_pressed("lmb") and (event is InputEvent):
		#is_dragging = event.accumulate(event)
		##PIVOT
#
		#if is_dragging:
			#on_lmb_down()
		#else:
			##delta_cursor = selected_entity.position - _raycast_from_mouse().position
			#pass
#
	#if Input.is_action_just_released("lmb") and (event is InputEvent) and !is_dragging:
		#on_lmb_pressed()
	#if Input.is_action_just_released("lmb") and (event is InputEvent) and is_dragging:
		#on_lmb_released()
#
	## -----RMB------
	#if Input.is_action_pressed("rmb") and (event is InputEvent):
		#drag_cam = event.accumulate(event)
		#
	#if Input.is_action_just_released("rmb") and (event is InputEvent) and !drag_cam:
		#on_rmb_pressed()
#
#
#
#
#
#func _process(_delta):
#
	#update_hover()
	#
	### Делаем драг
	#if is_dragging and selected_entity:
		#move_entity(selected_entity)
	#if current_ghost:
		#move_entity(current_ghost)
#
#
#
### Позиция ентити 
#func move_entity(_entity) :
	#
	#var result = _raycast_from_mouse() # это объект
	#if not result: return
#
	## Отправили transform в c_drag 
	## PIVOT 
#
	#var _new_pos = result.position + delta_cursor
	#var _transform = _align_to_surface(_new_pos, result.normal)
	#_transform.origin -= ghost_offset
	#if _entity.has_component(C_Drag):
		#_entity.get_component(C_Drag).apply_transform(_transform)
#
#
#
### 💡💡 =============OBJECT SELECTED=====================
## FIXME ‼️ (old) устарела функция??
### Функция передачи инструкций в логику игры из UI. Запускается в билдконтроллере по кнопке
#func btn_object_selected(_setting: EntitySetting):
	#printt('_btn',_setting)
	#clear_selection()
	#current_setting = _setting
#
	#if current_ghost:
		#current_ghost.queue_free()
	#
	## Фабрика создает гост\сущность
	#current_ghost = entity_factory.create_from_setting(_setting)
	## Меняем слой коллизии на 11
	#set_collision_layer_recursive(current_ghost, layer(10))
	#
	##инспектор
	#entity_debugger.set_target(current_ghost)
#
	## Добавили компоненты select и hovered
	#current_ghost.add_component(C_Ghost.new())
	#current_ghost.add_component(C_Drag.new())
	#current_ghost.add_component(C_Blocked.new())
	#
	## Добавили в мир
	##TODO надо в нужное место %EntitiesRoot
	#world.add_entity(current_ghost)
	#
	#var conf = {'name' : 'Ghost'}
	#current_ghost.set_config(conf)
#
	### ---PIVOT---
	## для госта получаем его центр
	#var center = current_ghost.get_component(C_Visual).get_center_world()
	#ghost_offset = hit_pos - center
#
#
#
#
#
### =============OBJECT SELECTED END=====================
#
### Cоздаем чистый entity
#func place_current():
	#
	#if current_ghost.has_component(C_Blocked) and current_ghost.get_component(C_Blocked).is_blocked:
		#return
		#
	#var new_entity = entity_factory.create_from_setting(current_setting)
	#new_entity.global_transform = current_ghost.global_transform
	#
	##TODO надо в нужное место  EntitiesRoot/Tracks  или EntitiesRoot/Tracks или..
	#world.add_child(new_entity)
#
#
#
#
### ПКМ — отмена
#func cancel_placement():
#
	#if drag_cam: return
	#
	#if current_ghost:
		#current_ghost.queue_free()
	#
	#current_ghost = null
	#current_setting = null
	#ghost_offset = Vector3.ZERO
#
#
### =============HOVER=====================
#
### Ловим ховер
#func update_hover() -> void:
	#
	## драг или гост - нет ховера
	#if is_dragging or current_ghost: return
	#
	#var result = _raycast_from_mouse()
	#
	#var new_hovered: Entity = null
	#
	#if result and result.collider:
		#new_hovered = find_entity_from_collider(result.collider)  # подняться к Entity
	#
	## убрать старый hover
	#if hovered_entity and hovered_entity.has_component(C_Hovered):
		#hovered_entity.remove_component(C_Hovered)
	#
	#hovered_entity = new_hovered
	#
	## добавить hovered в entity 
	#if hovered_entity:
		#hovered_entity.add_component(C_Hovered.new())
#
#
	### 🧲 ============= DRAG =====================
#func on_lmb_down():
#
		## 👉 если на объект → начинаем drag или drag + select
	#if  hovered_entity or selected_entity:
		#var new_select = hovered_entity if hovered_entity else selected_entity
		#
		#select_entity(new_select) # Назначили селектед
		#if !_mouse_on_select_ent():
			#return
		##------PIVOT-------------
#
		#if hit_pos.length() == 0:
			#delta_cursor = selected_entity.global_transform.origin - _raycast_from_mouse().position
			#hit_pos = delta_cursor
#
		## добавляем Drag
		#if not selected_entity.has_component(C_Drag):
			#selected_entity.add_component(C_Drag.new())
#
#
	### 🧲=============SELECT===================== 
	#
###🧱 LMB pressed -Клик по объекту
#func on_lmb_pressed():
	##printt('pressed')
	#
	## 👉 если есть ghost → ставим
	#if current_ghost:
		#place_current()
#
	## 👉 если на объект → назначаем select
	#if ( hovered_entity):
		#select_entity(hovered_entity) 
		#
	## 👉 клик в пустоту → снять выделение	
	#else:
		#clear_selection()
#
#
	### 🧲 ============= Cancel =====================
#
###🧱 LMB released - отпущена
#func on_lmb_released():
	##printt('released')
	#
	## Убрали с-драг
	#if selected_entity and selected_entity.has_component(C_Drag):
		#selected_entity.remove_component(C_Drag)
	#
	#is_dragging = false
	#
	##PIVOT
	#hit_pos = Vector3.ZERO
	#delta_cursor = Vector3.ZERO
#
#
###🧱 RMB pressed Сброс
#func on_rmb_pressed():
	#
	## отмена ghost
	#if current_ghost:
		#cancel_placement()
		#
	#if selected_entity:
		#clear_selection()
#
#
#
	### Селект объекта по клику
#func select_entity(entity: Entity):
#
	#if selected_entity == entity:	return
	#
	## снять старый
	#if selected_entity and selected_entity.has_component(C_Selected):
		#selected_entity.remove_component(C_Selected)
	#
	#selected_entity = entity
	#
	#if not selected_entity.has_component(C_Selected):
		#selected_entity.add_component(C_Selected.new())
#
	## инспектор
	#entity_debugger.set_target(selected_entity)
#
	#
#
### Очистка селекшна
#func clear_selection():
	#if selected_entity and selected_entity.has_component(C_Selected):
		#selected_entity.remove_component(C_Selected)
	#
	#selected_entity = null
	#
	#if !current_ghost and !selected_entity:
		#entity_debugger.set_target(null)
#
#
#
### --------------Меняем режим ---------------------------------
#
#func on_current_mode_changed(_new_mode):
	#GR.current_mode = _new_mode
	#update_info.emit() 
#
#
#
### Получаем текущий current mode
#func get_current_mode() -> StringName:
	#return GR.current_mode
#
#
#
### Получаем текущий debug_mode
#func get_debug_mode() -> bool:
	#return GR.debug_mode
#
#
#
### ----------Helpers-------------------
#
## Мышь над селектом?
#func _mouse_on_select_ent():
	#var coll = _raycast_from_mouse( layer(11))
#
	#return true if coll else false
	#
	#
	#
## Выставляет всем дочерним нодам-коллизиям слой
#func set_collision_layer_recursive(node, layer_value):
	#
	#if node is CollisionObject3D:
		#node.collision_layer = layer_value
	#
	#for child in node.get_children():
		#set_collision_layer_recursive(child, layer_value)
		#
#
### преобразователь номера слоя в маску
#func layer(n: int) -> int:
	#return 1 << (n - 1)
#
#
#
#
#
###💡 Позиция пересечения луча и объекта. Ловит поверхность
#func _raycast_from_mouse(_mask : int = -1 )->Dictionary :
	#var mouse_pos = get_viewport().get_mouse_position()
	#
	#var camera =  get_viewport().get_camera_3d()
#
	#var from = camera.project_ray_origin(mouse_pos)
	#var to = from + camera.project_ray_normal(mouse_pos) * 1000
	#var query = PhysicsRayQueryParameters3D.create(from, to)
	#query.collide_with_areas = true
		## Вариант 1
	##query.collision_mask = LAYER_GROUND | LAYER_TRACK | LAYER_WAGON
		## Вариант 2
	#
	#var actual_mask = layer(1) | layer(3) 
	#if _mask != -1:
		#actual_mask = _mask 
	#query.collision_mask = actual_mask
	#
	## 💡result это : collider,collider_id, normal, position, face_index
	#var result := get_world_3d().direct_space_state.intersect_ray(query)
	#return result
#
#
#
### Выравнивание по поверхности
#func _align_to_surface(pos: Vector3, normal: Vector3) -> Transform3D:
	#
	#var up = normal
	#var forward = Vector3.BACK
	#
	## если почти параллельно — fallback
	#if abs(up.dot(forward)) > 0.95:
		#forward = Vector3.RIGHT
	#
	#var right = forward.cross(up).normalized()
	#forward = up.cross(right).normalized()
	#
	#var _basis = Basis(right, up, forward)
	#
	#return Transform3D(_basis, pos)
#
#
#
### Из коллайдера поднимает его Entity
#func find_entity_from_collider(node: Node) -> Entity:
	#
	#var current = node
	#while current:
		#if current is Entity:
			#if current.has_component(C_Ghost):	return null 
			#
			#return current
		#current = current.get_parent()
	#
	#return null
	#
	#
### ‼️не исп. Позиция пересечения луча и плоскости. ловит только высоту = 0,
#func _get_ground_position(camera, mouse_pos) -> Vector3:
	#var ray_from = camera.project_ray_origin(mouse_pos)
	#var ray_to = ray_from + camera.project_ray_normal(mouse_pos) * 1000
	#var cursorpos = Plane(Vector3.UP, 0).intersects_ray(ray_from, ray_to) 
	#if cursorpos == null:
		#cursorpos = Vector3.ZERO
	#return cursorpos
