class_name SocketSettings extends ComponentSettings

## Фабрика запустит эту функцию создания
func create_component(entity: Entity) -> Component:
	var comp = C_Socket.new()
	entity.add_component(comp)
	return comp
