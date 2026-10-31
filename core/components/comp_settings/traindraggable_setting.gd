class_name TrainDraggableSettings extends ComponentSettings


## Фабрика запустит эту функцию создания
func create_component(entity: Entity) -> Component:
	var comp := C_TrainDraggable.new()
	var cfg := WagonConfig.from_entity(entity)
	if cfg == null:
		push_error("TrainDraggableSettings: в паспорте (C_Identity.object_config) нет WagonConfig, параметры по умолчанию")
	else:
		comp.coupler_offset = cfg.coupler_offset   # длина метки на столе = 2 * от центра до торца
	comp.name = 'C_TrainDraggable'
	entity.add_component(comp) # Добавили комп к объекту

	return comp
