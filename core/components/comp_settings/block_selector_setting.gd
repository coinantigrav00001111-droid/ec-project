class_name BlockSelectorSetting extends ComponentSettings

## Устройство коммутации (D5): создает C_BlockSelector


func create_component(entity: Entity) -> Component:
	var comp := C_BlockSelector.new()

	entity.add_component(comp)
	return comp
