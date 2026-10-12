class_name IdentitySetting extends ComponentSettings

# конфиги для объектов - TrackConfig, WagonConfig итд 
@export var object_config : ObjectConfig

## Фабрика запускает функцию создания
func create_component(entity) -> Component:
	var comp = C_Identity.new()
	
	comp.object_config = object_config
	comp.name = 'C_Identity'
	
	entity.add_component(comp) # Добавили комп к объекту
	
	return comp
