class_name TerrainDraggableSetting extends ComponentSettings

# XX claude-terra (новый файл)

## Фабрика запустит эту функцию создания
func create_component(entity: Entity) -> Component:
	var comp := C_TerrainDraggable.new()
	comp.name = 'C_TerrainDraggable'
	entity.add_component(comp)

	return comp
