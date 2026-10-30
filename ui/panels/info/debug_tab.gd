class_name InfoDebugTab extends InfoTab

###########################
## Вкладка «Debug»: список компонентов, тюнинг подвески и сцепления, камера вагона
###########################
## Узлы в info_panel.tscn (DebugTab). Спинбоксы тюнинга переедут в DebugPanel в U14.


func _setup() -> void:
	_n("EnableSusp").pressed.connect(func() -> void: set_tuning("enable_suspension", _n("EnableSusp").button_pressed))
	_n("EnableVert").pressed.connect(func() -> void: set_tuning("debug_susp_vertical", _n("EnableVert").button_pressed))
	_n("EnablePitch").pressed.connect(func() -> void: set_tuning("debug_susp_pitch", _n("EnablePitch").button_pressed))
	_n("EnableRoll").pressed.connect(func() -> void: set_tuning("debug_susp_roll", _n("EnableRoll").button_pressed))
	_n("EnableLateral").pressed.connect(func() -> void: set_tuning("debug_susp_lateral", _n("EnableLateral").button_pressed))
	_n("SuspMult").value_changed.connect(func(v: float) -> void: set_tuning("effect_multiplier", v))
	_n("LongGrip").value_changed.connect(func(v: float) -> void: set_tuning("longitudinal_grip", v))
	_n("MaxYawDeg").value_changed.connect(func(v: float) -> void: set_tuning("max_yaw_deg", v))
	_n("YawSpring").value_changed.connect(func(v: float) -> void: set_tuning("yaw_spring", v))
	_n("WagonCameraButton").pressed.connect(_on_wagon_camera_button_pressed)


func _on_bind() -> void:
	update_text()
	refresh()


func components_changed() -> void:
	update_text()


## Камера вагона включена: следующий клик по пустоте или другому объекту только выключает ее (см. InfoPanel.set_target)
func wagon_camera_active() -> bool:
	return _n("WagonCameraButton").button_pressed


func release_wagon_camera() -> void:
	_n("WagonCameraButton").press()


func _on_wagon_camera_button_pressed() -> void:
	if target:
		target.send_event('on_wagon_camera_selected', {'selected': _n("WagonCameraButton").button_pressed})


## Значения ручек из компонентов цели (без сигналов и не в поле ввода)
func refresh() -> void:
	if target == null:
		return
	var _chassis := target.get_comp(C_Chassis) as C_Chassis
	var _kinemat := target.get_comp(C_Kinematics) as C_Kinematics
	var _engine := target.get_comp(C_Engine) as C_Engine
	if not _chassis or not _kinemat or not _engine:
		return
	_n("EnableSusp").set_pressed_no_signal(_chassis.enable_suspension)
	_n("EnableVert").set_pressed_no_signal(_chassis.debug_susp_vertical)
	_n("EnablePitch").set_pressed_no_signal(_chassis.debug_susp_pitch)
	_n("EnableRoll").set_pressed_no_signal(_chassis.debug_susp_roll)
	_n("EnableLateral").set_pressed_no_signal(_chassis.debug_susp_lateral)
	set_spin(_n("SuspMult"), _chassis.effect_multiplier)
	set_spin(_n("LongGrip"), _kinemat.longitudinal_grip)
	set_spin(_n("MaxYawDeg"), _kinemat.max_yaw_deg)
	set_spin(_n("YawSpring"), _kinemat.yaw_spring)
	set_spin(_n("MaxTractiveForceB"), _engine.max_tractive_force)
	set_spin(_n("MaxTheoreticalSpeedB"), _engine.max_theoretical_speed)


## Список компонентов цели одним присваиванием. Зовется при bind и когда компонент добавлен или убран
func update_text() -> void:
	if not target: return
	
	# Cобираем ОДНУ строку
	var text_dump = "[color=green]Components:[/color]\n"
	for child in target.get_children():
		if child is Component:
			if child.is_state:
				text_dump += "[color=yellow]-" + child.get_script().get_global_name() + " - state[/color]\n"
			else:
				text_dump += "- " + child.get_script().get_global_name() + "\n"
			
	# Присваиваем текст один раз. Никаких утечек памяти!
	_n("DebugText").text = text_dump
