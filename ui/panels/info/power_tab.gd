class_name InfoPowerTab extends InfoTab

###########################
## Вкладка «Питание»: контур и напряжение трака, клипса питания, значения поезда
###########################
## Узлы в info_panel.tscn (PowerTab). Трак обновляется по сигналам PGM (update_tab, on_power_track_updated),
## поезд живыми значениями в refresh().


func _setup() -> void:
	_n("PowerClipButton").pressed.connect(_on_power_clip_button_pressed)
	_n("ClipContourIDButton").item_selected.connect(_on_contour_id_item_selected)


func _on_bind() -> void:
	update_tab()


func update_tab() -> void:
	#await get_tree().physics_frame
	if not target: return
	var identity = target.get_comp(C_Identity)
	if not identity: return
	var _category = identity.get_category()
	
	# Power Track
	match _category:
		&'track':
			_n("PowerTrackTab").show()
			_n("PowerTrainTab").hide()
		
			var _power_comp = target.get_comp(C_PowerTrack) as C_PowerTrack
			var _power_clip = target.get_comp(C_PowerClip)
			var _socket_comp = target.get_comp(C_Socket)
			var _path = target.get_comp(C_Path)
			if _path:
				_n("RadiusLabel").text = str(_path.radius) + ' u/sm'
				_n("DegLabel").text = str(_path.deg) + '°'
				_n("LengthLabel").text = str(_path.get_length()) + ' u/sm'
			if _power_comp: # Если Power трак
				_n("PowerClipButton").disabled = false
				_n("PowerClipButton").button_pressed = false
				_n("ClipContourIDButton").disabled = true  # запрещаем менять контур
				# Трак
				# XX claude-switch: у кросса с раздельными цепями "1 | 2" (по лучу на путь)
				_n("TrackContourLabel").text = _power_comp.contour_text()
				_n("TrackVoltageLabel").text = _power_comp.voltage_text()
				_n("FlippedLabel").text = _power_comp.flip_text()

		
			else: # Если трака нет, то в дефолт все
				_n("PowerClipButton").disabled = true
				_n("PowerClipButton").button_pressed = false
				_n("ClipContourIDButton").disabled = true  # запрещаем менять контур
				_n("TrackContourLabel").text = str(0)
				_n("TrackVoltageLabel").text = str(0)
				_n("FlippedLabel").text = str(0) 
				return
			
			# Power Clip
			if _power_clip: # Если клип есть, то он определяет
				_n("PowerClipButton").disabled = false
				_n("PowerClipButton").button_pressed = true
				_n("ClipContourIDButton").disabled = false # разрешаем менять контур
				_power_comp = _power_clip # Переключаемся на клип
				
			if _power_comp.contour_id != 0 and !_power_clip:
					_n("PowerClipButton").button_pressed = false
					_n("PowerClipButton").disabled = true
					_n("ClipContourIDButton").disabled = true # не менять контур
					
			# 💡-option_button- Делаем селектор контура-
			_fill_clip_contour_button(_power_comp.contour_id)

			# Цвета 
			if  PGM.get_power(_power_comp.contour_id) > 0:
				_n("TrackVoltageLabel").modulate = Color(0.0, 0.824, 0.0, 1.0)
			elif PGM.get_power(_power_comp.contour_id) < 0:
				_n("TrackVoltageLabel").modulate = Color(1.0, 0.302, 0.043, 1.0)
			else:
				_n("TrackVoltageLabel").modulate = Color(1.0, 1.0, 1.0, 1.0)
				
		&'train':
			_n("PowerTrackTab").hide()
			_n("PowerTrainTab").show()
			refresh()


func refresh() -> void:
	if not target: return
	var identity = target.get_comp(C_Identity)
	if not identity or identity.get_category() != &'train': return

	var _engine_comp = target.get_comp(C_Engine) as C_Engine
	var _chassis_comp = target.get_comp(C_Chassis) as C_Chassis
	if not _engine_comp or not _chassis_comp: return

	_n("EngineContourLabel").text = str(_engine_comp.power.contour_id)
	_n("TrainVoltageLabel").text = str(_engine_comp.power.voltage)

	var _spd = _chassis_comp.current_speed
	_n("SpeedLabel").text = str( "%0.2f" % [_spd] if abs(_spd) > 0.05 else '0.0' )
	var _c_force = _chassis_comp.centrifugal_force
	_n("CentrifugalForceLabel").text = tr( "%0.2f" % [_c_force] if abs(_c_force) > 0.05 else '0.0' )

	# Цвета
	var _pw: float = PGM.get_power(_engine_comp.power.contour_id)
	if _pw > 0:
		_n("TrainVoltageLabel").modulate = Color(0.0, 0.824, 0.0, 1.0)
		_n("SpeedLabel").modulate = Color(0.0, 0.824, 0.0, 1.0)
	elif _pw < 0:
		_n("TrainVoltageLabel").modulate = Color(1.0, 0.302, 0.043, 1.0)
		_n("SpeedLabel").modulate = Color(1.0, 0.302, 0.043, 1.0)
	else:
		_n("TrainVoltageLabel").modulate = Color(1.0, 1.0, 1.0, 1.0)
		_n("SpeedLabel").modulate = Color(1.0, 1.0, 1.0, 1.0)


func on_power_track_updated(_contour : int, _voltage : float) ->void:
	if not target: return
	
	var _power_comp = target.has_comp(C_PowerTrack)
	if _power_comp: # Если трак
		_power_comp = target.get_comp(C_PowerTrack)
		_n("TrackContourLabel").text = str(_power_comp.contour_id)
		_n("TrackVoltageLabel").text = str(PGM.get_power(_power_comp.contour_id))
		_n("FlippedLabel").text = str(_power_comp.is_flipped)
	
		if  _voltage > 0:
			_n("TrackVoltageLabel").modulate = Color(0.0, 0.824, 0.0, 1.0)
		elif _voltage < 0:
			_n("TrackVoltageLabel").modulate = Color(1.0, 0.302, 0.043, 1.0)
		else:
			_n("TrackVoltageLabel").modulate = Color(1.0, 1.0, 1.0, 1.0)


func _on_contour_id_item_selected(index: int):
	if not target: return
	
	var power_clip = target.has_comp(C_PowerClip)
	if power_clip:
		power_clip = target.get_comp(C_PowerClip)

	if not power_clip: return
	
	# Извлекаем зашитый ID контура из выбранного пункта меню
	var new_contour_id = _n("ClipContourIDButton").get_item_id(index)
	
	# Если значение изменилось — обновляем данные компонента
	if power_clip.contour_id != new_contour_id:
		power_clip.set_contour(new_contour_id)
		# Вешаем на трак новый контур
		target.get_comp(C_PowerTrack).contour_id = new_contour_id
		
		#await get_tree().physics_frame
		
		PGM.request_recalculate()
		# На всякий случай перерисовываем панель, чтобы закрепить состояние
		update_tab()


func _on_power_clip_button_pressed() -> void:
	
	if not target or not target.has_comp(C_PowerTrack):
		return # это powertrack?
	
	# Выбор контура 
	var _contour: int = _n("ClipContourIDButton").selected
	var _btn_pressed = _n("PowerClipButton").button_pressed
	
	# Менеджер проверит и создаст 
	_contour = PGM.create_power_clip(target, _contour, _btn_pressed)
	
	# Обновляем UI, чтобы игрок сразу визуально увидел, какой контур ему выдали
	_n("ClipContourIDButton").selected = _contour
	update_tab()


func _fill_clip_contour_button(_current_contour_id) -> void:
	var option_button = _n("ClipContourIDButton") as OptionButton
	option_button.clear() # Полностью очищаем старые пункты
	
	# 1.1️⃣ Добавляем базовый вариант (0 - отключено от питания)
	option_button.add_item("0: Отключено", 0)
	
	# Получаем массив контуров, которые УЖЕ заняты другими клеммами на макете
	var occupied_contours = PGM.get_occupied_contours()
	var current_id = _current_contour_id # Текущий контур этого объекта

	# 2. 2️⃣ Динамически наполняем список доступными контурами
	for i in range(1, PGM.MAX_CONTOURS + 1):
		# Контур доступен, если он СВОБОДЕН, ИЛИ если это "родной" контур текущего объекта
		if i == current_id or not i in occupied_contours:
			option_button.add_item("Контур " + str(i), i) # Текст и внутренний ID элемента
	
	# 3. 3️⃣ Выставляем визуальный фокус на текущий контур объекта
	# Так как мы передавали реальный ID контура вторым аргументом в add_item,
	# мы можем легко найти индекс нужной строки
	for idx in range(option_button.item_count):
		if option_button.get_item_id(idx) == current_id:
			option_button.select(idx)
			break
