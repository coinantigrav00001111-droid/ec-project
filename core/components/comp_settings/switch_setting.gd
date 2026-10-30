class_name SwitchSettings extends ComponentSettings

# XX claude-switch (новый файл)
## Управление стрелкой (C_Switch). Последним в массиве компонентов .tres.
## Значения (control, throw_time, power_routing, frog, start_route) берет из паспорта (SwitchConfig) и переносит
## в компонент как начальное состояние. Дальше состояние живет в компоненте и сохраняется в save_data.

func create_component(entity: Entity) -> Component:
	var comp := C_Switch.new()
	comp.name = 'C_Switch'
	var cfg := SwitchConfig.from_entity(entity)
	if cfg == null:
		push_error("SwitchSettings: в паспорте (C_Identity.object_config) нет SwitchConfig, параметры по умолчанию")
	else:
		comp.control = cfg.control as C_Switch.Drive
		comp.throw_time = cfg.throw_time
		comp.power_routing = cfg.power_routing
		comp.frog = cfg.frog as C_Switch.Frog
		comp.start_route = cfg.start_route
	entity.add_component(comp)
	return comp
