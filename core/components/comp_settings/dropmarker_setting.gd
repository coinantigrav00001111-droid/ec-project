class_name DropMarkerSetting extends ComponentSettings

## Ширина следа (юниты). Длина 0 = авто: 2 * coupler_offset вагона
@export var width := 3.4
@export var length := 0.0

func create_component(entity) -> Component:
	var comp := C_DropMarker.new()
	comp.width = width
	var identity = entity.get_comp(C_Identity)
	comp.length = length
	if length <= 0.0:
		comp.length = 12.0
		if identity:
			comp.length = 2.0 * identity.get_config('coupler_offset', 6.0)
	comp.name = 'C_DropMarker'
	entity.add_component(comp)
	return comp
