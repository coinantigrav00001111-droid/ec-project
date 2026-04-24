class_name TrackSettings extends ComponentSettings


@export var length: float

func create_component(_entity: Entity) -> Component:
	var comp = C_Track.new()

	comp.length = length
	
	_entity.add_component(comp)
	
	return comp
