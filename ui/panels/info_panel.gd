class_name InfoPanel extends PanelContainer


@onready var tab_container = %TabContainer

var current_target: Entity

## ⚡Сигнал для спидометра
signal s_select_entity( sel_entity:Variant, spdmetr_on: bool, vert :bool)


func _ready():
	hide() # Прячем панель на старте
	PGM.power_tab_updated.connect(_update_power_tab)
	PGM.power_updated.connect(_on_power_track_updated)
	#PGM.neighbor_updated.connect(_on_neighbor_updated)



# Для TransformTab (если нужны живые координаты)
# Только ЭТУ вкладку имеет смысл обновлять в _process, и только если она открыта!
func _process(_delta):
	if visible and current_target and tab_container.current_tab == 2:# 2 - Положение  
		# Допустим, TransformTab = 2
		var _pos = current_target.global_position
		var _rot = current_target.rotation_degrees
		%PosLabel.text =  "(%.2f, %.2f, %.2f)" % [_pos.x, _pos.y, _pos.z]
		%RotLabel.text =  "(%.2f, %.2f, %.2f)" % [_rot.x, _rot.y, _rot.z]
		if current_target.get_comp(C_Chassis) and  current_target.get_comp(C_Kinematics):
			var _ontrack = current_target.get_comp(C_Chassis).is_on_rails
			var _freeze = current_target.get_comp(C_Kinematics).rb.freeze
			var _friction = current_target.get_comp(C_Kinematics).rb.physics_material_override.friction
			var _linear_damp = current_target.get_comp(C_Kinematics).rb.linear_damp
			var _angular_damp = current_target.get_comp(C_Kinematics).rb.angular_damp
			var _mass = current_target.get_comp(C_Kinematics).rb.mass
			%OnTrackLabel.text ='On' if _ontrack else 'Off'
			%FreezeLabel.text = 'On' if _freeze else 'Off'
			%FrictionLabel.text = "%.2f" % [_friction]
			%LinearDampLabel.text = "%.2f" % [_linear_damp]
			%AngularDampLabel.text = "%.2f" % [_angular_damp]
			%MassWLabel.text = "%.2f" % [_mass]
			
			var identity = current_target.get_comp(C_Identity)
			if identity:
				#%MassWLabel.text = "%.2f" % [identity.get_config('mass', 0.0)]
				%RollResistanceLabel.text = "%.2f" % [identity.get_config('roll_resistance', 0.0)]
				%MaxGripLabel.text = "%.2f" % [identity.get_config('max_grip', 0.0)]
			
			var speed = 0.0
			if _ontrack:
				speed = current_target.get_comp(C_Chassis).current_speed
			else:
				speed = current_target.get_comp(C_Kinematics).rb.linear_velocity.z
			%SpeedmpsLabel.text = "%0.2f" % [speed] if abs(speed) > 0.05 else '0.0'
	if visible and current_target and tab_container.current_tab == 4: 
		_update_debug_tab()
	
	if visible and current_target and tab_container.current_tab == 1: # 1 - Питание
		_update_power_tab()
	



# Вызывается из SelectTool, когда мы кликаем по объекту
func set_target(entity: Entity):

	# 1. Отписываемся от старого объекта
	if current_target:
		current_target.component_added.disconnect(_on_components_changed)
		current_target.component_removed.disconnect(_on_components_changed)
		
	current_target = entity

	# 2. Если кликнули в пустоту - прячем панель
	if not current_target:
		s_select_entity.emit(null, false,false)
		hide()
		return
		
	# 3. Подписываемся на новый объект (для обновления Debug-вкладки)
	current_target.component_added.connect(_on_components_changed)
	current_target.component_removed.connect(_on_components_changed)
	
	#INFO ПАНЕЛЬ спидометра! спидометр он офф
	var _spd = $VBoxContainer/TabContainer/TransformTab/VBoxContainer/HBoxContainer4/SpeedometerCheckBox.button_pressed
	var _vert =$VBoxContainer/TabContainer/TransformTab/VBoxContainer/HBoxContainer4/SpeedometerVCheck.button_pressed
	s_select_entity.emit(current_target, _spd, _vert)
	
	show() # Visible = on
	
	#4. Обновляем необходимые в моменте вкладки
	_populate_data()



# Выполняется после получения таргета, обновляет необходимые в моменте показа вкладки
func _populate_data():
	# Вкладка Main
	_populate_main_tab()
	# Вкладка Power
	_update_power_tab()
	# Вкладка Debug
	_update_debug_tab()



func _populate_main_tab():
	var identity = current_target.get_comp(C_Identity)
	if identity:
		%CategoryLabel.text = identity.get_category()
		%TagLabel.text =  identity.get_tag()
		%HeaderLLabel.text = '  ' + identity.get_name_e() 
		%HeaderRLabel.text ='node : ' + current_target.name 
		%DescriptionLabel.text = identity.get_description()
		%IconRect.texture = identity.get_icon()
		
		match  identity.get_category():
			&'track':
				var _path = current_target.get_comp(C_Path)
				%TrackContainer.show()
				%TrainContainer.hide()
				if _path:
					%RadiusLabel.text = str(_path.radius) + ' u/sm'
					%DegLabel.text = str(_path.deg) + '°'
					%LengthLabel.text = str(_path.get_length()) + ' u/sm'
			&'train':
				%TrackContainer.hide()
				%TrainContainer.show()
				identity.get_config('mass', 0.0)
				%MassLabel.text = str(identity.get_config('mass', 0.0))
				%PowerLabel.text = str(identity.get_config('power', 0.0))
				%MaxSpeedLabel.text = str(identity.get_config('maxspeed', 700.0))
	else:
		# Если это какой-то системный объект без паспорта
		%HeaderLabel.text = "Системный объект"



#--- TRANSFORM  TAB ---
# Все в process

# кнопка спидометра
func _on_speedometer_check_box_toggled(toggled_on: bool) -> void:
	var _vert = $VBoxContainer/TabContainer/TransformTab/VBoxContainer/HBoxContainer4/SpeedometerVCheck.button_pressed
	s_select_entity.emit(current_target, toggled_on, _vert)
	
	
	
# Переключатель v\h спидометра
func _on_speedometer_vert_toggled(toggled_on: bool) -> void:
	var _spdmeter_on = $VBoxContainer/TabContainer/TransformTab/VBoxContainer/HBoxContainer4/SpeedometerCheckBox.button_pressed
	s_select_entity.emit(current_target, _spdmeter_on, toggled_on)



#---POWER TAB ---
func _update_power_tab():
	#await get_tree().physics_frame
	if not current_target: return
	var identity = current_target.get_comp(C_Identity)
	var _category = identity.get_category()
	
	# Power Track
	match _category:
		&'track':
			%PowerTrackTab.show()
			%PowerTrainTab.hide()
		
			var _power_comp = current_target.get_comp(C_PowerTrack) as C_PowerTrack
			var _power_clip = current_target.get_comp(C_PowerClip)
			var _socket_comp = current_target.get_comp(C_Socket)
			var _path = current_target.get_comp(C_Path)
			if _path:
				%RadiusLabel.text = str(_path.radius) + ' u/sm'
				%DegLabel.text = str(_path.deg) + '°'
				%LengthLabel.text = str(_path.get_length()) + ' u/sm'
			if _power_comp: # Если Power трак
				%PowerClipButton.disabled = false
				%PowerClipButton.button_pressed = false
				%ClipContourIDButton.disabled = true  # запрещаем менять контур
				# Трак
				%TrackContourLabel.text = str(_power_comp.contour_id)
				%TrackVoltageLabel.text = str(PGM.get_power(_power_comp.contour_id))
				%FlippedLabel.text = str(_power_comp.is_flipped)

		
			else: # Если трака нет, то в дефолт все
				%PowerClipButton.disabled = true
				%PowerClipButton.button_pressed = false
				%ClipContourIDButton.disabled = true  # запрещаем менять контур
				%TrackContourLabel.text = str(0)
				%TrackVoltageLabel.text = str(0)
				%FlippedLabel.text = str(0) 
				return
			
			# Power Clip
			if _power_clip: # Если клип есть, то он определяет
				%PowerClipButton.disabled = false
				%PowerClipButton.button_pressed = true
				%ClipContourIDButton.disabled = false # разрешаем менять контур
				_power_comp = _power_clip # Переключаемся на клип
				
			if _power_comp.contour_id != 0 and !_power_clip:
					%PowerClipButton.button_pressed = false
					%PowerClipButton.disabled = true
					%ClipContourIDButton.disabled = true # не менять контур
					
			# 💡-option_button- Делаем селектор контура-
			_fill_clip_contour_button(_power_comp.contour_id)

			# Цвета 
			if  PGM.get_power(_power_comp.contour_id) > 0:
				%TrackVoltageLabel.modulate = Color(0.0, 0.824, 0.0, 1.0)
			elif PGM.get_power(_power_comp.contour_id) < 0:
				%TrackVoltageLabel.modulate = Color(1.0, 0.302, 0.043, 1.0)
			else:
				%TrackVoltageLabel.modulate = Color(1.0, 1.0, 1.0, 1.0)
				
		&'train':
			%PowerTrackTab.hide()
			%PowerTrainTab.show()
			
			var _engine_comp = current_target.get_comp(C_Engine) as C_Engine
			var _chassis_comp = current_target.get_comp(C_Chassis) as C_Chassis
			if _engine_comp:
				%EngineContourLabel.text = str(_engine_comp.power.contour_id)
				%TrainVoltageLabel.text = str(_engine_comp.power.voltage)
				%MaxTractiveForceLabel.text = str(_engine_comp.max_tractive_force)
				%MaxTheoreticalSpeedLabel.text = str(_engine_comp.max_theoretical_speed)
				
				
				var _spd = _chassis_comp.current_speed
				%SpeedLabel.text = str( "%0.2f" % [_spd] if abs(_spd) > 0.05 else '0.0' )
				var _c_force = _chassis_comp.centrifugal_force
				%CentrifugalForceLabel.text = tr( "%0.2f" % [_c_force] if abs(_c_force) > 0.05 else '0.0' )
				
				# Цвета 
				if  PGM.get_power(_engine_comp.power.contour_id) > 0:
					%TrainVoltageLabel.modulate = Color(0.0, 0.824, 0.0, 1.0)
					%SpeedLabel.modulate = Color(0.0, 0.824, 0.0, 1.0)
				elif PGM.get_power(_engine_comp.power.contour_id) < 0:
					%TrainVoltageLabel.modulate = Color(1.0, 0.302, 0.043, 1.0)
					%SpeedLabel.modulate = Color(1.0, 0.302, 0.043, 1.0)
				else:
					%TrackVoltageLabel.modulate = Color(1.0, 1.0, 1.0, 1.0)
					%SpeedLabel.modulate = Color(1.0, 1.0, 1.0, 1.0)
				



# ⚡Сигнал из менеджера при дергании ручки.  Обновляет инфой о ТРАКЕ!.
func _on_power_track_updated(_contour : int, _voltage : float) ->void:
	if not current_target: return
	
	var _power_comp = current_target.has_comp(C_PowerTrack)
	if _power_comp: # Если трак
		_power_comp = current_target.get_comp(C_PowerTrack)
		%TrackContourLabel.text = str(_power_comp.contour_id)
		%TrackVoltageLabel.text = str(PGM.get_power(_power_comp.contour_id))
		%FlippedLabel.text = str(_power_comp.is_flipped)
	
		if  _voltage > 0:
			%TrackVoltageLabel.modulate = Color(0.0, 0.824, 0.0, 1.0)
		elif _voltage < 0:
			%TrackVoltageLabel.modulate = Color(1.0, 0.302, 0.043, 1.0)
		else:
			%TrackVoltageLabel.modulate = Color(1.0, 1.0, 1.0, 1.0)





func _update_debug_tab():
	if not current_target: return
	
	# Вместо создания сотен Label.new(), мы просто собираем ОДНУ строку
	var text_dump = "[color=green]Components:[/color]\n"
	for child in current_target.get_children():
		if child is Component:
			if child.is_state:
				text_dump += "[color=yellow]-" + child.get_script().get_global_name() + " - state[/color]\n"
			else:
				text_dump += "- " + child.get_script().get_global_name() + "\n"
			
	# Присваиваем текст один раз. Никаких утечек памяти!
	%DebugTab.text = text_dump



# Вызывается ТОЛЬКО когда компонент добавился/удалился
func _on_components_changed(_type: Script):
	_update_debug_tab()
	# Здесь же можно перепроверять видимость вкладок (вдруг добавили C_Power)



## ---⚡Сигналы от кнопок---

## Кнопка меняет Номер контура  0 - нет подключения
## должен щелкать только по свободным контурам, 0 и своему, если он есть

func _on_contour_id_item_selected(index: int):
	if not current_target: return
	
	var power_clip = current_target.has_comp(C_PowerClip)
	if power_clip:
		power_clip = current_target.get_comp(C_PowerClip)

	if not power_clip: return
	
	# Извлекаем зашитый ID контура из выбранного пункта меню
	var new_contour_id = %ClipContourIDButton.get_item_id(index)
	
	# Если значение изменилось — обновляем данные компонента
	if power_clip.contour_id != new_contour_id:
		power_clip.set_contour(new_contour_id)
		# Вешаем на трак новый контур
		current_target.get_comp(C_PowerTrack).contour_id = new_contour_id
		
		#await get_tree().physics_frame
		
		PGM.request_recalculate()
		# На всякий случай перерисовываем панель, чтобы закрепить состояние
		_update_power_tab()



## Кнопка вешает PowerClip на трак

func _on_power_clip_button_pressed() -> void:
	
	if not current_target or not current_target.has_comp(C_PowerTrack):
		return # это powertrack?
	
	# Выбор контура 
	var _contour: int = %ClipContourIDButton.selected
	var _btn_pressed = %PowerClipButton.button_pressed
	
	# Менеджер проверит и создаст 
	_contour = PGM.create_power_clip(current_target, _contour, _btn_pressed)
	
	# Обновляем UI, чтобы игрок сразу визуально увидел, какой контур ему выдали
	%ClipContourIDButton.selected = _contour
	_update_power_tab()



# --Helpers --

# 💡-option_button- Делаем селектор контура-
func _fill_clip_contour_button(_current_contour_id) -> void:
	var option_button = %ClipContourIDButton as OptionButton
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
