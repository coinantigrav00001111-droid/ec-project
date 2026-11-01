extends Node
# class_name PowerGridManager название класса отменяем, так как теперь это синглтон PGM
###########################
##💡 PGM - Системный сервис(autoload), контроль енергосети
############################
##
## Хранит массив состояний всех доступных цепей
##
## Пульт (UI Panel или 3D Entity): Выступает просто устройством ввода. Когда игрок дергает ручку, пульт лишь передает команду в PGM: "Обнови target_voltage в цепи №2 на 60".
##
## Подключает распределяет питание по тракам
## Подача питания  в цепь осуществляет поверклип компонент, который можно подключить на некоторые типы траков.
##
## power_pwm - Словарь, в котором есть все контуры и питание на них, и останов
##
## D1 (ATTN_10): топологию цепей считает RailNetBuilder (граф с чётностью), а не обход в ширину от каждого клипа.
## Клипы не удаляются при конфликте, КЗ полярности это состояние цепи.
@onready var dc_controller: Panel #= $"/root/GameRoot/UI/DCControlPanel" #$"/root/GameRoot/Gimbal"
# Максимальное количество контуров в сети. Не связано с DCC контроллером, там отдельно регулировать слайдер
const MAX_CONTOURS = 10

# pwm - принцип ШИМ. словарь контуров заполняется нулями на старте
# текущее питание в цепи ключ - net_id (номер контура), значение - словарь:
#power_pwm {"voltage": 0, "is_stopped": false}
var power_pwm : Dictionary = {}

# Список всех активных КЛИПОВ на столе
var active_clips: Array[C_PowerClip] = []

# Флаг включения визуального повер-слоя
var is_power_layer_active: bool = false

# флаг ожидания пересчета сети
var _recalc_pending: bool = false

## Строит граф цепей (хранит список виденных траков между пересчетами)
var _builder := RailNetBuilder.new()

## Сводка по цепям после последнего пересчета: net_id -> {feeders, tracks, conflicts, short}
var net_info: Dictionary = {}

## Цепи, которые сейчас в КЗ полярности (net_id -> true). При подаче напряжения такая цепь отключается защитой
var shorted_nets: Dictionary = {}

## Время последнего пересчета сети, мкс (замер для бюджета, ATTN_10 §10.5.1)
var last_recalc_usec: int = 0
## Печатать время пересчета в Output (только debug)
var log_recalc: bool = false

## ⚡Сигналы
# ⚡Сигнал о включении визуального повер-слоя на столе
signal power_layer_toggled(is_active: bool)

# ⚡Сигналы в UI
@warning_ignore("unused_signal")
signal power_tab_updated()  # вся панель обновляется
signal power_updated(contour_id: int, new_voltage: float) # Обновл. данные трака по ручке
# XX claude-switch: контур отключен защитой (КЗ на крестовине стрелки или полярности). Сброс: emergency_stop(false) или reset_contour
signal contour_tripped(contour_id: int, reason: String)
## ⚡Состояние сети сброшено (новая или загруженная партия): пульты ставят ручки в ноль
signal state_reset()



func _ready() -> void:
	# Преаллокация при старте игры
	_fill_channels()


func _fill_channels() -> void:
	power_pwm.clear()
	for i in range(1, MAX_CONTOURS + 1):
		power_pwm[i] = {
			"voltage": 0,
			"is_stopped": false # Для аварийного тормоза
		}


## Сброс состояния сети: напряжения 0, защита снята, мертвые клипы убраны. Зовут на новой и загруженной партии,
## иначе в сессии остаются старые значения, а ручка пульта стоит в нуле (ATTN_10 P5)
func reset_state() -> void:
	_fill_channels()
	shorted_nets.clear()
	net_info.clear()
	var alive: Array[C_PowerClip] = []
	for clip in active_clips:
		if is_instance_valid(clip) and is_instance_valid(clip.entity) and not clip.entity.is_queued_for_deletion():
			alive.append(clip)
	active_clips = alive
	state_reset.emit()


# --- ИНТЕРФЕЙС ДЛЯ ПУЛЬТА (UI или 3D Entity) ---

# передача питания во все в контуры, если _contour == -1
# передача питания в никуда, если _contour == 0
func set_power_pwm( _cid: int = 0, _voltage :int = 0) -> void:
	if _cid == 0:
		return # Нейтралка

	if _cid == -1: # передача питания во все в контуры
		# 1. Записываем в память сети и обновляем шейдеры по ключам контуров
		for cid in power_pwm.keys():
			power_pwm[cid]["voltage"] = _voltage
			#обновляем визуал (анимацию шейдера) для этого контура
			_update_shader_voltage(cid, _voltage) # Используем реальный ID контура!

		# 2. Обновляем данные во всех клипах на столе
		for clip in active_clips:
			if is_instance_valid(clip):
				clip.set_power(clip.net_id, _voltage)

	elif _cid != 0: # если указан номер != 0
		# 1. Записываем в память сети
		if power_pwm.has(_cid):
			power_pwm[_cid]["voltage"] = _voltage

			# 2. Записываем вольтаж в клип
			for clip in active_clips:
				if is_instance_valid(clip) and clip.net_id == _cid:
					clip.set_power(_cid, _voltage)
					# break если в будущем вешать 2 клипа на 1 контур, то брек не нужен

		# 3. ИЗ КЕША Visual МГНОВЕННО обновляем визуал (анимацию шейдера) для этого контура
		_update_shader_voltage(_cid, _voltage)

	# ⚡Сигнал для UI
	power_updated.emit(_cid, _voltage)

	# Подали напряжение в цепь, где КЗ полярности: защита отключает контур
	if _voltage != 0:
		if _cid == -1:
			_retrip_shorted()
		elif shorted_nets.has(_cid):
			trip_contour(_cid, "polarity")



func get_power(_cid: int) -> float:
	if power_pwm.has(_cid) and not power_pwm[_cid]["is_stopped"]:
		return power_pwm[_cid]["voltage"]
	return 0.0



# ---Хелпер для связи с C_TrackVisual---
func _update_shader_voltage(cid: int, voltage: float) -> void:
	# Материалы контура в кэше: "<cid>_false" / "<cid>_true", у рельсов с нестандартным UV (Track Studio, ATTN_20)
	# с суффиксом "_<scale>_<swap>". Обновляем все варианты по префиксу
	var prefix_normal := str(cid) + "_false"
	var prefix_flipped := str(cid) + "_true"
	for key in C_TrackVisual.power_materials_cache.keys():
		var k := String(key)
		var mat: ShaderMaterial = C_TrackVisual.power_materials_cache[key]
		if k.begins_with(prefix_normal):
			# Передаем напряжение в шейдер
			mat.set_shader_parameter("scroll_speed", voltage * 0.01)
		elif k.begins_with(prefix_flipped):
			# Для перевернутых траков инвертируем скорость/направление
			mat.set_shader_parameter("scroll_speed", -voltage * 0.01)



# ⚡Сигнал выключения питания
func emergency_stop(_stop : bool) -> void:
	for cid in power_pwm.keys():
		power_pwm[cid]["is_stopped"] = _stop

		# 1. Высчитываем эффективное напряжение для отображения
		var _effective_voltage = 0.0 if _stop else power_pwm[cid]['voltage']

		# 2. Передача напряжения в UI панели
		power_updated.emit(cid, _effective_voltage)

		# 3. Обновляем метки (Label3D) на физических клипах на столе
		for clip in active_clips:
			if is_instance_valid(clip) and clip.net_id == cid:
				clip.set_power(cid, _effective_voltage)

		# 4. Останавливаем (или запускаем) анимацию шейдеров тока на рельсах
		_update_shader_voltage(cid, _effective_voltage)
	
	# Сняли стоп, а КЗ полярности в цепи осталось: защита отключает контур снова
	if not _stop:
		_retrip_shorted()



# XX claude-switch. Отключает контур защитой по КЗ (как аварийный стоп, но для одного контура).
# Сброс: reset_contour(cid) или emergency_stop(false) (кнопка аварийного стопа: включить и выключить)
func trip_contour(_cid: int, reason: String = "") -> void:
	if not power_pwm.has(_cid) or power_pwm[_cid]["is_stopped"]:
		return
	power_pwm[_cid]["is_stopped"] = true
	for clip in active_clips:
		if is_instance_valid(clip) and clip.net_id == _cid:
			clip.set_power(_cid, 0.0)
	_update_shader_voltage(_cid, 0.0)
	power_updated.emit(_cid, 0.0)
	contour_tripped.emit(_cid, reason)
	print("⚡ КЗ (", reason, "): контур ", _cid, " отключен")


## Вернуть питание контура после отключения защитой
func reset_contour(_cid: int) -> void:
	if not power_pwm.has(_cid) or not power_pwm[_cid]["is_stopped"]:
		return
	power_pwm[_cid]["is_stopped"] = false
	var v: float = power_pwm[_cid]["voltage"]
	for clip in active_clips:
		if is_instance_valid(clip) and clip.net_id == _cid:
			clip.set_power(_cid, v)
	_update_shader_voltage(_cid, v)
	power_updated.emit(_cid, v)
	# КЗ полярности не устранено: защита сработает снова
	if shorted_nets.has(_cid) and v != 0.0:
		trip_contour(_cid, "polarity")


## Контуры с КЗ полярности и поданным напряжением отключаются защитой
func _retrip_shorted() -> void:
	for cid in shorted_nets.keys():
		if power_pwm.has(cid) and power_pwm[cid]["voltage"] != 0:
			trip_contour(cid, "polarity")


# Создает клип на траке по кнопке инфопанели
func create_power_clip(_entity: Entity, _cid: int, _pressed: bool) -> int:

	# Проверяем: если контур равен 0 (игрок не выбрал конкретный канал) - берем первый свободный
	if _pressed and _cid == 0:
		_cid = get_free_contour_id()
		if _cid == 0:
			return 0   # свободных номеров нет

	#💡 нажата
	if  _pressed:
		# Вешаем C_PowerClip
		var power_clip = C_PowerClip.new()

		#power_clip.net_id = target_contour # set_power сделает
		_entity.add_component(power_clip)

		# Задает электрику в клип из пгм
		power_clip.set_power(_cid, PGM.power_pwm[_cid].voltage)

		# Вешаем на трак контур
		_entity.get_comp(C_PowerTrack).net_id = _cid

	else : # отжата
		_entity.remove_component(C_PowerClip)
		# Снимаем контур с трака
		_entity.get_comp(C_PowerTrack).net_id = 0

	return _cid


# --- ИНТЕРФЕЙС ДЛЯ ТОПОЛОГИИ (Вызывается из C_PowerClip ) ---
# Регистрация клипов в сети
func register_clip(_clip):
	if not active_clips.has(_clip):
		active_clips.append(_clip)
		request_recalculate() # запрос пересчета



func unregister_clip(_clip):
	if active_clips.has(_clip):
		active_clips.erase(_clip)
		request_recalculate() # запрос пересчета



# Возвращает список ID контуров, которые СЕЙЧАС заняты
func get_occupied_contours() -> Array[int]:
	var occupied: Array[int] = []
	for clip in active_clips:
		if is_instance_valid(clip) and clip.net_id > 0:
			if not clip.net_id in occupied:
				occupied.append(clip.net_id)
	return occupied



## Возвращает первый свободный ID контура в диапазоне от 1 до MAX_CONTOURS.
## Если все контуры заняты, возвращает 0.
func get_free_contour_id() -> int:
	var occupied = get_occupied_contours()
	for id in range(1, MAX_CONTOURS + 1):
		if not id in occupied:
			return id
	return 0



# буферный метод, который ждет, пока физика Godot уложит все рельсы на места.
func request_recalculate() -> void:
	if _recalc_pending: return # если ожидание вкл - выход
	_recalc_pending = true
	# Ждем 2 кадра физики, чтобы двойные угловые снапы и Area3D успели обновить overlap
	await get_tree().physics_frame
	await get_tree().physics_frame

	recalculate_grid()
	_recalc_pending = false
	#await get_tree().physics_frame


# Пересчет всей сети: граф цепей, лидеры и конфликты клипов, КЗ полярности. Подробно: RailNetBuilder
func recalculate_grid() -> void:
	var t0 := Time.get_ticks_usec()
	var res: Dictionary = _builder.solve(get_tree(), active_clips)
	last_recalc_usec = Time.get_ticks_usec() - t0
	net_info = res.nets

	# Вид обновляем только у тех, у кого цепь, полярность или авария изменились (и у новых траков)
	for e in res.changed:
		if is_instance_valid(e):
			e.send_event("on_power_view_changed", {"active": is_power_layer_active})

	# Метки клипов (конфликт, знак «−»)
	for clip in active_clips:
		if is_instance_valid(clip):
			clip._change_clip_label()

	# КЗ полярности: цепи с напряжением отключаются защитой
	shorted_nets.clear()
	for cid in res.shorts:
		shorted_nets[cid] = true
	_retrip_shorted()

	if log_recalc and Global.debug_mode:
		print("PGM: пересчет сети %d мкс, траков в цепях %d, клипов %d" % [last_recalc_usec, _tracks_in_nets(), active_clips.size()])

	power_tab_updated.emit()


func _tracks_in_nets() -> int:
	var n := 0
	for k in net_info:
		n += int(net_info[k].tracks)
	return n



# Срабатывает при переключении слоя электрики в топ панели
func toggle_power_layer(state: bool):
	is_power_layer_active = state
	power_layer_toggled.emit(state)
	# Получаем список всех сущностей с C_PowerTrack
	var all_tracks = get_tree().get_nodes_in_group("power_track")
	for track_entity in all_tracks:
		track_entity.send_event("on_power_view_changed", {"active": state})
