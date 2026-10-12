class_name ChassisSetting extends ComponentSettings

#TODO удалить. Уже не
@export var front_bogie_offset: float = 4.0 # Расстояние от центра до передней тележки
@export var rear_bogie_offset: float = -4.0 # Расстояние от центра до задней тележки

#@export var down_bogie_offset: float  = -0.36 # Вертикальное смещение боги от низа вагона
@export var wheel_gap: float  = 0.02 # Вертикальный зазор от кузова до колеса

## Фабрика запускает функцию создания
func create_component(entity) -> Component:
	var comp = C_Chassis.new()
	var identity = entity.get_comp(C_Identity)

	if identity:
		comp.bogie_configs = identity.get_config('bogie_configs')	

	#comp.down_bogie_offset = down_bogie_offset
	
	comp.name = 'C_Chassis'
	entity.add_component(comp) # Добавили комп к объекту
	
	return comp
