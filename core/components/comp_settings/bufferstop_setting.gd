class_name BufferStopSettings extends ComponentSettings

# XX claude-switch (новый файл)
## Упор (C_BufferStop). В массиве компонентов .tres после PathSetting и SocketSettings.
## Значения берет из паспорта (BufferStopConfig) и переносит в компонент, как остальные Settings.

func create_component(entity: Entity) -> Component:
	var comp := C_BufferStop.new()
	comp.name = 'C_BufferStop'
	var cfg := BufferStopConfig.from_entity(entity)
	if cfg == null:
		push_error("BufferStopSettings: в паспорте (C_Identity.object_config) нет BufferStopConfig, параметры по умолчанию")
	else:
		comp.stop_at_end = cfg.stop_at_end
		comp.max_speed = cfg.max_speed
		comp.zeta = cfg.zeta
	entity.add_component(comp)
	return comp
