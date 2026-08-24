class_name IdentitySetting extends ComponentSettings


## Фабрика запускает функцию создания
func create_component(entity) -> Component:
	var comp = C_Identity.new()
	comp.name = 'C_Identity'
	entity.add_component(comp) # Добавили комп к объекту
	
	return comp
