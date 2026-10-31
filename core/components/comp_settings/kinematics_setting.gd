class_name KinematicsSetting extends ComponentSettings

## Физика вагона. Значения берет из паспорта (WagonConfig) и переносит в C_Kinematics при создании.

## Фабрика запускает функцию создания
func create_component(entity) -> Component:
	var comp := C_Kinematics.new()
	var cfg := WagonConfig.from_entity(entity)
	if cfg == null:
		push_error("KinematicsSetting: в паспорте (C_Identity.object_config) нет WagonConfig, параметры по умолчанию")
	else:
		comp.mass = cfg.mass
		comp.max_grip = cfg.max_grip
		comp.roll_resistance = cfg.roll_resistance
		comp.longitudinal_grip = cfg.longitudinal_grip
		comp.min_curve_radius = cfg.min_curve_radius
		comp.slide_friction = cfg.slide_friction
		comp.locked_wheel_friction = cfg.locked_wheel_friction
		comp.max_tractive_force = cfg.max_tractive_force
		comp.max_theoretical_speed = cfg.max_theoretical_speed
		# "Rotation Limits (YAW)"
		comp.max_yaw_deg = cfg.max_yaw_deg
		comp.yaw_spring = cfg.yaw_spring

	comp.name = 'C_Kinematics'
	entity.add_component(comp) # Добавили комп к объекту

	return comp
