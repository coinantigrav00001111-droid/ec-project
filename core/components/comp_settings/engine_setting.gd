class_name EngineSetting extends ComponentSettings

## Мотор. Значения берет из паспорта (WagonConfig) и переносит в C_Engine при создании.

## Фабрика запускает функцию создания
func create_component(entity) -> Component:
	var comp := C_Engine.new()
	var cfg := WagonConfig.from_entity(entity)
	if cfg == null:
		push_error("EngineSetting: в паспорте (C_Identity.object_config) нет WagonConfig, параметры по умолчанию")
	else:
		comp.max_tractive_force = cfg.max_tractive_force
		comp.max_theoretical_speed = cfg.max_theoretical_speed

	comp.name = 'C_Engine'
	entity.add_component(comp) # Добавили комп к объекту

	return comp
