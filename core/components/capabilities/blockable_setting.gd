class_name BlockableSettings extends ComponentSettings


## Фабрика запустит эту функцию создания
func create_component(_entity: Entity) -> Component:
	var comp = C_Blockable.new()
	comp.name = 'C_Blockable'
	_entity.add_component(comp) # Добавили комп к объекту
	
	return comp
