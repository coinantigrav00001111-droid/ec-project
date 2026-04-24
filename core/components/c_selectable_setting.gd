class_name SelectableSetting extends ComponentSettings


## Фабрика запустит эту функцию создания
func create_component(_entity: Entity) -> Component:
	var comp = C_Selectable.new()
	
	_entity.add_component(comp) # Добавили комп к объекту
	
	return comp
