class_name SwitchSettings extends ComponentSettings

# XX claude-switch (новый файл)
## Управление стрелкой (C_Switch). Последним в массиве компонентов .tres

## MANUAL: рычаг у стрелки (клик). REMOTE: только команды управления (панель, позже провода и привод)
@export_enum("Manual", "Remote") var control: int = 0
## Время перекладки, с. 0 = мгновенно. У дистанционного привода обычно 0.3 .. 3
@export var throw_time := 0.0
## E1: ток только на выбранную ветку (невыбранная мертвая, удобно для тупиков и депо). false: обе ветки под током
@export var power_routing := false


func create_component(entity: Entity) -> Component:
	var comp := C_Switch.new()
	comp.name = 'C_Switch'
	comp.control = control as C_Switch.Drive
	comp.throw_time = throw_time
	comp.power_routing = power_routing
	entity.add_component(comp)
	return comp
