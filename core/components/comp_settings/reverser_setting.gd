class_name ReverserSetting extends ComponentSettings

## Устройство коммутации (D5): создает C_Reverser


func create_component(entity: Entity) -> Component:
	var comp := C_Reverser.new()

	entity.add_component(comp)
	return comp
