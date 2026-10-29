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
##    или верх другого листа, свой лист луч не видит (он на слое ghost, пока драг/призрак);
##  - T5: вертикальный магнит к низу балласта плоского трака (C_TerrainLayer.snap_to_tracks).
## Снапа к сокетам у листа нет: он нужен только траку.

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
	# T5: верх листа прилипает к низу балласта плоского трака. Ниже поверхности под курсором лист не опускаем
	var layer := entity.get_comp(C_TerrainLayer) as C_TerrainLayer
	if layer:
		layer.snap_to_tracks(snappedf(data.position.y, T))
	_check_validity()


## Драг закончен. Лист на месте, где он занимает чужую площадь (C_Invalid), возвращаем туда, откуда взяли,
## затем сообщаем C_TerrainLayer, что лист окончательно встал (пересчет земли)
func on_drag_ended(_data: Dictionary) -> void:
	if entity.has_comp(C_Invalid):
		entity.global_transform = initial_transform
		_check_validity()   # на исходном месте лист валиден, красный флаг снимется
	entity.send_event("on_terrain_moved", {})


## Перекрытие с другими листами (D6). Лист сам решает, что он невалиден
func _check_validity() -> void:
	var layer := entity.get_comp(C_TerrainLayer) as C_TerrainLayer
	if layer:
		layer.update_validity()


func on_rotate_input(data: Dictionary) -> void:
	if data.axis == "y":
		rotation_euler.y += deg_to_rad(data.amount)
	if data.axis == "x":   # R/F: уровень, шаг всегда один слой
		elevation = maxi(0, elevation + int(signf(data.amount)))


## XX claude-terra 13.1.4. Крупный шаг уровня (Shift+R/F, PageUp/PageDown)
func on_elevation_input(data: Dictionary) -> void:
	elevation = maxi(0, elevation + int(data.get("levels", 0)))


## --- Клонирование состояния (BuildTool: призрак -> настоящий лист) ---

func on_clone_state_to(data: Dictionary) -> void:
	var target_entity: Entity = data.target
	var state := {
		"rotation_euler": rotation_euler,
		"elevation": elevation,
	}
	# XX claude-terra 13.2 B2: нарисованный лист (DRAW_POLYGON) переносит свою форму и толщину
	if _is_drawn():
		var contour := entity.get_comp(C_Contour) as C_Contour
		var layer := entity.get_comp(C_TerrainLayer) as C_TerrainLayer
		if contour:
			state["points"] = contour.points.duplicate()
		if layer:
			state["levels"] = layer.levels
	target_entity.send_event("on_receive_draggable_state", state)


func on_receive_draggable_state(data: Dictionary) -> void:
	if data.has("rotation_euler"):
		rotation_euler = data.rotation_euler
	if data.has("elevation"):
		elevation = data.elevation
	# XX claude-terra 13.2 B2: форма и толщина нарисованного листа
	if data.has("levels"):
		var layer := entity.get_comp(C_TerrainLayer) as C_TerrainLayer
		if layer:
			layer.set_levels(int(data.levels))
	if data.has("points"):
		var contour := entity.get_comp(C_Contour) as C_Contour
		if contour:
			contour.set_points(data.points)
		# призрак-дубль: форма готова, фаза рисования не нужна
		var draw := entity.get_comp(C_PolygonDraw) as C_PolygonDraw
		if draw:
			draw.set_preshaped()


## XX claude-terra 13.2 B2. Лист создан из пресета с build_behavior = DRAW_POLYGON или DRAW_STRIP (форму рисовал игрок)
func _is_drawn() -> bool:
	var identity := entity.get_comp(C_Identity) as C_Identity
	if identity == null or identity.setting == null:
		return false
	var b: int = identity.setting.build_behavior
	return b == EntitySetting.BuildBehavior.DRAW_POLYGON or b == EntitySetting.BuildBehavior.DRAW_STRIP


## Сброс поворота и уровня (DragTool, Home)
func on_drag_reset(_data: Dictionary) -> void:
	rotation_euler = Vector3.ZERO
	drag_offset = Vector3.ZERO
	elevation = 0
	entity.rotation = Vector3.ZERO
