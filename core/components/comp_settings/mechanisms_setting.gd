class_name MechanismsSetting extends ComponentSettings

## Собирает C_Mechanisms. Данные (WagonConfig.mechanisms и WagonConfig.lights) берет из паспорта,
## поэтому в массиве компонентов вагона он стоит ПОСЛЕ Identity и TrainVisual.

func create_component(entity: Entity) -> Component:
	var comp := C_Mechanisms.new()
	var cfg := WagonConfig.from_entity(entity)
	if cfg == null:
		push_error("MechanismsSetting: в паспорте (C_Identity.object_config) нет WagonConfig, параметры по умолчанию")
	else:
		comp.mechanism_configs = cfg.mechanisms
		comp.light_configs = cfg.lights
	comp.name = 'C_Mechanisms'
	entity.add_component(comp)
	return comp
