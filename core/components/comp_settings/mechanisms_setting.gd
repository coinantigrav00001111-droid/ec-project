class_name MechanismsSetting extends ComponentSettings

## Собирает C_Mechanisms. Данные берёт из WagonConfig.mechanisms через C_Identity,
## поэтому в массиве компонентов вагона он стоит ПОСЛЕ Identity и TrainVisual.

func create_component(entity: Entity) -> Component:
	var comp := C_Mechanisms.new()
	comp.name = 'C_Mechanisms'
	entity.add_component(comp)
	return comp
