class_name C_PowerClip extends Component

#######################
## 💡 Компонент клеммы питания. Точка входа напряжения (фидер).
#######################
# Данные: номер цепи (net_id, бывший contour_id: канал контроллера), текущее подаваемое напряжение.
# Логика: При добавлении в дерево регистрирует себя в контроллере и инициирует пересчет контуров дороги.
# Визуал: добавляет сцену коробочки клеммы с индикацией текущего напряжения и номера цепи
# D1 (ATTN_10 §10.5.4): на цепь можно ставить несколько клипов. Клип не удаляется при конфликте,
# а помечается `conflict`. `reversed` меняет полярность подключения (провода перепутаны).

#var scene: PackedScene
var scene: PackedScene = preload("res://data/tracks/power_clip.tscn")

var voltage: float #текущее напряжение
# Номер канала на пульте DCController (задается из UI при создании)
var net_id :int = 1

## Поменяны провода: полярность подключения клипа к рельсам обратная (знак «−» на метке).
## Цепь согласована, если развёрнутость трака относительно эталона цепи равна `reversed`
var reversed: bool = false

## Результат расчёта сети (RailNetBuilder), в сейв не пишется:
## "" нет конфликта; "label" цепь уже питает клип с меньшим номером контура; "polarity" полярность не сходится с цепью (КЗ)
var conflict: String = ""
## Номер цепи клипа-лидера при conflict == "label" (0 если конфликта нет). Ставит RailNetBuilder
var conflict_with: int = 0


# Entity запускает это при создании компонента
func on_added():
	name = 'C_PowerClip'

	# Регистрируем себя и заставляем менеджера пересчитать топологию
	PGM.register_clip(self) # добавляет клип в активный массив клипов

	var visual = get_comp(C_TrackVisual)
	if visual and visual.instance:
		# Если визуал уже есть — применяем сразу
		_add_to_visual()



# Если визуал появился позже клипа, добавляем коробочку клемы
func on_component_added(_type: Script):
	var visual := get_comp(C_TrackVisual) as C_TrackVisual
	if visual and visual.instance and visual.instance.get_node_or_null("PowerClip") == null:
		_add_to_visual()


# добавляем клип в визуал
func _add_to_visual():
	var visual = get_comp(C_TrackVisual)
	if visual == null or visual.instance == null:
		return
	var _clip = scene.instantiate() # Создаем сцену
	_clip.transform = visual.clip_transform()   # XX claude-terra: у стилизованных траков зависит от стиля и наклона
	visual.instance.add_child(_clip)
	_change_clip_label()



func on_removed():
	# При удалении клипа сеть тоже должна пересчитаться
	PGM.unregister_clip(self)

	var visual = get_comp(C_TrackVisual)
	if visual == null or visual.instance == null:
		return
	var _clip = visual.instance.get_node_or_null('PowerClip')
	if is_instance_valid(_clip):
		visual.instance.remove_child(_clip)

		_clip.queue_free()



# Задает электрику в клип
func set_power(_net_id, _voltage) -> void:

	net_id = _net_id
	voltage = _voltage
	_change_clip_label()


func set_contour(_net_id) -> void:
	net_id = _net_id
	_change_clip_label()


## «Поменять полярность»: провода клипа перепутаны. Сеть пересчитывается
func set_reversed(on: bool) -> void:
	if reversed == on:
		return
	reversed = on
	_change_clip_label()
	PGM.request_recalculate()


# Меняет показания на клипе питания (Вывод на метки)
func _change_clip_label():
	var visual = get_comp(C_TrackVisual)
	if visual == null or visual.instance == null:
		return
	var _clip_label = visual.instance.get_node_or_null('PowerClip/ContourLabel')
	if _clip_label == null: # нода клипа
		return
	var _out: PowerOutput = PGM.get_output(net_id) if net_id != 0 else null
	var _voltage := int(PGM.get_power(net_id)) if net_id != 0 else 0
	var _tripped: bool = _out != null and _out.tripped

	var _text := ("−" if reversed else "") + str(net_id) + ':  ' + str(_voltage) + '%'
	if _out != null and not _tripped and _voltage != 0:
		_text += "  %.2fA" % _out.current
	if _tripped:
		_text += "  ⚡"
	if conflict != "":
		_text += "  (!)"
	_clip_label.text = _text

	if _tripped:
		_clip_label.modulate = Color(1.0, 0.15, 0.15, 1.0)   # красный: вывод отключен защитой
	elif conflict != "":
		_clip_label.modulate = Color(1.0, 0.85, 0.15, 1.0)   # желтый: конфликт клипа
	elif _voltage >= 0:
		_clip_label.modulate = Color(0.0, 0.824, 0.0, 1.0)
	else:
		_clip_label.modulate = Color(1.0, 0.302, 0.043, 1.0)


## Текст для InfoPanel: что не так с этим клипом. Пусто, если все в порядке
func conflict_text() -> String:
	match conflict:
		"label":
			return "Конфликт: цепь уже питает вывод %d (меньший номер), этот клип не ведёт цепь" % conflict_with
		"polarity":
			return "КЗ: полярность клипа не сходится с цепью (поменяйте полярность)"
	return ""


#------SAVE\LOAD----

# Сейв данных по запросу ентити
func save_data() -> Dictionary:
	return {
		# не исп
		'comp_path':get_script().resource_path, #  "res://core/components/c_power_clip.gd"
		# не исп, для наглядности в сейве
		'comp_name':get_script().resource_path.get_file().get_basename(), # "c_power_clip"
		"net_id": net_id,
		"contour_id": net_id,   # старый ключ: сейв читается и старыми версиями
		"voltage": voltage,
		"reversed": reversed,
	}



func load_data(_data: Dictionary) -> void:
	# net_id новый ключ, contour_id из старых сейвов
	if _data.has("net_id"):
		net_id = _data.net_id
	elif _data.has("contour_id"):
		net_id = _data.contour_id
	if _data.has("voltage"):
		voltage = _data.voltage
	reversed = bool(_data.get("reversed", false))
