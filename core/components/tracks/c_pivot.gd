class_name C_Pivot extends Component

#######################
## 💡 Логика. Pivot offset к центру.
#######################
## Компонент сам переносит центр инстанса сцены в оффсет, указанный в редакторе. 
## если есть C_Path, то оффсет генерится в _generate_path вместо указанного по дефолту

var offset: Vector3 = Vector3.ZERO

# Entity запускает это при создании компонента
func on_added():
	# Если визуал уже есть — применяем сразу
	_apply_to_visual()


# Если появился визуал, то по ⚡Сигналу сработает
func on_component_added(type: Script):
	if type == C_TrackVisual:
		_apply_to_visual()



# Сдвигаем инстанс(сцену) в оффсет из сеттинга
func _apply_to_visual():
	var visual = get_comp(C_TrackVisual)
	if visual and visual.instance:
		visual.instance.position = offset



# Изменился офсет(в C_Path), обновляется он и инстанс
func on_offset_changed(data:Dictionary):
	offset = data.new_offset
	_apply_to_visual()



#------SAVE\LOAD----

# Сейв данных по запросу ентити
func save_data() -> Dictionary:
	return {
		
		'comp_path':get_script().resource_path,		# "res://core/components/c_power_clip.gd"
		'comp_name':get_script().resource_path.get_file().get_basename(), # "c_power_clip"
		"offset": offset
	}


func load_data(data: Dictionary) -> void:
	if data.has("offset"):
		offset = data.offset
		_apply_to_visual() # Применяем смещение к визуал-ноде
