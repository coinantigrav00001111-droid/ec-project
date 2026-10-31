class_name ChassisSetting extends ComponentSettings

# Смещения тележек и зазор колеса убраны (никем не читались, смещения теперь в паспорте: bogie_configs)

## Фабрика запускает функцию создания
func create_component(entity) -> Component:
	var comp := C_Chassis.new()
	var cfg := WagonConfig.from_entity(entity)
	if cfg == null:
		push_error("ChassisSetting: в паспорте (C_Identity.object_config) нет WagonConfig, параметры по умолчанию")
	else:
		comp.bogie_configs = cfg.bogie_configs
		comp.suspension_config = cfg.suspension   # null = значения по умолчанию (SuspensionConfig)

	comp.name = 'C_Chassis'
	entity.add_component(comp) # Добавили комп к объекту

	return comp
