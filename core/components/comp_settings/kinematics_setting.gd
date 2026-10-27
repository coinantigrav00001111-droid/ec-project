class_name KinematicsSetting extends ComponentSettings

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
		comp.slide_friction = identity.get_config('slide_friction', 0.1)
		comp.locked_wheel_friction = identity.get_config('locked_wheel_friction', 3.0)
		
		comp.max_tractive_force = identity.get_config('max_tractive_force', 0.0)	
		comp.max_theoretical_speed = identity.get_config('max_theoretical_speed', 0.0)	
		
		# "Rotation Limits (YAW)"
		comp.max_yaw_deg = identity.get_config('max_yaw_deg', 0.0)	
		comp.yaw_spring = identity.get_config('yaw_spring', 0.0)	
		#"Suspension (Travel & Play)"
		comp.suspension_stiffness = identity.get_config('suspension_stiffness', 0.0)	
		
	comp.name = 'C_Kinematics'
	entity.add_component(comp) # Добавили комп к объекту
	
	return comp
