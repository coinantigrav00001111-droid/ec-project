class_name C_PowerClip extends Component

#######################
## 💡 Компонент клеммы питания. Точка входа напряжения.
#######################
# Данные: Ссылка на канал контроллера (contour_id), текущее подаваемое напряжение.
# Логика: При добавлении в дерево регистрирует себя в контроллере и инициирует пересчет контуров дороги.
# Визуал: добавляет сцену коробочки клеммы с индикацией текущего напряжения и id контура

#var scene: PackedScene 
var scene: PackedScene = preload("res://data/tracks/power_clip.tscn")

var voltage: float #текущее напряжение
# Номер канала на пульте DCController (задается из UI при создании)
var contour_id :int = 1


# Entity запускает это при создании компонента
func on_added():
	name = 'C_PowerClip'
		
	# Регистрируем себя и заставляем менеджера пересчитать топологию
	PGM.register_clip(self) # добавляет клип в активный массив клипов
	
	var visual = get_comp(C_TrackVisual)
	if visual and visual.instance:
		# Если визуал уже есть — применяем сразу
		_add_to_visual()



# Если появился визуал, то по ⚡Сигналу сработает
func on_component_added(type: Script):
	if type == C_TrackVisual:
		#_add_to_visual()
		pass


# добавляем клип в визуал 
func _add_to_visual():
	var visual = get_comp(C_TrackVisual)
	var _clip = scene.instantiate() # Создаем сцену
	_clip.position = Vector3(2.2, 0.3, -2.2)
	visual.instance.add_child(_clip)
	_change_clip_label()
		


func on_removed():
	# При удалении клипа сеть тоже должна пересчитаться
	PGM.unregister_clip(self)
	
	var visual = get_comp(C_TrackVisual)
	var _clip = visual.instance.get_node_or_null('PowerClip')
	if is_instance_valid(_clip):
		visual.instance.remove_child(_clip)
	
		_clip.queue_free()



# Задает электрику в клип
func set_power(_contour_id, _voltage) -> void:
	
	contour_id = _contour_id
	voltage = _voltage
	_change_clip_label()


func set_contour(_contour_id) -> void:
	contour_id = _contour_id
	_change_clip_label()


# Меняет показания на клипе питания (Вывод на метки)
func _change_clip_label():
	var visual = get_comp(C_TrackVisual)
	var _clip_label = visual.instance.get_node_or_null('PowerClip/ContourLabel')
	var _is_stopped =  PGM.power_pwm[contour_id]["is_stopped"] if contour_id != 0 else false
	var _voltage = PGM.power_pwm[contour_id]['voltage']  if !(contour_id == 0  or _is_stopped) else 0
		
	if _clip_label: # нода клипа 
		_clip_label.text = str(contour_id) + ':  ' + str(_voltage) + '%'
		
		if  _voltage >= 0:
			_clip_label.modulate = Color(0.0, 0.824, 0.0, 1.0)
		else:
			_clip_label.modulate = Color(1.0, 0.302, 0.043, 1.0)
			
			

#------SAVE\LOAD----

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
