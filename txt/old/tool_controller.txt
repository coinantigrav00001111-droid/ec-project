class_name ToolController extends Node3D

##########################
##  Главный инструмент для управления инструментами в режиме BUILD. 
##  Связь с UI.
##########################
## Переключает текущий инструмент - билд, селект, драг

#@onready var GR : GameRoot = $".."
@onready var world: World = $"../World"

@onready var entity_factory: EntityFactory = $"../EntityFactory"
@onready var entities_root: Node3D = %EntitiesRoot # Здесь лежат сущности




# Инструменты
@onready var build_tool: BuildTool = %BuildTool
@onready var select_tool = %SelectTool
@onready var drag_tool: DragTool = %DragTool
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
	
	# Инициализируем инструменты, передав им ссылку на себя
	for tool in %Tools.get_children():
		tool.controller = self
		
	# При старте инструмент - select_tool
	switch_tool(select_tool) 



func _unhandled_input(event: InputEvent) -> void:
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
	active_tool.enter()




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
	
	return get_world_3d().direct_space_state.intersect_ray(query)





## 💡--------------Меняем режим ---------------------------------

func on_current_mode_changed(_new_mode):
	GS.current_mode = _new_mode
	update_info.emit() 


### Получаем текущий current mode
#func get_current_mode() -> StringName:
	#return GR.current_mode


### Получаем текущий debug_mode
#func get_debug_mode() -> bool:
	#return GR.debug_mode
