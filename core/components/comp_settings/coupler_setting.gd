class_name CouplerSetting extends ComponentSettings

## Собирает C_Coupler. Подключается в массив сеттингов компонентов вагона/локо в редакторе.
## Параметры читаются из WagonConfig через C_Identity (как в KinematicsSetting/EngineSetting),
## поэтому C_Identity должен быть создан раньше.

## Фабрика запустит эту функцию создания
func create_component(entity) -> Component:
	var comp = C_Coupler.new()
	var identity = entity.get_comp(C_Identity)

	if identity:
		comp.offset_z = identity.get_config('coupler_offset', comp.offset_z)
		comp.type_front = identity.get_config('coupler_front', comp.type_front)
		comp.type_rear = identity.get_config('coupler_rear', comp.type_rear)
		comp.slack = identity.get_config('coupler_slack', comp.slack)
		comp.buffer_travel = identity.get_config('coupler_travel', comp.buffer_travel)
		comp.strength = identity.get_config('coupler_strength', comp.strength)
		comp.couple_speed_max = identity.get_config('couple_speed_max', comp.couple_speed_max)
		comp.impact_dv_limit = identity.get_config('impact_dv_limit', comp.impact_dv_limit)

	comp.name = 'C_Coupler_с'
	entity.add_component(comp) # Добавили комп к объекту

	return comp
