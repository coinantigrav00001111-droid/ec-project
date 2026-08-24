class_name C_Engine extends ICapability

####################
## Способность, Библиотека действий. Она живет на объекте всегда.
####################
## (Мотор): Считывает напряжение через контакт с C_PowerTrack под собой и преобразует его в вектор силы (Torque) или целевую скорость.

# Коэффициент конвертации напряжения (V) в скорость/тягу
var speed_multiplier: float = 10.5 

func _physics_process(_delta: float) -> void:
	var chassis = entity.get_comp(C_Chassis)
	
	# 1. Проверяем наличие шасси, контакт с рельсами и валидность трака
	if not chassis or not chassis.is_on_rails or not is_instance_valid(chassis.current_track):
		entity.send_event('on_speed_changed', {'speed': 0.0})
		return

	# 2. Получаем электрический компонент трака, на котором стоим
	var power_track = chassis.current_track.get_comp(C_PowerTrack) as C_PowerTrack
	if not power_track:
		# Трак не электрифицирован
		entity.send_event('on_speed_changed', {'speed': 0.0})
		return

	# 3. Читаем напряжение контура и передаем импульс
	var contour = power_track.contour_id
	var voltage = PGM.get_power(contour)
	
	if voltage != 0.0:
		# Вагон движется пропорционально поданному напряжению
		var target_speed = voltage * speed_multiplier
		entity.send_event('on_speed_changed', {'speed': target_speed})
	else:
		entity.send_event('on_speed_changed', {'speed': 0.0})
