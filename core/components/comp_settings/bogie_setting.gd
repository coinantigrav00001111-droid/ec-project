class_name BogieSetting extends ComponentSettings

# Конфигурация тележек для данного вагона берется из паспорта (WagonConfig.bogie_configs)

## Фабрика запускает функцию создания
func create_component(entity) -> Component:
	var comp := C_Bogie.new()
	var cfg := WagonConfig.from_entity(entity)
	if cfg == null:
		push_error("BogieSetting: в паспорте (C_Identity.object_config) нет WagonConfig, параметры по умолчанию")
	else:
		comp.bogie_configs = cfg.bogie_configs

	comp.name = 'C_Bogie'
	entity.add_component(comp) # Добавили комп к объекту

	return comp
