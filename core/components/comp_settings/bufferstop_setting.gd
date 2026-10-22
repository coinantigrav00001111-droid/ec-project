class_name BufferStopSettings extends ComponentSettings

# XX claude-switch (новый файл)
## Упор (C_BufferStop). В массиве компонентов .tres после PathSetting и SocketSettings

## Демпфирование буфера: больше - меньше отскок
@export var zeta := 0.25


func create_component(entity: Entity) -> Component:
	var comp := C_BufferStop.new()
	comp.name = 'C_BufferStop'
	comp.zeta = zeta
	entity.add_component(comp)
	return comp
