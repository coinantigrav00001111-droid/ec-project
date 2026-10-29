class_name TerrainLayerSetting extends ComponentSettings

# XX claude-terra (новый файл)
## Собирает лист пенопласта одним компонентом настроек: C_Contour (прямоугольник по size), C_TerrainLayer и C_ContourHandle.
## Порядок в массиве компонентов .tres: Identity (TerrainConfig), TerrainLayer, TerrainDraggable, Hoverable, Selectable.
## Identity должен идти первым: размер и толщину берем из его TerrainConfig.

## Материалы стадий. null = встроенные
@export var style: TerrainStyle


func create_component(entity: Entity) -> Component:
	var size := Vector2(20.0, 20.0)
	var levels := 1
	var identity := entity.get_comp(C_Identity) as C_Identity
	if identity:
		size = identity.get_config('size', size)
		levels = int(identity.get_config('levels', levels))

	# 1. Контур. set_rect до add_component: entity еще нет, событие не шлется, данные просто лежат
	var contour := C_Contour.new()
	contour.name = 'C_Contour'
	contour.set_rect(size)
	entity.add_component(contour)

	# 2. Визуал и коллизия (строятся в on_entity_ready, когда контур уже на месте)
	var layer := C_TerrainLayer.new()
	layer.name = 'C_TerrainLayer'
	layer.levels = maxi(1, levels)
	layer.style = style
	entity.add_component(layer)

	# 3. XX claude-terra 13.2 B3: ручки правки контура (видны только у выбранного листа)
	var handle := C_ContourHandle.new()
	entity.add_component(handle)

	return layer
