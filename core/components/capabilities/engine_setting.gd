class_name EngineSetting extends ComponentSettings

# Данные заполняются в редакторе, в массиве сеттингов
# Коэффициент конвертации напряжения (V) в скорость/тягу
@export var speed_multiplier: float = 0.5

## Фабрика запускает функцию создания
func create_component(entity) -> Component:
	var comp = C_Engine.new()
	
	comp.speed_multiplier = speed_multiplier	
	comp.name = 'C_Engine'
	entity.add_component(comp) # Добавили комп к объекту
	
	return comp
