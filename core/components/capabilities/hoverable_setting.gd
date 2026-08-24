class_name HoverableSetting extends ComponentSettings

## Фабрика запустит эту функцию создания
func create_component(_entity: Entity) -> Component:
	var comp = C_Hoverable.new()
	comp.name = 'C_Hoverable'
	_entity.add_component(comp) # Добавили комп к объекту
	
	return comp
