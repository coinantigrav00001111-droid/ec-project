class_name FuseSetting extends ComponentSettings

## Устройство коммутации (D5): создает C_Fuse
@export var limit_a := 1.0

func create_component(entity: Entity) -> Component:
	var comp := C_Fuse.new()
	comp.limit_a = limit_a
	entity.add_component(comp)
	return comp
