class_name SwitchSettings extends ComponentSettings

# XX claude-switch (новый файл)
## Управление стрелкой (C_Switch). Последним в массиве компонентов .tres

## MANUAL: рычаг у стрелки (клик). REMOTE: только команды управления (панель, позже провода и привод)
@export_enum("Manual", "Remote") var control: int = 0
## Время перекладки, с. 0 = мгновенно. У дистанционного привода обычно 0.3 .. 3
@export var throw_time := 0.0
## E1: ток только на выбранную ветку (невыбранная мертвая, удобно для тупиков и депо). false: обе ветки под током
@export var power_routing := false
## E2: тип крестовины. Insulated: пластиковая, КЗ нет. Live fixed: токопроводящая, привязана к пути 0, на пути 1 при
## проезде КЗ. Live switched: полярность крестовины переключается вместе со стрелкой (контакты привода, реле).
## При power_routing КЗ нет в любом режиме
@export_enum("Insulated", "Live fixed", "Live switched") var frog: int = 0


func create_component(entity: Entity) -> Component:
	var comp := C_Switch.new()
	comp.name = 'C_Switch'
	comp.control = control as C_Switch.Drive
	comp.throw_time = throw_time
	comp.power_routing = power_routing
	comp.frog = frog as C_Switch.Frog
	entity.add_component(comp)
	return comp
