class_name CrossingShapeSettings extends ComponentSettings

# XX claude-switch (новый файл)
## Форма кросса. В массиве компонентов .tres после PathSetting и до SocketSettings

func create_component(entity: Entity) -> Component:
	var comp := C_CrossingShape.new()
	comp.name = 'C_CrossingShape'
	entity.add_component(comp)
	return comp
