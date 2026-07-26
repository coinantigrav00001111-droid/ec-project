class_name DCController extends Panel

################################
## DC (Direct Current) Controller PWM
################################

## Базовый контроллер питания жд, все контроллеры дочерние от него
## DCC (Digital Command Control) будет потом
## 
## Ручка управляется родительской нодой HandlePower, 
## начальное положение и размер - Handle_texture
##
## Контроллер выдает питание в PowerControlleer, который занимается дальнейшей его обработкой
## Изначально предполагает pwm (ШИМ) структуру. То есть можно выбирать контур для регулировки мощностью. Однако простейшая реализация может быть только с общей регулировкой и наследуется из этого класса
## 
## Для каждого контроллера есть свой ресурс в папке object. Он используется при нажатии кнопки создания в меню лвл2


########################
##  Основные переменные
########################

## Ресурс с настройками экземпляра 
var object_setting :DCControllerSetting

## Подача мощности в 0 - 100% с учетом направления +-. 
# текущий повер внутри контроллера
var power_local : int = 0 
#var power_memory : Dictionary[int, int] = {}

## Множитель мощности для умножения мощности. Не реализовано. Учитывать float!
## В текущем состоянии этот множитель используется в кнопке выключения питания всего
var power_mult : float = 1.0

## Активный контур, в который передается питание. 0 - во все
var active_contour : int = -1

## Mаксимальный угол поворота ручки, чем меньше, тем надежней блокровка на крайних значениях
@export var handle_max_angle : int = 330
## Вращение ручки в обе стороны вместо переключателя полярности
@export var rotation_with_direction : bool = false


########################
##  Внутренние переменные и флаги 
########################

##REF проверить переменные, которые можно передавать через аргументы, чтобы не болтались в памяти
var sign_power = 1 # полярность 
var mouse_on_handle = false #мышь над ручкой
var mousepos # позиция мыши
var delta_a = 0 #дельта между углом мыши и ручки
var power_changing = false #идет изменение повер
var power_min = false #ручка в мин позиции
var power_max = false #ручка в макс позиции
var pre_a = 0 #предыдущее значение угла для расчетов



# ⚡Сигнал текущей power в обработчик powermanager
signal change_power_pwm(power, contour)
@warning_ignore("unused_signal")
signal onoff_power_pwm(onoff)



########################
##   Переопределенные функции
########################

func _ready() -> void:
	# Имя контроллера на корпусе
	var _model_index = 'B' if rotation_with_direction else 'A'
	$ModelLabel.text += str(handle_max_angle) + _model_index
	
	# начальное значение кнопки видимости 
	%ShowControllerButton.button_pressed = true 
	# реакция на кнопку dc контроллера (в редакторе он виден по умолчанию)
	_on_show_controller_button_pressed() 
	
	# по умолчанию слайдер полярности есть, иначе настраиваем положение ручки
	if rotation_with_direction :
		%HandlePower.rotation_degrees = float (handle_max_angle) / 2
		$DirectionSliderLabels.visible = false
		$DirectionSlider.visible = false
	else:
		%HandlePower.rotation_degrees = 0 
	$HandlePower/Handle_texture.rotation_degrees = - float(handle_max_angle) / 2

	#XX подключаемся к powercontroller
	#change_power_pwm.connect(PC.on_change_power_dc)
	#onoff_power_pwm.connect(PC.on_onoff_power_dc)



## Контроль ручки
func _input(event) -> void:
	#освобождаем ручку
	if Input.is_action_just_released("lmb"):
		mousepos = get_viewport().get_mouse_position()
		power_changing = false

	# вращаем ручку
	if power_changing and event is InputEventMouseMotion:
		rotate_handle()



func _physics_process(_delta: float) -> void:
	# если ручку взяли, то смотрим позицию мыши
	if power_changing:
		mousepos = get_viewport().get_mouse_position()


########################
## Свои функции 
########################

## настройки передаются в объект перед реди
func new_setting(_setting: DCControllerSetting) -> void:
	object_setting = _setting 
	# Это нужно и для передачи туда текущего остояния питания
	rotation_with_direction = object_setting.rotation_with_direction
	handle_max_angle = object_setting.handle_max_angle
	name =  'DCControllerPanel'  # Имя не влияет ни на что пока



## Меняет текущее значение повер из положения ручки и позиции sign_power
## Вызывается при вращении ручки и смене полярности в слайдере
## Выдает сигнал для PowerController с контуром(только + ) питанием на нем
func current_power_local() -> void:
	var _handle_angle = %HandlePower.rotation_degrees
	#power_local  = int(power_mult * (round(_handle_angle / handle_max_angle*100) * sign_power))
	power_local  = int(power_mult * (_handle_angle / handle_max_angle * 100 * sign_power))
	# Пересчет если в обе стороны крутим
	if rotation_with_direction:
		power_local  =int(power_mult * (power_local - 50) * 2)
	var _dir
	if power_local > 0 :
		%DirectionLabel.text = '🠊'
		%PowerProgressBar.fill_mode = 0
	elif power_local < 0 :
		%DirectionLabel.text = '🠈'
		%PowerProgressBar.fill_mode = 1
	else:
		%DirectionLabel.text = '-'
	
	%PowerProgressBar.value = abs(power_local)
	%ContourLabel.text = 'C: ' + str(active_contour)

	# Подача сигнала с питание в контур. 0 - во все 
	change_power_pwm.emit(power_local, active_contour)



## Обработка вращения ручки
func rotate_handle() -> void:
	# угол положения мыши относительно ручки в положении 0
	var mouse_a0 = floor( rad_to_deg(%HandlePower.global_position.angle_to_point(mousepos)))

	# угол положения мыши относительно ручки если ручка не в 0
	var mouse_a = mouse_a0 - delta_a
	
	# считаем угол в диапазоне 0-max_угол 
	var calibrating_a = calc_calibrating_angle(mouse_a)
	
	#фиксируем угол с учетом минмакс значений
	calibrating_a = check_minmax(calibrating_a, handle_max_angle) 
	%HandlePower.rotation_degrees = calibrating_a 
	
	# Выставляем значение power_local по углу ручки с учетом полярности и сигнал в повер контроллер
	current_power_local()




########################
## Служебные функции
########################

## Устанавливаем угол ручки с учетом диапазона и ограничителей
func check_minmax(calibrating_a, _max=270):
	if calibrating_a >= 0 and calibrating_a <= _max: # в диапазоне регулировки
		if power_min: #если завели в мин
			if calibrating_a < 20: # то пока не поставить в 20 и меньше ничего не будет
				power_min = false
			else:
				calibrating_a = 0
	
		elif power_max: #если завели в макс 
			if calibrating_a > _max - 20: # то пока не поставить в 250 и больше ничего не будет
				power_max = false
			else:
				calibrating_a = _max

	# если очень резко дергать, то проброс к минмакс в этом диапазоне
	elif pre_a <= 50:
		calibrating_a = 0
		power_min = true
		
	elif pre_a >= _max - 50:
		calibrating_a = _max
		power_max = true
		
	#если происходит перекидывание то обнуляем
	if calibrating_a > _max:
		printt('Error rortating handle! Set zero position.')
		calibrating_a = 0
		
	pre_a = calibrating_a
	return calibrating_a



## задаем угол в диапазоне 0-360
func calc_calibrating_angle(a)-> float:
	#устанавливаем а в 0-360
	if  a < 0:
		a += 360
	if a > 360:
		a -= floor(a / 360) * 360

	# Смещение на угол калибрате
	if a >= 360 :
		a -= 360 
	
	return a




########################
## Сигналы 
########################

## Переключатель слайдера направления 🠊🠈
func _on_direction_slider_value_changed(value: float) -> void:
	if rotation_with_direction:
		#направление подачи энергии - -1 +1
		match  int(value):
			1 : %DirectionLabel.text = '🠊'
			0 : %DirectionLabel.text = '-'
			-1 : %DirectionLabel.text = '🠈'
	sign_power = value
	current_power_local()



##Кнопка вкл\выкл видимости контроллера
func _on_show_controller_button_pressed() -> void:
	var contr_size = $".".size
	var y_offset =%CatContainer.size.y + 5 # смещение по вертикали на высоту CatContainer


	if %ShowControllerButton.button_pressed:
		$".".position = Vector2(5, get_viewport().size.y - contr_size.y - y_offset)
		%ShowControllerButton.text = '<'
	else :
		$".".position = Vector2( -contr_size.x , get_viewport().size.y - contr_size.y - y_offset)
		%ShowControllerButton.text = '>'



## мышь на ручке	
func _on_handle_texture_mouse_entered() -> void:
	mouse_on_handle = true



## мышь не на ручке
func _on_handle_texture_mouse_exited() -> void:
	mouse_on_handle = false



## События на ручке
func _on_handle_texture_gui_input(_event: InputEvent) -> void:
	#если мышь на ручке, нажата лкм повер не начали менять, то задаем старт
	if mouse_on_handle and Input.is_action_just_pressed("lmb") and !power_changing:
		mousepos = get_viewport().get_mouse_position()
		delta_a = floor(rad_to_deg(%HandlePower.global_position.angle_to_point(mousepos) - %HandlePower.rotation))
		power_changing = true
	
	# По пкм обнуляем ручку
	if mouse_on_handle and Input.is_action_just_pressed("rmb") and !power_changing:
		if rotation_with_direction :
			%HandlePower.rotation_degrees = float (handle_max_angle) / 2
		else:
			%HandlePower.rotation_degrees = 0 
		
		current_power_local()

## Слайдер для активного контура. 0 - питает все контуры
func _on_contour_slider_value_changed(value: float) -> void:
	active_contour = int(value)
	%ContourLabel.text = 'C: ' + str(active_contour)



## Кнопка выключени питания. Импользует множитель power_mult = 0
func _on_power_button_pressed() -> void:
	var pwr_on = %PowerButton.button_pressed
	if !pwr_on: #Выкл
		#power_mult = 0
		active_contour = 0
		%PowerSlider.value =0
		
		#onoff_power_pwm.emit(pwr_on) # Подача сигнала питание выкл в powermanager 
	else: # Вкл
		#power_mult = 1
		active_contour = %ContourSlider.value
		#onoff_power_pwm.emit(pwr_on) # восстановит все из мемори
		current_power_local() # обновляем питание по ручке
	
	PGM.emergency_stop(!pwr_on)

	
