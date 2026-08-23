class_name C_KinematicsSetting extends ComponentSettings

# Данные заполняются в редакторе, в массиве сеттингов
@export var mass: float = 0.2 # Кг
@export var max_grip: float = 5.0 # Максимальная удерживающая сила реборды
@export var roll_resistance: float = 0.05 # Трение качения

## Фабрика запускает функцию создания
func create_component(entity) -> Component:
	var comp = C_Kinematics.new()
	
	comp.mass = mass	
	comp.max_grip = max_grip
	comp.roll_resistance = roll_resistance
	comp.name = 'C_Kinematics'
	entity.add_component(comp) # Добавили комп к объекту
	
	return comp
