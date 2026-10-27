class_name SwitchVisualSettings extends ComponentSettings

# XX claude-switch (новый файл)
## Визуал стрелки: процедурный, как у flex. Первым после Identity в массиве компонентов .tres

## Рельсы, шпалы, балласт. Пусто = TrackStyle по умолчанию (как у flex)
@export var style: TrackStyle
## Рычаг у носка. Выключить у траков без переключения (например, упор)
@export var lever := true


func create_component(entity: Entity) -> Component:
	var vis := C_SwitchVisual.new()
	vis.style = style
	vis.with_lever = lever
	vis.name = 'C_SwitchVisual'
	entity.add_component(vis)
	return vis
