class_name StyleVisualSetting extends ComponentSettings

# XX claude-terra (новый файл)
## Собирает жёсткий стилизованный трак (прямая/дуга/пандус) двумя компонентами: C_Path (centered =
## true, как у обычных траков) и C_StyleVisual. C_Path создаётся ПЕРВЫМ: на его on_entity_ready()
## генерируется curve/path_node, а C_StyleVisual (идёт следом по порядку детей) строит геометрию
## по этой кривой в СВОЁМ on_entity_ready(). Порядок важен: Path должен быть раньше визуала.
##
## Остальной массив компонентов в .tres как у обычного трека: Draggable, Pivot, Hoverable,
## Selectable, Blockable, Socket, PowerTrack, TrackSupport. radius/deg/rise берутся из
## TrackConfig (Identity), как и для сцен из Blender.

## Рельсы, шпалы, балласт. Пусто = TrackStyle по умолчанию (балласт, головка рельса 0.85)
@export var style: TrackStyle


func create_component(entity: Entity) -> Component:
	# 1. Путь: нужен ПЕРЕД визуалом (визуал строит геометрию по его кривой в on_entity_ready)
	var path := C_Path.new()
	var identity := entity.get_comp(C_Identity) as C_Identity
	if identity:
		path.radius = identity.get_config('radius', 0.0)
		path.deg = identity.get_config('deg', 0.0)
	path.centered = true   # как у обычных жёстких траков: origin в середине кривой
	path.name = 'C_Path'
	entity.add_component(path)

	# 2. Визуал: строит каркас сразу (on_added), геометрию по кривой - в on_entity_ready
	var vis := C_StyleVisual.new()
	vis.style = style
	vis.name = 'C_StyleVisual'
	entity.add_component(vis)

	return vis
