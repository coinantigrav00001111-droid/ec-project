extends DCController

########################
## Контроллер 1 
########################

## Этот контроллер самая простая версия, хоть и наследует из pwm 
## переключение контура для дебага , в релизе выключить
##
## Ручка управляется нодой HandlePower, 
## начальное положение и размер картинки - Handle_texture
##
## Меняет текущее значение повер из положения ручки и позиции sign_power
## Выдает сигнал для PowerController с контуром(только + ) питанием на нем

func _ready() -> void:
	super()
	## TODO Это есть в род классе, можно убрать?
	$DirectionSliderLabels.visible = !rotation_with_direction
	$DirectionSlider.visible = !rotation_with_direction


## Переписываем функцию родит. класса 
func current_power_local() -> void:
	var _handle_angle = %HandlePower.rotation_degrees
	power_local  = int(power_mult * _handle_angle / handle_max_angle * 100 * sign_power) 
	
	# Пересчет если в обе стороны крутим
	if rotation_with_direction:
		power_local = int(power_mult *  (power_local - 50) * 2)
	var _dir
	if power_local > 0 :
		%DirectionLabel.text = '🠊'
		#%PowerProgressBar.fill_mode = 0
	elif power_local < 0 :
		%DirectionLabel.text = '🠈'
		#%PowerProgressBar.fill_mode = 1
	else:
		%DirectionLabel.text = '-'
	
	%PowerLabel.text = str(power_local) + '%'
	%ContourLabel.text = 'C: ' + str(active_contour)
	
	# Подача сигнала с питание в контур. 0 - во все 
	#change_power_pwm.emit(power_local, active_contour)
	PGM.set_power_pwm(active_contour, power_local)
