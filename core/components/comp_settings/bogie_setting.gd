class_name BogieSetting extends ComponentSettings

# Данные заполняются в редакторе, в массиве сеттингов
# Конфигурация тележек для данного вагона
#faaeb



## Фабрика запускает функцию создания
func create_component(entity) -> Component:
	var comp = C_Bogie.new()

	comp.name = 'C_Bogie'
	entity.add_component(comp) # Добавили комп к объекту
	
	return comp
