class_name PivotSettings extends ComponentSettings

# для каждого ентити прописываем в редакторе
# если в ентити есть C_Path, то оффсет генерится в _generate_path вместо указанного по дефолту

@export var offset: Vector3 = Vector3.ZERO

func create_component(entity: Entity) -> Component:
	var comp = C_Pivot.new()
	comp.name = 'C_Pivot'
	comp.offset = offset
	entity.add_component(comp)
	return comp
