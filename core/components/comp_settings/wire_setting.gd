class_name WireSetting extends ComponentSettings

## Провод между клеммами (D4). Концы и точки излома задает WireTool или автопроводка после создания

func create_component(entity: Entity) -> Component:
	var comp := C_Wire.new()
	entity.add_component(comp)
	return comp
