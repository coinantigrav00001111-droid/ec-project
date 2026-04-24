class_name DragSetting extends ComponentSettings


## Фабрика запускает функцию создания
func create_component(_entity: Entity) -> Component:
	var comp = C_Drag.new()

	_entity.add_component(comp) # Добавили комп к объекту
	return comp
