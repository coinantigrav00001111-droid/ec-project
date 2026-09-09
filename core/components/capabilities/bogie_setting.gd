class_name BogieSetting extends ComponentSettings

# Данные заполняются в редакторе, в массиве сеттингов
# Конфигурация тележек для данного вагона
#faaeb



## Фабрика запускает функцию создания
func create_component(entity) -> Component:
	var comp = C_Bogie.new()
	var identity = entity.get_comp(C_Identity)

	#if identity:
		#comp.bogie_configs = identity.get_config('bogie_configs')	
	
	comp.name = 'C_Bogie'
	entity.add_component(comp) # Добавили комп к объекту
	
	return comp
