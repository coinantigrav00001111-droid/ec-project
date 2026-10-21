class_name C_TerrainDraggable extends IDraggable

# XX claude-terra (новый файл)
##################################
## Библиотека действий. Живет на листе пенопласта всегда.
##################################
## Двигает лист пенопласта, когда включен C_Drag (драг) или лист-призрак (BuildTool).
## Контракт тот же, что у C_TrackDraggable (rotation_euler, elevation, on_clone_state_to,
## on_receive_draggable_state), поэтому BuildTool и DragTool ничего о листах не знают.
##  - в Entity только yaw, лист всегда горизонтален;
##  - XZ привязываются к сетке GlobalSetting.terrain_grid_step;
##  - Y = верх поверхности под курсором + elevation уровней (layer_height). Под курсором стол
##    или верх другого листа, свой лист луч не видит (он на слое ghost, пока драг/призрак).
## Снапа к сокетам и вертикального магнита у листа нет: они нужны только траку.

var drag_offset := Vector3.ZERO     # смещение лист - мышь (только XZ)
var rotation_euler := Vector3.ZERO  # храним тут, чтобы не терять при смене тулов
var elevation := 0                  # уровней над поверхностью под курсором
var initial_transform: Transform3D  # поза до драга


## Запоминаем смещение, yaw и уровень, чтобы лист не "прыгнул" в точку курсора
func on_drag_started(data: Dictionary) -> void:
	initial_transform = entity.global_transform
	var raw_offset: Vector3 = entity.global_position - data.position
	drag_offset = Vector3(raw_offset.x, 0.0, raw_offset.z)
	rotation_euler = Vector3(0.0, entity.global_basis.get_euler().y, 0.0)
	# поверхность под курсором уже без самого листа: он перешел на слой ghost
	var T: float = Global.settings.layer_height
	elevation = maxi(0, roundi((entity.global_position.y - data.position.y) / T))


func on_drag_moved(data: Dictionary) -> void:
	var gs = Global.settings
	var T: float = gs.layer_height
	var step: float = gs.terrain_grid_step
	var target: Vector3 = data.position + drag_offset
	# верх поверхности кратен уровню (D2), snappedf страхует от накопленной погрешности
	var y: float = snappedf(data.position.y, T) + elevation * T
	var pos := Vector3(snappedf(target.x, step), y, snappedf(target.z, step))
	entity.global_transform = Transform3D(Basis(Vector3.UP, rotation_euler.y), pos)


## Драг закончен: пересчет земли делает C_TerrainLayer.on_drag_ended (этот же ивент)
func on_drag_ended(_data: Dictionary) -> void:
	pass


func on_rotate_input(data: Dictionary) -> void:
	if data.axis == "y":
		rotation_euler.y += deg_to_rad(data.amount)
	if data.axis == "x":   # R/F: уровень, шаг всегда один слой
		elevation = maxi(0, elevation + int(signf(data.amount)))


## --- Клонирование состояния (BuildTool: призрак -> настоящий лист) ---

func on_clone_state_to(data: Dictionary) -> void:
	var target_entity: Entity = data.target
	target_entity.send_event("on_receive_draggable_state", {
		"rotation_euler": rotation_euler,
		"elevation": elevation,
	})


func on_receive_draggable_state(data: Dictionary) -> void:
	if data.has("rotation_euler"):
		rotation_euler = data.rotation_euler
	if data.has("elevation"):
		elevation = data.elevation


## Сброс поворота и уровня (DragTool, Home)
func on_drag_reset(_data: Dictionary) -> void:
	rotation_euler = Vector3.ZERO
	drag_offset = Vector3.ZERO
	elevation = 0
	entity.rotation = Vector3.ZERO
