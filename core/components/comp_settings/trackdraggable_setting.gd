class_name DraggableSettings extends ComponentSettings


## Фабрика запустит эту функцию создания
func create_component(_entity: Entity) -> Component:
	var comp = C_TrackDraggable.new()
	comp.name = 'C_TrackDraggable'
	_entity.add_component(comp) # Добавили комп к объекту
	
	return comp
