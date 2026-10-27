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
	
	# Таб механизмы создается кодом
	_build_mech_tab()
	# Таб материала листа пенопласта (T7), тоже кодом
	_build_terrain_tab()
	# XX claude-terra 13.1.7: строки уровня, подъема и уклона в блоке трака, тоже кодом
	_build_track_rows()


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
			%OnTrackLabel.text ='On' if _ontrack else 'Off'
			%FreezeLabel.text = 'On' if _freeze else 'Off'
			%FrictionSpinB.value = _friction
			%LinearDampSpinB.value =  current_target.get_comp(C_Kinematics).rb.linear_damp
			%AngularDampSpinB.value =  current_target.get_comp(C_Kinematics).rb.angular_damp
			
			var identity = current_target.get_comp(C_Identity)
			if identity:
				%MassWSpinB.value = current_target.get_comp(C_Kinematics).mass
				%RollResSpinB.value = current_target.get_comp(C_Kinematics).roll_resistance
				%MaxGripSpinB.value = current_target.get_comp(C_Kinematics).max_grip

			var speed = 0.0
			if _ontrack:
				speed = current_target.get_comp(C_Chassis).current_speed
			else:
				speed = current_target.get_comp(C_Kinematics).rb.linear_velocity.length()
			%SpeedmpsLabel.text = "%0.2f" % [speed] if abs(speed) > 0.05 else '0.0'
			
			var _kinemat_comp = current_target.get_comp(C_Kinematics) as C_Kinematics
			var _spd_k = current_target.get_comp(C_Kinematics).rb.linear_velocity.length()
			var _spd_kmh = _spd_k * 0
			var _spd_s = current_target.get_comp(C_Chassis).current_speed
			
			%SpeedKLabel.text = "%0.2f" % [_spd_k] if abs(_spd_k) > 0.05 else '0.0'
			%SpeedKmhLabel.text = "%0.2f" % [_spd_kmh] if abs(_spd_kmh) > 0.05 else 'no calc'
			%SpeedSLabel.text = "%0.2f" % [_spd_s] if abs(_spd_s) > 0.05 else '0.0'
			
			
	# XX claude-terra 13.1.7: уровень и уклон живые (призрак трака и трак в драге двигаются), не чаще 4 раз в секунду
	if visible and current_target and _track_rows_ready:
		_track_acc += _delta
		if _track_acc >= TRACK_ROWS_PERIOD:
			_track_acc = 0.0
			_update_track_rows()

	if visible and current_target and tab_container.current_tab == 4:  # 4 - дебаг 
		_update_debug_tab()
	
	if visible and current_target and tab_container.current_tab == 1: # 1 - Питание
		_update_power_tab()

	# Вкладка механизмов и света: статус и положения слайдеров
	if visible and current_target and _mech_tab and tab_container.current_tab == tab_container.get_tab_idx_from_control(_mech_tab):
		_update_mech_tab()
	



# Вызывается из SelectTool, когда мы кликаем по объекту
func set_target(entity: Entity):
	if %WagonCameraButton.button_pressed == true:
		%WagonCameraButton.press()
		return
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
	# Вкладка механизмы 
	_rebuild_mech_tab()
	# Вкладка материал листа
	_update_terrain_tab()


func _populate_main_tab():
	var identity = current_target.get_comp(C_Identity)
	if identity:
		%CategoryLabel.text = identity.get_category()
		%TagLabel.text =  identity.get_tag()
		%HeaderLabel.text = '  ' + identity.get_name_e() 
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
				_update_track_rows()   # XX claude-terra 13.1.7
			&'terrain':
				%TrackContainer.hide()
				%TrainContainer.hide()
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
				# XX claude-switch: у кросса с раздельными цепями "1 | 2" (по лучу на путь)
				%TrackContourLabel.text = _power_comp.contour_text()
				%TrackVoltageLabel.text = _power_comp.voltage_text()
				%FlippedLabel.text = _power_comp.flip_text()

		
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


##=== DEBUG =====


func _update_debug_tab():
	if not current_target: return
	
	# Cобираем ОДНУ строку
	var text_dump = "[color=green]Components:[/color]\n"
	for child in current_target.get_children():
		if child is Component:
			if child.is_state:
				text_dump += "[color=yellow]-" + child.get_script().get_global_name() + " - state[/color]\n"
			else:
				text_dump += "- " + child.get_script().get_global_name() + "\n"
			
	# Присваиваем текст один раз. Никаких утечек памяти!
	%DebugText.text = text_dump


# вызывается при обновлении панельки коэф. вагона
func _on_wagon_k_container_draw() -> void:
	var _chassis = current_target.get_comp(C_Chassis)
	var _kinemat = current_target.get_comp(C_Kinematics)

	if not _kinemat: return
	%RollResSpinB.value = _kinemat.roll_resistance
	%MassWSpinB.value = _kinemat.mass
	%MaxGripSpinB.value = _kinemat.max_grip
	

	
# вызывается при обновлении дебаг таба
func _on_debug_tab_draw() -> void:
	if not current_target: return
	
	var _chassis = current_target.get_comp(C_Chassis)
	var _kinemat = current_target.get_comp(C_Kinematics)
	var _engine = current_target.get_comp(C_Engine)
	
	if not _chassis or not _kinemat or not _engine: return
	
	%EnableSusp.button_pressed = _chassis.enable_suspension
	%EnableVert.button_pressed = _chassis.debug_susp_vertical
	%EnablePitch.button_pressed = _chassis.debug_susp_pitch
	%EnableRoll.button_pressed = _chassis.debug_susp_roll
	%EnableLateral.button_pressed = _chassis.debug_susp_lateral
	%SuspMult.value = _chassis.effect_multiplier
	
	%LongGrip.value = _kinemat.longitudinal_grip
	%MinCurveRadius.value = _kinemat.min_curve_radius
	%MaxYawDeg.value = _kinemat.max_yaw_deg
	%YawSpring.value = _kinemat.yaw_spring
	
	if _engine: 
		%MaxTractiveForceB.value = _engine.max_tractive_force
		%MaxTheoreticalSpeedB.value = _engine.max_theoretical_speed
	else:
		%MaxTractiveForceB.value = 0
		%MaxTheoreticalSpeedB.value = 0


## Функция передачи коэф подвески в вагон
func set_suspension_k(_data: Dictionary):
	var _chassis = current_target.get_comp(C_Chassis)
	var _kinemat = current_target.get_comp(C_Kinematics)
	var _key = _data['key']
	var _val = _data['value']
	match _key:
		'enable_suspension': _chassis.enable_suspension = _val
		'debug_susp_vertical': _chassis.debug_susp_vertical = _val
		'debug_susp_pitch': _chassis.debug_susp_pitch = _val
		'debug_susp_roll': _chassis.debug_susp_roll = _val
		'debug_susp_lateral': _chassis.debug_susp_lateral = _val
		'effect_multiplier': _chassis.effect_multiplier = _val

		'longitudinal_grip': _kinemat.longitudinal_grip = _val
		'min_curve_radius': _kinemat.min_curve_radius = _val
		'max_yaw_deg': _kinemat.max_yaw_deg = _val
		'yaw_spring': _kinemat.yaw_spring = _val
		
		'roll_resistance': _kinemat.roll_resistance = _val
		'mass': _kinemat.mass = _val
		'max_grip': _kinemat.max_grip = _val
		
		'friction': _kinemat.rb.physics_material_override.friction = _val
		'linear_damp': _kinemat.rb.linear_damp = _val
		'angular_damp': _kinemat.rb.angular_damp = _val


func _on_enable_susp_pressed() -> void:
	set_suspension_k({'key':'enable_suspension', 'value': %EnableSusp.button_pressed })
		

func _on_enable_vert_pressed() -> void:
	set_suspension_k({'key':'debug_susp_vertical', 'value': %EnableVert.button_pressed })


func _on_enable_pitch_pressed() -> void:
	set_suspension_k({'key':'debug_susp_pitch', 'value': %EnablePitch.button_pressed })


func _on_enable_roll_pressed() -> void:
	set_suspension_k({'key':'debug_susp_roll', 'value': %EnableRoll.button_pressed })


func _on_enable_lateral_pressed() -> void:
	set_suspension_k({'key':'debug_susp_lateral', 'value': %EnableLateral.button_pressed })


func _on_susp_mult_value_changed(value: float) -> void:
	set_suspension_k({'key':'effect_multiplier', 'value':value })


func _on_long_grip_value_changed(value: float) -> void:
	set_suspension_k({'key':'longitudinal_grip', 'value': value })


func _on_min_curve_radius_value_changed(value: float) -> void:
	set_suspension_k({'key':'min_curve_radius', 'value': value })


func _on_max_yaw_deg_value_changed(value: float) -> void:
	set_suspension_k({'key':'max_yaw_deg', 'value': value })


func _on_yaw_spring_value_changed(value: float) -> void:
	set_suspension_k({'key':'yaw_spring', 'value': value })


func _on_roll_res_spin_b_value_changed(value: float) -> void:
	set_suspension_k({'key':'roll_resistance', 'value': value })

func _on_mass_w_spin_b_value_changed(value: float) -> void:
	set_suspension_k({'key':'mass', 'value': value })


func _on_max_grip_spin_b_value_changed(value: float) -> void:
	set_suspension_k({'key':'max_grip', 'value': value })
	

func _on_friction_spin_b_value_changed(value: float) -> void:
	set_suspension_k({'key':'friction', 'value': value })


func _on_linear_damp_spin_b_value_changed(value: float) -> void:
	set_suspension_k({'key':'linear_damp', 'value': value })

func _on_angular_damp_spin_b_value_changed(value: float) -> void:
	set_suspension_k({'key':'angular_damp', 'value': value })

## ==========



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



## === MECHANISMS 

##===========================================================================
## ВКЛАДКА "МЕХАНИЗМЫ" 
## Строится кодом, живёт в TabContainer последней вкладкой, видна только у сущностей с C_Mechanisms.
## Определяется по контролу (_mech_tab), а не по номеру, поэтому индексы других вкладок не важны.
## ======================================================================

var _mech_tab: VBoxContainer
var _mech_list: VBoxContainer
var _mech_rows: Dictionary = {}      # StringName -> {slider, check, enabled, status}
var _mech_drag: StringName = &""     # id механизма, чей слайдер тянут сейчас
var _light_rows: Dictionary = {}     # StringName -> {slider, check, enabled, status}
var _light_drag: StringName = &""    # id источника света, чей слайдер тянут сейчас


func _build_mech_tab() -> void:
	_mech_tab = VBoxContainer.new()
	_mech_tab.name = "Механизмы"
	tab_container.add_child(_mech_tab)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_mech_tab.add_child(margin)
	_mech_list = VBoxContainer.new()
	margin.add_child(_mech_list)
	_set_mech_tab_visible(false)


func _set_mech_tab_visible(on: bool) -> void:
	var idx = tab_container.get_tab_idx_from_control(_mech_tab)
	tab_container.set_tab_hidden(idx, not on)
	if not on and tab_container.current_tab == idx:
		tab_container.current_tab = 0


func _get_mech_comp() -> C_Mechanisms:
	if current_target == null or current_target.has_comp(C_Ghost):
		return null
	return current_target.get_comp(C_Mechanisms) as C_Mechanisms


## Пересобирает строки. Вызывать при смене цели и при добавлении/удалении C_Mechanisms / C_Ghost
func _rebuild_mech_tab() -> void:
	for c in _mech_list.get_children():
		_mech_list.remove_child(c)
		c.queue_free()
	_mech_rows.clear()
	_light_rows.clear()
	_mech_drag = &""
	_light_drag = &""

	var comp := _get_mech_comp()
	if comp == null:
		_set_mech_tab_visible(false)
		return
	var mechs := comp.get_list()
	var lamps := comp.get_light_list()
	if mechs.is_empty() and lamps.is_empty():
		_set_mech_tab_visible(false)
		return
	_set_mech_tab_visible(true)

	for item in mechs:
		_add_mech_row(item)

	if not mechs.is_empty():
		var all_row := HBoxContainer.new()
		var b_open := Button.new()
		b_open.text = "Открыть всё"
		b_open.pressed.connect(_on_mech_all.bind(1.0))
		var b_close := Button.new()
		b_close.text = "Закрыть всё"
		b_close.pressed.connect(_on_mech_all.bind(0.0))
		all_row.add_child(b_open)
		all_row.add_child(b_close)
		_mech_list.add_child(all_row)

	if not lamps.is_empty():
		if not mechs.is_empty():
			_mech_list.add_child(HSeparator.new())
		var head := Label.new()
		head.text = "Свет"
		_mech_list.add_child(head)
		for item in lamps:
			_add_light_row(item)
		var l_row := HBoxContainer.new()
		var b_on := Button.new()
		b_on.text = "Включить весь"
		b_on.pressed.connect(_on_light_all.bind(1.0))
		var b_off := Button.new()
		b_off.text = "Выключить весь"
		b_off.pressed.connect(_on_light_all.bind(0.0))
		l_row.add_child(b_on)
		l_row.add_child(b_off)
		_mech_list.add_child(l_row)
	_update_mech_tab()


func _add_mech_row(item: Dictionary) -> void:
	var id: StringName = item.id
	var row := HBoxContainer.new()

	var title := Label.new()
	title.text = item.title
	title.custom_minimum_size.x = 110
	row.add_child(title)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size.x = 140
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.drag_started.connect(func(): _mech_drag = id)
	slider.drag_ended.connect(func(_changed): _mech_drag = &"")
	slider.value_changed.connect(func(v): if _mech_drag == id: _send_mech(id, v))
	row.add_child(slider)

	var check := CheckButton.new()
	check.text = "Открыто"
	check.toggled.connect(func(on): _send_mech(id, 1.0 if on else 0.0))
	row.add_child(check)

	var en := CheckBox.new()
	en.text = "вкл"
	en.tooltip_text = "Выключенный механизм не реагирует на команды"
	en.toggled.connect(func(on):
		var comp := _get_mech_comp()
		if comp: comp.set_enabled(id, on))
	row.add_child(en)

	var status := Label.new()
	status.custom_minimum_size.x = 70
	row.add_child(status)

	_mech_list.add_child(row)
	_mech_rows[id] = {"slider": slider, "check": check, "enabled": en, "status": status}


func _add_light_row(item: Dictionary) -> void:
	var id: StringName = item.id
	var row := HBoxContainer.new()

	var title := Label.new()
	title.text = item.title
	title.custom_minimum_size.x = 110
	row.add_child(title)

	# Слайдер = яркость: множитель к energy из конфига (0..GAIN_MAX). Включение и выключение - кнопка "Горит"
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = LightConfig.GAIN_MAX
	slider.step = 0.05
	slider.tooltip_text = "Яркость (множитель к энергии из конфига)"
	slider.custom_minimum_size.x = 140
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.drag_started.connect(func(): _light_drag = id)
	slider.drag_ended.connect(func(_changed): _light_drag = &"")
	slider.value_changed.connect(func(v): if _light_drag == id: _send_light_gain(id, v))
	row.add_child(slider)

	var gain_label := Label.new()
	gain_label.custom_minimum_size.x = 44
	row.add_child(gain_label)

	var check := CheckButton.new()
	check.text = "Горит"
	check.toggled.connect(func(on): _send_light(id, 1.0 if on else 0.0))
	row.add_child(check)

	var auto := Button.new()
	auto.text = "Авто"
	auto.tooltip_text = "Вернуть источник правилу (ночь, направление движения)"
	auto.pressed.connect(func(): _send_light_auto(id))
	row.add_child(auto)

	var en := CheckBox.new()
	en.text = "вкл"
	en.tooltip_text = "Выключенный источник не реагирует на команды и правила"
	en.toggled.connect(func(on):
		var comp := _get_mech_comp()
		if comp: comp.set_light_enabled(id, on))
	row.add_child(en)

	var status := Label.new()
	status.custom_minimum_size.x = 80
	row.add_child(status)

	_mech_list.add_child(row)
	_light_rows[id] = {"slider": slider, "gain_label": gain_label, "check": check, "auto": auto, "enabled": en, "status": status}


## Каждый кадр, пока вкладка открыта. Только синхронизация вида, команд не шлёт (set_*_no_signal)
func _update_mech_tab() -> void:
	var comp := _get_mech_comp()
	if comp == null:
		return
	_update_light_rows(comp)
	for item in comp.get_list():
		var r: Dictionary = _mech_rows.get(item.id, {})
		if r.is_empty():
			continue
		var usable: bool = item.enabled and item.found
		if _mech_drag != item.id:
			r.slider.set_value_no_signal(item.t)
		r.slider.editable = usable
		r.check.set_pressed_no_signal(item.target > 0.5)
		r.check.disabled = not usable
		r.enabled.set_pressed_no_signal(item.enabled)
		r.enabled.disabled = not item.found
		if not item.found:
			r.status.text = "нет части"
			r.status.modulate = Color(1.0, 0.302, 0.043, 1.0)
		else:
			r.status.text = "..." if item.moving else "%d%%" % roundi(item.t * 100.0)
			r.status.modulate = Color.WHITE


func _update_light_rows(comp: C_Mechanisms) -> void:
	for item in comp.get_light_list():
		var r: Dictionary = _light_rows.get(item.id, {})
		if r.is_empty():
			continue
		var usable: bool = item.enabled and item.found
		var has_rule: bool = item.rule != LightConfig.Rule.COMMAND
		if _light_drag != item.id:
			r.slider.set_value_no_signal(item.gain)
		r.slider.editable = usable
		r.gain_label.text = "%d%%" % roundi(item.gain * 100.0)
		r.check.set_pressed_no_signal(item.target > 0.5)
		r.check.disabled = not usable
		r.auto.disabled = not (usable and has_rule and item.manual)
		r.enabled.set_pressed_no_signal(item.enabled)
		r.enabled.disabled = not item.found
		r.status.modulate = Color.WHITE
		if not item.found:
			r.status.text = "нет света"
			r.status.modulate = Color(1.0, 0.302, 0.043)
		elif item.culled:
			var q: QualityPreset = GFX.get_quality()
			r.status.text = "свечение" if (q and q.entity_light_emissive_only) else "бюджет"
			r.status.modulate = Color(1.0, 0.75, 0.2)
		elif item.changing:
			r.status.text = "..."
		elif has_rule:
			r.status.text = "ручн." if item.manual else "авто"
		else:
			r.status.text = "%d%%" % roundi(item.t * 100.0)


func _send_light(id: StringName, state: float) -> void:
	if current_target:
		current_target.send_event("on_light_set", {"id": id, "state": state})


func _send_light_gain(id: StringName, gain: float) -> void:
	if current_target:
		current_target.send_event("on_light_gain", {"id": id, "gain": gain})


func _send_light_auto(id: StringName) -> void:
	if current_target:
		current_target.send_event("on_light_auto", {"id": id})


func _on_light_all(state: float) -> void:
	var comp := _get_mech_comp()
	if comp == null:
		return
	for item in comp.get_light_list():
		_send_light(item.id, state)


func _send_mech(id: StringName, state: float) -> void:
	if current_target:
		current_target.send_event("on_mechanism_set", {"id": id, "state": state})


func _on_mech_all(state: float) -> void:
	var comp := _get_mech_comp()
	if comp == null:
		return
	for item in comp.get_list():
		_send_mech(item.id, state)

## ======================================================================



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



##  ----VISUAL TAB ----
func _on_wagon_camera_button_pressed() -> void:
	if %WagonCameraButton.button_pressed:
		#printt('_on_wagon_camera_button_pressed')
		current_target.send_event('on_wagon_camera_selected',{'selected': true})
	else:
		#printt('_on_wagon_camera_button_pressed')
		current_target.send_event('on_wagon_camera_selected',{'selected': false})


## --- Вкладка "Материал" листа пенопласта (T7, XX claude-terra) ---
## Видна только у настоящего листа (C_TerrainLayer без C_Ghost). Стадия: C_TerrainLayer.FoamStage.

const STAGE_NAMES := ["Сырой пенопласт", "Шпаклёвка", "Краска", "Трава"]

var _terrain_tab: VBoxContainer
var _stage_option: OptionButton
var _terrain_info: Label


func _build_terrain_tab() -> void:
	_terrain_tab = VBoxContainer.new()
	_terrain_tab.name = "Материал"
	tab_container.add_child(_terrain_tab)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_terrain_tab.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	_terrain_info = Label.new()
	box.add_child(_terrain_info)
	var lbl := Label.new()
	lbl.text = "Стадия отделки листа"
	box.add_child(lbl)
	_stage_option = OptionButton.new()
	for n in STAGE_NAMES:
		_stage_option.add_item(n)
	_stage_option.item_selected.connect(_on_stage_selected)
	box.add_child(_stage_option)
	_set_terrain_tab_visible(false)


func _set_terrain_tab_visible(on: bool) -> void:
	var idx = tab_container.get_tab_idx_from_control(_terrain_tab)
	tab_container.set_tab_hidden(idx, not on)
	if not on and tab_container.current_tab == idx:
		tab_container.current_tab = 0


func _get_terrain_layer() -> C_TerrainLayer:
	if current_target == null or current_target.has_comp(C_Ghost):
		return null
	return current_target.get_comp(C_TerrainLayer) as C_TerrainLayer


func _update_terrain_tab() -> void:
	var layer := _get_terrain_layer()
	_set_terrain_tab_visible(layer != null)
	if layer:
		_stage_option.select(layer.stage)
		_refresh_terrain_info(layer)


## Размер в плане, толщина и положение по уровням. Живые значения: вкладка обновляется при смене цели и стадии
func _refresh_terrain_info(layer: C_TerrainLayer) -> void:
	var T: float = Global.settings.layer_height
	var identity := current_target.get_comp(C_Identity) as C_Identity
	var _size: Vector2 = identity.get_config('size', Vector2.ZERO) if identity else Vector2.ZERO
	var base := roundi(layer.base_y() / T)
	_terrain_info.text = "Размер: %d × %d u\nСлоёв: %d (высота %.1f u)\nНижний уровень: %d, верхний: %d\nВырезов: %d" % [
		_size.x, _size.y, layer.levels, layer.levels * T, base, base + layer.levels, layer.cuts.size()]


func _on_stage_selected(index: int) -> void:
	if _get_terrain_layer():
		current_target.send_event("on_terrain_stage_set", {"stage": index})



# ==========================================
# XX claude-terra 13.1.7. Трак: уровень, подъем, уклон
# ==========================================

const TRACK_ROWS_PERIOD := 0.25

var _track_rows_ready := false
var _track_acc := 0.0
var _lvl_label: Label
var _rise_label: Label
var _slope_label: Label


func _build_track_rows() -> void:
	var grid := %TrackContainer as GridContainer
	_lvl_label = _add_track_row(grid, "Level: ")
	_rise_label = _add_track_row(grid, "Rise: ")
	_slope_label = _add_track_row(grid, "Slope: ")
	_track_rows_ready = true


func _add_track_row(grid: GridContainer, title: String) -> Label:
	var t := Label.new()
	t.text = title
	grid.add_child(t)
	var v := Label.new()
	grid.add_child(v)
	return v


## Уровень (низ балласта в слоях над столом), подъем и уклон выбранного трака, призрака или трака в драге.
## Жесткий трак: подъем rise из TrackConfig, длина вдоль уклона. Flex: подъем и уклон из C_FlexShape (максимальный)
func _update_track_rows() -> void:
	var path := current_target.get_comp(C_Path) as C_Path if current_target else null
	if path == null or not is_instance_valid(path) or not current_target.is_inside_tree():
		return
	var T: float = Global.settings.layer_height

	# низ балласта: самая низкая точка кривой (у пандуса нижний конец), origin пандуса стоит в середине
	var y_low := current_target.global_position.y
	var samples := path.ballast_samples(4.0)
	if not samples.is_empty():
		y_low = INF
		for d in samples:
			y_low = minf(y_low, float(d["y"]))
	_lvl_label.text = "%.1f сл. (%.1f ю)" % [y_low / T, y_low]

	var flex := current_target.get_comp(C_FlexShape) as C_FlexShape
	var rise := path.rise
	var slope_pct := 0.0
	var slope_deg := 0.0
	if flex:
		rise = flex.dy
		slope_pct = flex.grade * 100.0
		slope_deg = rad_to_deg(atan(flex.grade))
		%LengthLabel.text = "%.1f u/sm" % flex.length
		%RadiusLabel.text = "inf" if is_inf(flex.radius) else "%d u/sm" % roundi(flex.radius)
		%DegLabel.text = "-"
	else:
		var L := path.get_length()   # у жесткого трака длина вдоль уклона
		if absf(rise) > 0.0001 and L > absf(rise):
			slope_deg = rad_to_deg(asin(absf(rise) / L))
			slope_pct = absf(rise) / sqrt(L * L - rise * rise) * 100.0
	_rise_label.text = "%+.1f ю" % rise if absf(rise) > 0.0001 else "0"
	_slope_label.text = "%.2f%% (%.1f°)" % [slope_pct, slope_deg] if slope_pct > 0.0 else "0"
