class_name PathSetting extends ComponentSettings

# Данные заполняются в редакторе, в массиве сеттингов
@export var radius: float = 25.0
@export var deg: float = 0.0

## Фабрика запускает функцию создания
func create_component(entity) -> Component:
	var comp = C_Path.new()
	var identity = entity.get_comp(C_Identity)

	if identity:
		comp.radius = identity.get_config('radius', radius)	
		comp.deg = identity.get_config('deg', deg)	

	comp.name = 'C_Path'
	entity.add_component(comp) # Добавили комп к объекту
	
	return comp
