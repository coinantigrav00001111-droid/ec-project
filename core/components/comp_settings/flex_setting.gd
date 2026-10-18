class_name FlexSetting extends ComponentSettings

# XX claude-terra (новый файл)
## Собирает flex-трак одним компонентом настроек: C_VisualFlex, C_Path (centered = false), C_FlexShape.
## Порядок в массиве компонентов .tres: Identity, FlexSetting, Draggable, Pivot, Hoverable, Selectable,
## Blockable, Socket, PowerTrack, TrackSupport. Identity: TrackConfig с radius = 10 (начальная прямая).

@export var settings: VisualStateSettings = preload("res://core/visual/visual_state.tres")
## Рельсы, шпалы, балласт. Пусто = TrackStyle по умолчанию (балласт, головка рельса 0.85)
@export var style: TrackStyle


func create_component(entity: Entity) -> Component:
	# 1. Визуал (строит ноды Ballast / HeadStaticBody3D в коде)
	var vis := C_VisualFlex.new()
	vis.visual_settings = settings
	vis.style = style

	vis.name = 'C_VisualFlex'
	entity.add_component(vis)

	# 2. Путь: origin в начале кривой
	var path := C_Path.new()
	var identity := entity.get_comp(C_Identity) as C_Identity
	if identity:
		path.radius = identity.get_config('radius', 10.0)
		path.deg = identity.get_config('deg', 0.0)
	path.centered = false
	path.name = 'C_Path'
	entity.add_component(path)

	# 3. Форма (после C_Path: в on_entity_ready он уже построен)
	var shape := C_FlexShape.new()
	shape.name = 'C_FlexShape'
	entity.add_component(shape)
	
	# 4. Ручки изгибов (после C_FlexShape)
	var handles := C_FlexHandle.new()
	handles.name = 'C_FlexHandle'
	entity.add_component(handles)
	
	return vis
