class_name KinematicsSetting extends ComponentSettings

#TODO удалить. Уже не  Данные заполняются в редакторе, в массиве сеттингов
var mass: float = 0.2 # Кг
var max_grip: float = 5.0 # Максимальная удерживающая сила реборды
var roll_resistance: float = 0.05 # Трение качения

## Фабрика запускает функцию создания
func create_component(entity) -> Component:
	var comp = C_Kinematics.new()
	var identity = entity.get_comp(C_Identity)

	if identity:
		comp.mass = identity.get_config('mass', mass)	
		comp.max_grip = identity.get_config('max_grip', max_grip)	
		comp.roll_resistance = identity.get_config('roll_resistance', roll_resistance)	

	comp.name = 'C_Kinematics'
	entity.add_component(comp) # Добавили комп к объекту
	
	return comp
