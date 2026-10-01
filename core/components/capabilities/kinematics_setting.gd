class_name KinematicsSetting extends ComponentSettings

#TODO удалить. Уже не  Данные заполняются в редакторе, в массиве сеттингов
#var mass: float = 0.0 # Кг
#var max_grip: float = 0.0 # Максимальная удерживающая сила реборды
#var roll_resistance: float = 0.0 # Трение качения
# --- НОВЫЕ ПАРАМЕТРЫ ---
#var longitudinal_grip: float = 3.0
#var min_curve_radius: float = 0.0 
#var max_tractive_force: float = 0.0 
#var max_theoretical_speed: float = 0.0 
#var has_engine: bool = false

## Фабрика запускает функцию создания
func create_component(entity) -> Component:
	var comp = C_Kinematics.new()
	var identity = entity.get_comp(C_Identity)

	if identity:
		comp.mass = identity.get_config('mass', 0.0)	
		comp.max_grip = identity.get_config('max_grip', 0.0)	
		comp.roll_resistance = identity.get_config('roll_resistance', 0.0)	
		
		comp.longitudinal_grip = identity.get_config('longitudinal_grip', 0.0)	
		comp.min_curve_radius = identity.get_config('min_curve_radius', 0.0)	
		comp.max_tractive_force = identity.get_config('max_tractive_force', 0.0)	
		comp.max_theoretical_speed = identity.get_config('max_theoretical_speed', 0.0)	
		comp.has_engine = identity.get_config('has_engine', 0.0)	
		
	comp.name = 'C_Kinematics'
	entity.add_component(comp) # Добавили комп к объекту
	
	return comp
