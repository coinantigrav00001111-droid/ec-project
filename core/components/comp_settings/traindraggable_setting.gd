class_name TrainDraggableSettings extends ComponentSettings


## Фабрика запустит эту функцию создания
func create_component(_entity: Entity) -> Component:
	var comp = C_TrainDraggable.new()
	comp.name = 'C_TrainDraggable'
	_entity.add_component(comp) # Добавили комп к объекту
	
	return comp
