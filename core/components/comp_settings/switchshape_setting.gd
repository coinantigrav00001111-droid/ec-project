class_name SwitchShapeSettings extends ComponentSettings

# XX claude-switch (новый файл)
## Форма стрелки. В массиве компонентов .tres после PathSetting и до SocketSettings

func create_component(entity: Entity) -> Component:
	var comp := C_SwitchShape.new()
	comp.name = 'C_SwitchShape'
	entity.add_component(comp)
	return comp
