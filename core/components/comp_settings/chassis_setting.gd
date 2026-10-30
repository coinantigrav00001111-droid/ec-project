class_name ChassisSetting extends ComponentSettings

# Смещения тележек и зазор колеса убраны (никем не читались, смещения теперь в паспорте: bogie_configs)

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
