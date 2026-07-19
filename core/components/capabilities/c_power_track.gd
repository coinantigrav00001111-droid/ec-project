class_name C_PowerTrack extends IPowerable

##################################
## Библиотека действий. Она живет на объекте всегда.
##################################
## способность проводить ток 
## компонент принимает напряжение, передает другим сущностям


var voltage: float #текущее напряжение
var contour_id :int = 0 # Контур питания. 0 -не подключен к клипу
var is_flipped :bool = false # разворот пути относительно эталонного(клип-трак - эталон)

var power_schema_mesh : PlaneMesh

func on_added():
	#TODO  перекинуть в on_entity_ready можно
	entity.add_to_group('power_track')
	

func on_entity_ready() -> void:
	# Создаем Power схему 
	_generate_power_schema()


func _generate_power_schema() -> void:
	var _mesh_inst = MeshInstance3D.new()
	power_schema_mesh = PlaneMesh.new()
	_mesh_inst.mesh = power_schema_mesh

	
	entity.add_child(_mesh_inst)
	_mesh_inst.name = 'PowerSchemaMesh'
	
	# Размер и Позицию берем из path
	var _path_comp = entity.get_comp(C_Path) as C_Path
	# Position
	#_mesh_inst.position = Vector3(0.0, 0.61, -11.95)
	#_mesh_inst.position = -_path_comp.path_node.position
	print(_mesh_inst.position)
	_mesh_inst.position.y = 0.7
	
	# Size
	power_schema_mesh.size = Vector2(2.0, _path_comp.radius)
	_mesh_inst.set_layer_mask(1<<2) # Подключаем только к 3 слою
	# это эквивалент, только сначала надо отключать другие слои
	#_mesh_inst.set_layer_mask_value(3,true)
	
	
func on_removed():
	# Если рельс удалили (DragTool/Delete), нужно пнуть менеджера пересчитать сеть
	if contour_id != 0:
		PowerGridManager.recalculate_grid()

# Сейв данных по запросу ентити
func save_data() -> Dictionary:
	return {
		# не исп
		'comp_path':get_script().resource_path, #  "res://core/components/c_power_clip.gd"
		# не исп, для наглядности в сейве
		'comp_name':get_script().resource_path.get_file().get_basename(), # "c_power_clip"
		"contour_id": contour_id,
		"voltage": voltage,

	}



func load_data(_data: Dictionary) -> void:
	if _data.has("contour_id"):
		contour_id = _data.contour_id
	if _data.has("voltage"):
		voltage = _data.voltage
