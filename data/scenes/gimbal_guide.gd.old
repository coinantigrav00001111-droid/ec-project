extends Node3D

########################
##  Верхний узел(Gimbal) отвечает за перемещение и вращение камеры
##  Средний узел(Elevation) отвечает за высоту
##  Нижний узел(camera) отвечает за зум (позиция z )
########################

# Для ввода используется GUIDE аддон. 
# camera.tres - mapping_context -  карта экшенов. В ней создаются привязки инпутов к экшенам.
# Action получает ⚡Сигнал и передает его в скрипт . Все экшены в папке actions


# EXPORT PARAMS

@export_category('GUIDE')
## Контроллер input 
@export var move_action:GUIDEAction
@export var rotate_action:GUIDEAction
#@export var elevate_action:GUIDEAction
@export var zoom_action:GUIDEAction
@export var move_m_action:GUIDEAction
#@export var toggle_move_action:GUIDEAction
@export var mmb_action:GUIDEAction

@export_category('Gimbal')
@export_group('Move')
## скорость скролла кнопками
@export_range (0.01, 1, 0.01) var wasd_speed : float = 0.1
## скорость скролла мышью
@export_range (0.0001, 0.1, 0.0001) var drag_speed : float = 0.01 
## замедление скорости скролла
@export_range (0.01, 2, 0.01)  var damp_speed : float = 0.22	
# множителя скорости
@export var speed_multiplier : int = 5
# расстояние включения множителя скорости 
@export var speed_mult_distance : int = 15 

@export_group('Zoom')
## разрешить зум к курсору
@export var zoom_to_curser: bool = true			
## отдаление
@export_range (1, 200, 0.1) var zoom_max : float = 20		
## приближение	
@export_range (0.1, 1, 0.1) var zoom_min : float = 0.5	
## замедление скорости зума	
@export_range (0, 1, 0.05)  var zoom_damp : float = 0.8
## скорость зума
@export_range (0.1, 40, 0.1) var zoom_speed : float = 10
# множитель зума при расстоянии > mult_distance
@export var zoom_multiplier : int = 5
# расстояние включения множителя зума 
@export var mult_distance : int = 15 

@export_group('Rotate')
## скорость вращения
@export_range (0.001, 0.02, 0.0001)  var  rotate_speed : float = 0.005	
## замедлентие скорости вращения
@export_range (1.0, 30.0, 0.5) var rotate_damp : float = 8
## инверсия вращения 
@export var rotate_inv: bool = false	

@export_group('Elevation')
## верхняя точка
@export_range (-4, 0, 0.01) var elevation_max : float = -2.0
## нижняя точка
@export_range (-0.3, 0.6, 0.01) var elevation_min : float = 0.02 # нижняя точка

@export_group('Helpers')
#helpers
## скролл по краю
@export var scroll_edge = false 	
## Маркер центра вкл\выкл
@export var center_visible = true
## ограничение дальности передвижения камеры(граница мира)
@export var camera_move_edge = 1000 
## Нода, к которй камеру можно зацепить
@export var target : NodePath		



########################
# PARAMS & flags
########################
@onready var camera = $Elevation/Camera
@onready var elevation = $Elevation
var move = Vector3()	# Вектор определяет сколько будет мув
var zoom = 1.0			# Для старой версии зума. Начальный, управляет scale подвеса(гимбала)
var zoom_direction = 0.0	# для зума
var rotate_decelerate :Vector2 = Vector2.ZERO # замедление вращения после отпускания мыши
var camera_input :Vector2 = Vector2.ZERO	# для вращения временное смещение от мыши
# Позиция курсора
const RAY_LENGTH = 1000
const GROUND_PLANE = Plane(Vector3.UP, 0)
#var drag_mouse		# переменная из RR



########################
# OVERRIDE FUNCTIONS
########################

func _ready() -> void:
	%MeshCenter.visible = center_visible # Маркер центра вкл\выкл
	
	# Триггеры кнопки включения поворотов и мува мышью камеры
	move_m_action.triggered.connect(_camera_move)



func _process(delta):
	
	# --Rotate----Elevate --
	_camera_rotate(delta)

	# --Zoom --
	_zoom(delta) # выполняется только если задан новый зум 
	
	if scroll_edge:	#скролл по краю, то постоянно опрос позиции мыши, что не есть хорошо
		move_edge() 

	#💡 это итоговое перемещение камеры на вектор move.
	move_cam(delta) 
	#TODO Там же мув кнопками и по краю
	
	# если нужен таргет для камеры(не проверено)
	if target:
		global_transform.origin = get_node(target).global_transform.origin



## -----ROTATE ELEVATE-----

func _camera_rotate(delta):
	# Если ммб или замедление
	if mmb_action.value_bool or rotate_decelerate.length() >0.005:
		
		rotate_decelerate = rotate_decelerate.lerp(\
			rotate_action.value_axis_2d * rotate_speed,\
			delta * rotate_damp)
	else:
		# скорость  вращения замедляем пока не 0.001, потом 0
		rotate_decelerate = Vector2.ZERO

	## --Rotate --
	var p = 1 if rotate_inv else -1 # инверсия если вкл
	rotate_object_local(Vector3.UP, p * rotate_decelerate.x) 
	
	## --Elevate --
	elevation.rotate_object_local(Vector3.RIGHT, rotate_decelerate.y) 
	elevation.rotation.x = clamp(elevation.rotation.x, elevation_max, elevation_min)



## -------ZOOM--------
## новый вариант зума с зумом на курсор
## Изменение позиции Z узла camera.
func _zoom(delta: float) -> void:
	# Если колесо крутнули, то получили направление зума -1 или 1
	if zoom_action.value_axis_1d != 0:
		zoom_direction = zoom_action.value_axis_1d 
		
	# Выход если нет зума
	if zoom_direction == 0: return
	
	# Множитель зума от расстояния. 
	var mult = 1 if camera.position.z <=mult_distance else zoom_multiplier 
	var new_zoom = clamp(camera.position.z + mult * zoom_direction * zoom_speed * delta,
		zoom_min, zoom_max)
	
	# запоминаем позицию курсора на плоскости до зума
	var pointing_at = _get_ground_position() 
	camera.position.z = new_zoom
	
	# сдвиг камеры, если включен зум на курсор
	if zoom_to_curser and pointing_at != null:
		_realign_camera(pointing_at)
	
	# скорость затухания уменьшаем пока не 0.0001, потом 0
	zoom_direction *= zoom_damp
	if abs(zoom_direction) < 0.001:
		zoom_direction = 0




func _camera_move():

	var mult = 1 if camera.position.z <=speed_mult_distance else speed_multiplier

	 # Вектор определяет сколько будет мув
	move -=  basis * move_m_action.value_axis_3d * drag_speed * mult



## Итоговое  перемещение камеры  и + кнопками тут пока
## TODO колбасит каждый кадр
func move_cam(_delta):
	#окно игры в фокусе
	if !get_viewport().get_window().has_focus(): return

	#кнопки -  вперед\назад	,  влево\вправо - одна функция из guide 

	move = lerp(move, basis * move_action.value_axis_3d * wasd_speed, damp_speed)

	#move camera
	if move.length() == 0 : return # камера меняет позицию  только если вектор 

	position += move

	
		
#Сдвиг камеры по краю экрана. Тяжелая функция, т.к. выполняется постоянно
func move_edge():
		var viewport_size = get_viewport().size
		var mouse_pos = get_viewport().get_mouse_position()
		var ui_border =$"../../UI".size.y
		#get inputs
		var down_border=mouse_pos.y > ui_border and mouse_pos.y < ui_border + 20
		var up_border=mouse_pos.y < viewport_size.y - ui_border and mouse_pos.y > (viewport_size.y - ui_border - 20)
		var l_border=mouse_pos.x < viewport_size.x and mouse_pos.x > (viewport_size.x - 20)
		var r_border=mouse_pos.x > 0  and mouse_pos.x < 20
		if down_border:
			move.z = lerp(move.z,-wasd_speed, damp_speed)
		elif up_border:
			move.z = lerp(move.z,wasd_speed, damp_speed)
		else:
			move.z = lerp(move.z, 0.0, damp_speed)
		if r_border:
			move.x = lerp(move.x,-wasd_speed, damp_speed)
		elif l_border:
			move.x = lerp(move.x,wasd_speed, damp_speed)
		else:
			move.x = lerp(move.x, 0.0, damp_speed)



##############################
# HELPERS
##############################

# позиция пересечения луча и плоскости . Есть во все  скриптах.
func _get_ground_position() -> Vector3:
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_from = camera.project_ray_origin(mouse_pos)
	var ray_to = ray_from + camera.project_ray_normal(mouse_pos) * RAY_LENGTH
	var cursorpos = GROUND_PLANE.intersects_ray(ray_from, ray_to) 
	if cursorpos == null:
		cursorpos = Vector3.ZERO
	return cursorpos



# сдвигаем камеру к точке на курсор
func _realign_camera(point: Vector3) -> void:
	var new_position = _get_ground_position()
	if new_position == null:
		return
	position += point - new_position	# смена позиции узла на вектор 


## Это сохраняется отдельно пока
#func _on_save_game(saved_data:Array[SavedData]):
	#var my_data =SavedData.new()
	#my_data.gimbal_transform = global_transform
	#my_data.gimbal_elevation = elevation.transform
	#my_data.gimbal_camera = camera.transform
	#my_data.scene_path = "res://scenes/gimbal.tscn"
	#
	#saved_data.append(my_data)
