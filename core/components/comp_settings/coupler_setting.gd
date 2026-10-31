class_name CouplerSetting extends ComponentSettings

## Собирает C_Coupler. Подключается в массив сеттингов компонентов вагона/локо в редакторе.
## Параметры берет из паспорта (WagonConfig), поэтому C_Identity должен быть создан раньше.

## Фабрика запустит эту функцию создания
func create_component(entity) -> Component:
	var comp := C_Coupler.new()
	var cfg := WagonConfig.from_entity(entity)
	if cfg == null:
		push_error("CouplerSetting: в паспорте (C_Identity.object_config) нет WagonConfig, параметры по умолчанию")
	else:
		comp.offset_z = cfg.coupler_offset
		comp.type_front = cfg.coupler_front
		comp.type_rear = cfg.coupler_rear
		comp.slack = cfg.coupler_slack
		comp.buffer_travel = cfg.coupler_travel
		comp.strength = cfg.coupler_strength
		comp.couple_speed_max = cfg.couple_speed_max
		comp.impact_dv_limit = cfg.impact_dv_limit

	comp.name = 'C_Coupler_с'
	entity.add_component(comp) # Добавили комп к объекту

	return comp
