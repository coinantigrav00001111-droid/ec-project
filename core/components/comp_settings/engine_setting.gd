class_name EngineSetting extends ComponentSettings

# Данные заполняются в редакторе, в массиве сеттингов
## Фабрика запускает функцию создания
func create_component(entity) -> Component:
	var comp = C_Engine.new()
	var identity = entity.get_comp(C_Identity)

	if identity:
		comp.max_tractive_force = identity.get_config('max_tractive_force', 0.0)	
		comp.max_theoretical_speed = identity.get_config('max_theoretical_speed', 0.0)	
		#comp.has_engine = identity.get_config('has_engine', 0.0)	
	
	comp.name = 'C_Engine'
	entity.add_component(comp) # Добавили комп к объекту
	
	return comp
