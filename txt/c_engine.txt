class_name C_Engine extends ICapability

####################
## Способность, Библиотека действий. Она живет на объекте всегда.
####################
## (Мотор): Считывает напряжение через контакт с C_PowerTrack под собой и преобразует его в вектор силы (Torque) или целевую скорость.

# Коэффициент конвертации напряжения (V) в скорость/тягу
var speed_multiplier: float = 10.5 

## Коэффициент конвертации напряжения/мощности в силу тяги N/V (Ньютоны на Вольт)
@export var force_multiplier: float = 10.0

## Максимальная сила тяги двигателя (Н), ограничение физики мотора
@export var max_tractive_force: float = 30.0

## Максимальная скорость (м/с), которую мотор может развить в вакууме при power=100.
## По сути, это коэффициент KV мотора (обороты на вольт), переведенный в линейную скорость.
@export var max_theoretical_speed: float = 6.0

# Что в моменте на моторе
var power = {
	'contour_id': 0 ,
	'voltage': 0.0 ,
	}


func _physics_process(_delta: float) -> void:
	
	var chassis = entity.get_comp(C_Chassis) as C_Chassis
	if not chassis or not chassis.is_on_rails:
		entity.send_event('on_force_changed', {'force': 0.0})
		return
	
	var bogie_comp = entity.get_comp(C_Bogie) as C_Bogie
	var active_voltage: float = 0.0
	var current_contour: int = 0
	
	# ... (код получения питания) ..
	for bogie in bogie_comp.bogies_data:
		
		if not is_instance_valid(bogie.current_track):
			continue
			
		var power_track = bogie.current_track.get_comp(C_PowerTrack) as C_PowerTrack
		if power_track and power_track.contour_id != 0:
			current_contour = power_track.contour_id
			var raw_voltage = PGM.get_power(current_contour)
			
			# Учитываем полярность/разворот трака относительно контура питания
			#var polarity = 1.0 if power_track.is_flipped else -1.0
			active_voltage = raw_voltage# * polarity
			#break

	# Обновляем состояние мотора
	power.contour_id = current_contour
	power.voltage = active_voltage

	# Если 0, то выход
	if active_voltage == 0.0:
		entity.send_event('on_force_changed', {'force': 0.0})
		return

	# 1. Считаем предел скорости для текущего напряжения (имитация KV мотора)
	# При 50В максимальная скорость будет в два раза ниже, чем при 100В
	var voltage_ratio = active_voltage / 100.0 # Нормализуем напряжение (0.0 ... 1.0)
	var target_max_speed = max_theoretical_speed * voltage_ratio
	
	# 2. Узнаем текущую скорость вагона из шасси
	var current_speed = chassis.current_speed
	
	# 3. Имитация ПротивоЭДС: чем ближе текущая скорость к целевой, тем меньше тяга
	# Если мы стоим, speed_factor = 0. Если достигли предела, speed_factor = 1
	var speed_factor = 0.0
	if target_max_speed != 0.0:
		speed_factor = clamp(current_speed / target_max_speed, 0.0, 1.0)
	
	# Формула падающей тяги: F = F_max * (1 - V_cur / V_max)
	var engine_force = max_tractive_force * (1.0 - speed_factor) * sign(active_voltage)
	printt('engine_force=',  engine_force)

	# Отправляем рассчитанную силу
	entity.send_event('on_force_changed', {'force': engine_force})
	
