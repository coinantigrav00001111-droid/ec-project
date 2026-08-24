class_name PowerTrackSettings extends ComponentSettings

## Фабрика запустит эту функцию создания
func create_component(entity: Entity) -> Component:
	var comp = C_PowerTrack.new()
	
	comp.name = 'C_PowerTrack'
	entity.add_component(comp) # Добавили комп к объекту
	
	return comp
