class_name C_PowerTrack extends IPowerable

##################################
## Библиотека действий. Она живет на объекте всегда.
##################################
## способность проводить ток 
## компонент принимает напряжение, передает другим сущностям


#var voltage: float #текущее напряжение не используется
#var power_schema_mesh : PlaneMesh

# Контур питания. 0 -не подключен к клипу
var contour_id :int = 0: 
	set(val):
		contour_id = val

# разворот пути относительно эталонного(клип-трак - эталон)
var is_flipped :bool = false 



func on_added():
	entity.add_to_group('power_track')
	pass
	

func on_entity_ready() -> void:
	pass



func on_removed():
	# Если рельс удалили (DragTool/Delete), нужно пнуть менеджера пересчитать сеть
	if contour_id != 0:
		PGM.request_recalculate()


# Сейв данных по запросу ентити
func save_data() -> Dictionary:
	return {
		# не исп
		'comp_path':get_script().resource_path, #  "res://core/components/c_power_clip.gd"
		# не исп, для наглядности в сейве
		'comp_name':get_script().resource_path.get_file().get_basename(), # "c_power_clip"
		"contour_id": contour_id,
		#"voltage": voltage,
		"is_flipped": is_flipped,

	}



func load_data(_data: Dictionary) -> void:
	if _data.has("contour_id"):
		contour_id = _data.contour_id
	#if _data.has("voltage"):
		#voltage = _data.voltage
	if _data.has("is_flipped"):
		is_flipped = _data.is_flipped
