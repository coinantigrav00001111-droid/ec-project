class_name ChassisSetting extends ComponentSettings

# Данные заполняются в редакторе, в массиве сеттингов
@export var front_bogie_offset: float = 4.0 # Расстояние от центра до передней тележки
@export var rear_bogie_offset: float = -4.0 # Расстояние от центра до задней тележки

## Фабрика запускает функцию создания
func create_component(entity) -> Component:
	var comp = C_Chassis.new()
	
	comp.front_bogie_offset = front_bogie_offset	
	comp.rear_bogie_offset = rear_bogie_offset
	comp.name = 'C_Chassis'
	entity.add_component(comp) # Добавили комп к объекту
	
	return comp
