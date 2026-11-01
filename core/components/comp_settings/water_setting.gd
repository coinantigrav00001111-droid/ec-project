class_name WaterSetting extends ComponentSettings

# XX claude-terra 13.4 W2 (новый файл)
## Собирает водный участок: C_Water. Порядок в .tres: Identity, Water, Hoverable, Selectable.

func create_component(entity: Entity) -> Component:
	var water := C_Water.new()
	water.name = 'C_Water'
	entity.add_component(water)
	return water
