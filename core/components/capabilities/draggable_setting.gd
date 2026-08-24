class_name DraggableSettings extends ComponentSettings


## Фабрика запустит эту функцию создания
func create_component(_entity: Entity) -> Component:
	var comp = C_Draggable.new()
	comp.name = 'C_Draggable'
	_entity.add_component(comp) # Добавили комп к объекту
	
	return comp
