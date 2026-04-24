class_name PivotSettings extends ComponentSettings

# для каждого ентити прописываем в редакторе
@export var offset: Vector3 = Vector3.ZERO

func create_component(entity: Entity) -> Component:
	var comp = C_Pivot.new()
	comp.offset = offset
	entity.add_component(comp)
	return comp
