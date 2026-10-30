class_name InfoTransformTab extends InfoTab

###########################
## Вкладка «Положение»: координаты, физика вагона (живые значения и ручки), спидометр
###########################
## Узлы в info_panel.tscn (TransformTab). Компоненты цели кешируются при bind (и при их смене).

var _chassis: C_Chassis
var _kinemat: C_Kinematics
var _identity: C_Identity


func _setup() -> void:
	# Ручки физики вагона
	_n("FrictionSpinB").value_changed.connect(func(v: float) -> void: set_tuning("friction", v))
	_n("MassWSpinB").value_changed.connect(func(v: float) -> void: set_tuning("mass", v))
	_n("LinearDampSpinB").value_changed.connect(func(v: float) -> void: set_tuning("linear_damp", v))
	_n("RollResSpinB").value_changed.connect(func(v: float) -> void: set_tuning("roll_resistance", v))
	_n("AngularDampSpinB").value_changed.connect(func(v: float) -> void: set_tuning("angular_damp", v))
	_n("MaxGripSpinB").value_changed.connect(func(v: float) -> void: set_tuning("max_grip", v))
	_n("MinCurveRadius").value_changed.connect(func(v: float) -> void: set_tuning("min_curve_radius", v))
	# Спидометр
	_n("SpeedometerCheckBox").toggled.connect(func(_on: bool) -> void: _emit_speedometer())
	_n("SpeedometerVCheck").toggled.connect(func(_on: bool) -> void: _emit_speedometer())


## Состояние переключателей спидометра: [включен, вертикальный]
func speedometer_state() -> Array:
	return [_n("SpeedometerCheckBox").button_pressed, _n("SpeedometerVCheck").button_pressed]


func _emit_speedometer() -> void:
	var s := speedometer_state()
	panel.s_select_entity.emit(target, s[0], s[1])


func _on_bind() -> void:
	components_changed()
	refresh()


func _on_unbind() -> void:
	_chassis = null
	_kinemat = null
	_identity = null


func components_changed() -> void:
	if target == null:
		return
	_chassis = target.get_comp(C_Chassis) as C_Chassis
	_kinemat = target.get_comp(C_Kinematics) as C_Kinematics
	_identity = target.get_comp(C_Identity) as C_Identity


func refresh() -> void:
	if target == null:
		return
	var _pos := target.global_position
	var _rot := target.rotation_degrees
	_n("PosLabel").text = "(%.2f, %.2f, %.2f)" % [_pos.x, _pos.y, _pos.z]
	_n("RotLabel").text = "(%.2f, %.2f, %.2f)" % [_rot.x, _rot.y, _rot.z]
	if _chassis == null or _kinemat == null or not is_instance_valid(_kinemat.rb):
		return
	var _ontrack := _chassis.is_on_rails
	_n("OnTrackLabel").text = 'On' if _ontrack else 'Off'
	_n("FreezeLabel").text = 'On' if _kinemat.rb.freeze else 'Off'
	set_spin(_n("FrictionSpinB"), _kinemat.rb.physics_material_override.friction)
	set_spin(_n("LinearDampSpinB"), _kinemat.rb.linear_damp)
	set_spin(_n("AngularDampSpinB"), _kinemat.rb.angular_damp)
	if _identity:
		set_spin(_n("MassWSpinB"), _kinemat.mass)
		set_spin(_n("RollResSpinB"), _kinemat.roll_resistance)
		set_spin(_n("MaxGripSpinB"), _kinemat.max_grip)
	set_spin(_n("MinCurveRadius"), _kinemat.min_curve_radius)

	var speed := _chassis.current_speed if _ontrack else _kinemat.rb.linear_velocity.length()
	_n("SpeedmpsLabel").text = "%0.2f" % [speed] if abs(speed) > 0.05 else '0.0'

	var _spd_k := _kinemat.rb.linear_velocity.length()
	var _spd_s := _chassis.current_speed
	_n("SpeedKLabel").text = "%0.2f" % [_spd_k] if abs(_spd_k) > 0.05 else '0.0'
	_n("SpeedKmhLabel").text = 'no calc'
	_n("SpeedSLabel").text = "%0.2f" % [_spd_s] if abs(_spd_s) > 0.05 else '0.0'
