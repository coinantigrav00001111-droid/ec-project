class_name ToolController extends Node3D

##########################
##  Главный инструмент для управления инструментами в режиме BUILD. 
##  Связь с UI.
##########################
## Переключает текущий инструмент - билд, селект, драг

#@onready var GR : GameRoot = $".."
#@onready var world: World = $"../World"

@onready var entity_factory: EntityFactory = $"../EntityFactory"
@onready var entities_root: Node3D = %EntitiesRoot # Здесь лежат сущности




# Инструменты
@onready var build_tool: BuildTool = %BuildTool
@onready var select_tool = %SelectTool
@onready var drag_tool: DragTool = %DragTool
@onready var observe_tool = get_node_or_null('%ObserveTool')
#@onready var save_controller: SaveManager = %SaveManager



# UI 
@onready var build_controller: BuildController = $"../UI/BuildController"
#@onready var operate_controller: OperateController = $"../UI/OperateController"
@onready var info_controller: InfoController =  $"../UI/InfoController"
@onready var entity_debugger = $"../Debug/EntityDebugger"
@onready var info_panel: InfoPanel = $"../UI/InfoPanel"
@onready var top_panel: TopPanel = $"../UI/TopPanel"


# Текущий активный инструмент
var active_tool: Node 

# ⚡Сигнал обновляем инфу
signal update_info



func _ready() -> void:
	# ⚡Сигнал из моде контроллера
	$"../UI/ModeController".current_mode_changed.connect(on_current_mode_changed)
	
	# ⚡Сигнал из билд контроллера
	build_controller.object_selected.connect(_on_build_selected)
	#operate_controller.object_selected.connect(_on_operate_selected)
	#build_controller.object_deselected.connect(build_controller._on_object_deselected)
	
	# ⚡Сигнал из топпанели нажат пункт меню контроллера
	#top_panel.menu_button_pressed.connect(_on_menu_button_pressed)
	
	# XX claude-terra 13.1.4: дубль последнего объекта. Кнопка в панели Build и сигнал BuildTool обратно в кнопку
	build_controller.duplicate_requested.connect(duplicate_last_object)
	build_tool.last_changed.connect(build_controller.on_last_changed)

	# Инициализируем инструменты, передав им ссылку на себя
	for tool in %Tools.get_children():
		tool.controller = self
		
	# При старте инструмент - select_tool
	switch_tool(select_tool) 



func _unhandled_input(event: InputEvent) -> void:
	# XX claude-terra 13.1.7: Z - показать или скрыть зоны проблем flex (радиус, уклон) в режиме Build
	var kz := event as InputEventKey
	if kz and kz.pressed and not kz.echo and kz.keycode == KEY_Z and Global.current_mode == &'build' \
			and not (kz.ctrl_pressed or kz.alt_pressed or kz.shift_pressed or kz.meta_pressed):
		Global.flex_zones = not Global.flex_zones
		get_viewport().set_input_as_handled()
		return
	# XX claude-terra 13.1.4: V - дубль последнего объекта (в Build, из SelectTool и BuildTool)
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_V \
			and not (k.ctrl_pressed or k.alt_pressed or k.shift_pressed or k.meta_pressed):
		duplicate_last_object()
		if build_tool.can_duplicate() and Global.current_mode == &'build':
			get_viewport().set_input_as_handled()
			return
	if active_tool: 
		active_tool.handle_input(event) # Смотрит ввод активного инструмента



func _process(delta: float) -> void:
	if active_tool and active_tool.has_method("process_tick"):
		active_tool.process_tick(delta) # Смотрит тик активного инструмента
	#$"../UI/ModeLabel".text = active_tool.name

var to_drag := false

# Выбор инструмента/tool
func switch_tool(new_tool: Node):
	if active_tool: 
		# При выходе в драг надо без  отмены селект
		var _to_drag = active_tool == $%SelectTool and new_tool == %DragTool
		#to_drag = _to_drag
		active_tool.exit(_to_drag)

	active_tool = new_tool
	Hints.set_tool(active_tool.name)
	active_tool.enter()




# XX claude-terra 13.1.4
## Дубль последнего поставленного объекта. Только в режиме Build и только из SelectTool или BuildTool
## (в драге, Observe и т.п. клавиша ничего не делает)
func duplicate_last_object() -> void:
	if Global.current_mode != &'build' or not build_tool.can_duplicate():
		return
	if active_tool == select_tool or active_tool == build_tool:
		build_tool.duplicate_last()



# ⚡Сигнал выбран объект для билда
func _on_build_selected(setting: EntitySetting):
	if setting == null :
		# Очищаем селекта в UI если null
		build_controller.object_deselected()
		return

	build_tool.ghost_setting = setting
	# переключение в build_tool
	switch_tool(build_tool)




# ------- MENU -----------
# ⚡Сигнал из toppanel\верхнего меню .
# TODO Можно переносить В сейвменеджер.Это его зона ответсвенности.
#func _on_menu_button_pressed(idx : int) -> void:
	 #Пока все индексы передаем в save контроллер
	#SaveManager.menu_click_handling(idx)



# 💡 --- Общие хелперы для инструментов ---

func get_mouse_ray(mask: int = -1) -> Dictionary:
	var mouse_pos = get_viewport().get_mouse_position()
	var camera = get_viewport().get_camera_3d()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	#TODO Нужен не только 3 леер
	query.collision_mask = (1) if mask == -1 else mask # Земля (1) и Траки (3-й слой -> маска 4)
	
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	# Боковая грань и кромка стола (слой ground) не поверхность: иначе трак или вагон встанет ниже столешницы
	if not hit.is_empty() and hit.collider is CollisionObject3D \
			and (hit.collider.collision_layer & Global.active_layers(['ground'])) != 0 \
			and hit.normal.y < 0.7:
		return {}
	return hit



## Точка луча мыши на плоскости y (по умолчанию уровень стола). Запасной вариант, когда луч не попал в стол:
## например, кнопка спавна на панели находится не над столом
func get_mouse_plane_hit(y := 0.0) -> Dictionary:
	var mouse_pos := get_viewport().get_mouse_position()
	var camera := get_viewport().get_camera_3d()
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	var p = Plane(Vector3.UP, y).intersects_ray(from, dir)
	if p == null:
		return {}
	return {"position": p, "normal": Vector3.UP, "collider": null}


## Луч из камеры в мир (для драга по плоскости, считает сам компонент)
func get_mouse_ray_vec() -> Dictionary:
	var mouse_pos := get_viewport().get_mouse_position()
	var camera := get_viewport().get_camera_3d()
	return {"from": camera.project_ray_origin(mouse_pos), "dir": camera.project_ray_normal(mouse_pos)}
	


## 💡--------------Меняем режим ---------------------------------

func on_current_mode_changed(_new_mode):
	Global.current_mode = _new_mode
	Hints.set_mode(_new_mode)
	# Observe: инструмент без выбора и драга. Выход из прежнего инструмента сам снимает выделение и призрака
	if observe_tool:
		if _new_mode == &'observe':
			switch_tool(observe_tool)
		elif active_tool == observe_tool:
			switch_tool(select_tool)
	update_info.emit() 


### Получаем текущий current mode
#func get_current_mode() -> StringName:
	#return GR.current_mode


### Получаем текущий debug_mode
#func get_debug_mode() -> bool:
	#return GR.debug_mode
