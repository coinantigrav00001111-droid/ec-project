class_name ToolController extends Node3D

##########################
##  Главный инструмент для управления инструментами. 
##  Связь с UI.
##########################
## Переключает текущий инструмент - билд, селект, драг

@onready var GR : GameRoot = $".."
@onready var world: World = $"../World"

@onready var entity_factory: EntityFactory = $"../EntityFactory"
@onready var entities_root: Node3D = %EntitiesRoot # Здесь лежат сущности

# Инструменты
@onready var build_tool: BuildTool = %BuildTool
@onready var select_tool = %SelectTool
@onready var drag_tool: DragTool = %DragTool

# UI 
@onready var entity_debugger = $"../Debug/EntityDebugger"
@onready var info_panel: InfoPanel = $"../UI/InfoPanel"


# Текущий активный инструмент
var active_tool: Node 

# ⚡Сигнал обновляем инфу
signal update_info



func _ready() -> void:
	# ⚡Сигнал из моде контроллера
	$"../UI/ModeController".current_mode_changed.connect(on_current_mode_changed)
	# ⚡Сигнал из билд контроллера
	$"../UI/BuildController".object_selected.connect(_on_build_selected)
	
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



# Выбор инструмента/tool
func switch_tool(new_tool: Node):
	if active_tool: active_tool.exit()
	active_tool = new_tool
	active_tool.enter()



# ⚡выбран объект для билда - в билд-тул в бывшую  ‼️(old) btn_object_selected(_setting: EntitySetting)
func _on_build_selected(setting: EntitySetting):
	build_tool.ghost_setting = setting
	# переключение в build_tool
	switch_tool(build_tool)




# 💡 --- Общие хелперы для инструментов ---

func get_mouse_ray(mask: int = -1) -> Dictionary:
	var mouse_pos = get_viewport().get_mouse_position()
	var camera = get_viewport().get_camera_3d()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	
	#TODO Нужен не только 3 леер
	query.collision_mask = (1) if mask == -1 else mask # Земля (1) и Траки (3-й слой -> маска 4)
	
	return get_world_3d().direct_space_state.intersect_ray(query)


func align_with_normal(xform: Transform3D, normal: Vector3) -> Transform3D:
	xform.basis.y = normal
	xform.basis.x = -xform.basis.z.cross(normal).normalized()
	xform.basis = xform.basis.orthonormalized()
	return xform
	

# По поверхности
func align_to_surface(pos: Vector3, normal: Vector3) -> Transform3D:
	var up = normal
	var forward = Vector3.BACK if abs(normal.dot(Vector3.BACK)) < 0.95 else Vector3.RIGHT
	var right = forward.cross(up).normalized()
	forward = up.cross(right).normalized()
	return Transform3D(Basis(right, up, forward), pos)



## 💡--------------Меняем режим ---------------------------------

func on_current_mode_changed(_new_mode):
	GR.current_mode = _new_mode
	update_info.emit() 


## Получаем текущий current mode
func get_current_mode() -> StringName:
	return GR.current_mode


## Получаем текущий debug_mode
func get_debug_mode() -> bool:
	return GR.debug_mode
