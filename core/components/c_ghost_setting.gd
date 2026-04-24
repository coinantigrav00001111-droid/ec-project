class_name GhostSetting extends ComponentSettings


## Фабрика запускает функцию создания
func create_component(entity) -> Component:
	var comp = C_Ghost.new()

	entity.add_component(comp) # Добавили комп к объекту
	
	return comp
