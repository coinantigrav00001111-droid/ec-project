class_name PowerSourceSetting extends ComponentSettings

## 3D-пульт питания (D4). Модель из PowerModels: standard (1 вывод), dual (A и B), multi (10 выводов)
@export var model: StringName = &"standard"

func create_component(entity: Entity) -> Component:
	var comp := C_PowerSource.new()
	comp.model = model if PowerModels.has_model(model) else PowerModels.MULTI
	entity.add_component(comp)
	return comp
