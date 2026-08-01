# ghost_wagon.gd
extends Node3D
class_name GhostNode

## Ресурс с настройками экземпляра 
var object_setting :WagonSetting
# Добавляем одну важную переменную для памяти разворота
var visual_is_flipped := false
var was_on_track := false # Для отслеживания момента захода на рельс

@onready var sensors: GhostSensorController = $GhostSensorController
@onready var mesh_node: Node3D = $WagonMesh

@export_group("Spawn")
@export var wagon_start_id := "2"
#@export var wagon_start_dir := true 
@export var wheelbase := 6.0 # Расстояние между осями
@export var magnet_enabled := true # Можно вынести в настройки или переключать по кнопке

@export_group("Physics")
@export var v_max_kmh := 100.0
@export var accel_time := 3.0

var rail_ready := false
var current_speed := 0.0
var acceleration := 0.0

# Данные передней оси
var curve_f: Curve3D; var path_f: Path3D; var offset_f := 0.0; var sign_f := 1
# Данные задней оси
var curve_r: Curve3D; var path_r: Path3D; var offset_r := 0.0; var sign_r := 1

var delta_cursor : Vector3 #смещение мышки от центра выбранного вагона



## настройки передаются в wagon перед _ready 
func new_setting(_selected_setting: WagonSetting) -> void:
	object_setting = _selected_setting 

""" ЭТО заезжает при выборе трака
	if GM.currentObj == null:
		self.send_event.call_deferred('to_selected')	# сигнал в контур
		pass
	elif !GM.currentObj.in_collision:
			self.send_event.call_deferred('to_selected')	# сигнал в контур
		
	GM.currentObj = _atrack # setting уже прописан
	#GM.selectedSetting = _atrack.object_id
	GM.selectedSetting = _atrack.object_setting
	
	UI.info_panel.info_update.emit(true, _atrack) # сигнал в панельинфо
	self.set_expression_property('edit_on', false)	
	"""
	


func _ready() -> void:
	acceleration = (v_max_kmh / 3.6) / max(accel_time, 0.001)
	#if mesh_node:
		#mesh_node.rotation_degrees.y = 0 if wagon_start_dir else 180
	"""XXX  каррент заточен под трак - плохо"""
	GM.currentObj = self
	_setup_wagon()

""" Делаем нормальный спавн"""


func _setup_wagon() -> void:
	# Если пока мы тащили вагон, он "зацепился" за рельсы (rail_ready = true)
	if rail_ready:
		# Просто переинициализируем знаки движения для физики
		_init_logic() 
		print("Вагон успешно зафиксирован на рельсах")
	else:
		# Если нажали ЛКМ в пустом месте — вагон просто стоит на земле (Y=0)
		print("Вагон стоит вне путей")
		
		
func _init_logic() -> void:
	# Нам больше не нужно ничего вычислять! 
	# Все офсеты и пути уже записаны в _move.
	# Просто сбрасываем знаки в дефолт (по шерсти кривой)
	sign_f = 1
	sign_r = 1
	rail_ready = true
	
	#_update_wagon_transform()


func _physics_process(delta: float) -> void:
	if not rail_ready: 
		# Если мы не на рельсах, мы всё равно хотим видеть дебаг-лучи!
		_draw_debug_vectors()
		return
	# Логика движения по рельсам
	if not GM.stateChartGM.wagon_move:
		var target_speed = (UI.dc_controller.power_local / 100.0) * (v_max_kmh / 3.6)
		current_speed = move_toward(current_speed, target_speed, acceleration * delta)
	
		_move_probes()

		# Двигаем обе оси
		offset_f += current_speed * delta * sign_f
		offset_r += current_speed * delta * sign_r
	
		# Проверяем переходы для каждой оси независимо
		_check_transition_for_axle("front")
		_check_transition_for_axle("rear")

	# Если режим перетаскивания мышкой, то нет трансформа
	#if GM.stateChartGM.wagon_move: return 
	#_update_wagon_transform()
	#if not GM.stateChartGM.wagon_move:
		_update_wagon_transform()
	
	# Вызываем дебаг в каждом кадре
	_draw_debug_vectors()




func _draw_debug_vectors() -> void:
	# GhostNode (Физика) - СИНИЙ (всегда вдоль рельс)
	DebugDraw3D.draw_ray( global_position + Vector3(0,2,0),  -global_transform.basis.z * 3, 5, Color.CORNFLOWER_BLUE)
	
	# WagonMesh (Морда) - ЗЕЛЕНЫЙ (куда едем при speed > 0)
	if mesh_node:
		DebugDraw3D.draw_ray(mesh_node.global_position + Vector3(0,2,0), -mesh_node.global_transform.basis.z * 2.5, 5, Color.CHARTREUSE)
		
		
		
func _move_probes() -> void:
	if current_speed == 0: return
	var shift = -0.15 * sign(current_speed)
	# Выносим лучи на обеих тележках
	for probe in [$GhostRailProbeFront, $GhostRailProbeRear]:
		probe.get_node("RayDown_L").position.z = shift
		probe.get_node("RayDown_R").position.z = shift


func _check_transition_for_axle(type: String) -> void:
	var cur_offset = offset_f if type == "front" else offset_r
	var cur_curve = curve_f if type == "front" else curve_r
	var cur_path = path_f if type == "front" else path_r
	var cur_len = cur_curve.get_baked_length()
	
	if cur_offset >= 0 and cur_offset <= cur_len: return
	
	var sensor = sensors.front if type == "front" else sensors.rear
	if not sensor.curve or sensor.curve == cur_curve: return

	var excess = cur_offset - cur_len if cur_offset > cur_len else -cur_offset
	var old_dir = _get_curve_dir(cur_curve, cur_path, cur_len * 0.5)
	var new_dir = _get_curve_dir(sensor.curve, sensor.path, 0.5)
	var same_dir = old_dir.dot(new_dir) > 0
	
	var new_sign = (1 if same_dir else -1) * (sign_f if type == "front" else sign_r)
	var new_offset = 0.0
	
	if same_dir:
		new_offset = excess if cur_offset > cur_len else sensor.curve.get_baked_length() - excess
	else:
		new_offset = sensor.curve.get_baked_length() - excess if cur_offset > cur_len else excess

	if type == "front":
		curve_f = sensor.curve; path_f = sensor.path; offset_f = new_offset; sign_f = new_sign
	else:
		curve_r = sensor.curve; path_r = sensor.path; offset_r = new_offset; sign_r = new_sign



func _update_wagon_transform() -> void:
	var p_f = path_f.to_global(curve_f.sample_baked(offset_f))
	var p_r = path_r.to_global(curve_r.sample_baked(offset_r))
	
	global_position = (p_f + p_r) * 0.5
	
	var forward_rail = (p_f - p_r).normalized()
	var up = (sensors.front.up_vector + sensors.rear.up_vector).normalized()
	if up.length() < 0.1: up = Vector3.UP
	var right = up.cross(forward_rail).normalized()
	var actual_up = forward_rail.cross(right).normalized()
	
	global_transform.basis = Basis(right, actual_up, -forward_rail).orthonormalized()
	
	# Применяем флип только к мешу
	if mesh_node:
		mesh_node.rotation.y = PI if visual_is_flipped else 0.0
		
		
#func _update_wagon_transform() -> void:
	#var p_f = path_f.to_global(curve_f.sample_baked(offset_f))
	#var p_r = path_r.to_global(curve_r.sample_baked(offset_r))
	#
	#global_position = (p_f + p_r) * 0.5
	#
	## Базис Ghost-ноды: ВСЕГДА по направлению рельс (от R к F)
	#var forward_rail = (p_f - p_r).normalized()
	#var up = (sensors.front.up_vector + sensors.rear.up_vector).normalized()
	#if up.length() < 0.1: up = Vector3.UP
	#var right = up.cross(forward_rail).normalized()
	#var actual_up = forward_rail.cross(right).normalized()
	#
	## Устанавливаем трансформацию родителя (логики)
	#global_transform.basis = Basis(right, actual_up, -forward_rail).orthonormalized()
	#
	## А ТЕПЕРЬ ВИЗУАЛ: 
	## Просто разворачиваем меш внутри, если стоит флаг
	#if mesh_node:
		#mesh_node.rotation.y = PI if visual_is_flipped else 0.0
#
func _get_curve_dir(curve: Curve3D, path: Path3D, offset: float) -> Vector3:
	var p1 = curve.sample_baked(offset)
	var step = 0.1
	var p2 = curve.sample_baked(offset + step if offset + step < curve.get_baked_length() else offset - step)
	var d = (p2 - p1).normalized()
	if offset + step >= curve.get_baked_length(): d *= -1.0
	return path.global_transform.basis * d



## ===========================================================

## Доработанная функция определения позиции и типа поверхности
func get_cursor_data() -> Dictionary:
	var camera = get_viewport().get_camera_3d()
	var mousepos = get_viewport().get_mouse_position()
	
	var from = camera.project_ray_origin(mousepos)
	var to = from + camera.project_ray_normal(mousepos) * GM.default_setting.RAY_LENGTH
	
	var worldspace = get_world_3d().direct_space_state
	var params = PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = true # Если рельсы — это Area
	params.collide_with_bodies = true
	
	var intersect = worldspace.intersect_ray(params)

	# По умолчанию считаем, что мы на земле (Y=0)
	var target_pos = Plane(Vector3.UP, 0).intersects_ray(from, to)
	var is_on_track = false
	var _collider 
	
	
	if intersect:
		# Проверяем, что попали именно в трак (по группе или имени)
		#if intersect.collider.is_in_group("tracks") or "Track" in intersect.collider.name:
		if "Ballast" in intersect.collider.name or "Head" in intersect.collider.name:
			is_on_track = true
			_collider = intersect.collider.get_parent()._atrack
			# Если нужно, можно брать высоту прямо из точки столкновения
			# target_pos = intersect.position 

	if target_pos == null: target_pos = Vector3.ZERO
		
	return {"collider": _collider, "position": target_pos, "on_track": is_on_track}
	
	
	
func _move() -> void:
	var data = get_cursor_data()
	var cursor_pos = data["position"]
	var on_track = data["on_track"]
	
	if on_track:
		var track_node = data["collider"]
		var path = track_node.path3d
		if path:
			# Запоминаем направление вагона ДО того, как он "магнитится"
			if not was_on_track:
				var ground_fwd = -global_transform.basis.z # Куда смотрели на полу
				var rail_fwd = _get_curve_dir(path.curve, path, 0.0) # Направление начала рельса
				
				# Если на полу мы смотрели против направления рельса — флипаем визуал
				visual_is_flipped = ground_fwd.dot(rail_fwd) < 0
				was_on_track = true # Фиксируем, что мы уже на рельсах
			
			# Стандартная привязка осей
			path_f = path; curve_f = path.curve
			path_r = path; curve_r = path.curve
			offset_f = curve_f.get_closest_offset(path_f.to_local(cursor_pos))
			offset_r = offset_f - wheelbase 
			
			rail_ready = true
			
			# Q/E на траке просто переключают флаг (ручная доводка)
			if Input.is_action_just_pressed("key_e") or Input.is_action_just_pressed("key_q"):
				visual_is_flipped = !visual_is_flipped
			
			_update_wagon_transform()
	else:
		# Свободное перемещение по полу
		rail_ready = false
		was_on_track = false # Сбрасываем флаг, чтобы при следующем наезде снова сработало автоопределение
		
		global_position = cursor_pos + delta_cursor
		global_position.y = 0.0
		
		# Крутим всю ноду
		if Input.is_action_pressed("key_e"): rotation_degrees.y -= 2.0
		if Input.is_action_pressed("key_q"): rotation_degrees.y += 2.0
		
		# На полу визуал всегда сброшен (т.к. крутится вся нода)
		visual_is_flipped = false 
		if mesh_node: mesh_node.rotation.y = 0

# Рабочее 
#func _move() -> void:
	#var data = get_cursor_data()
	#var cursor_pos = data["position"]
	#var on_track = data["on_track"]
	#
	#if on_track:
		#var track_node = data["collider"]
		#var path = track_node.path3d
		#if path:
			## ФИЗИКА: всегда одинаково ориентирована по треку
			#path_f = path; curve_f = path.curve
			#path_r = path; curve_r = path.curve
			#offset_f = curve_f.get_closest_offset(path_f.to_local(cursor_pos))
			#offset_r = offset_f - wheelbase 
			#
			#rail_ready = true
			#
			## УПРАВЛЕНИЕ ВИЗУАЛОМ: Q/E теперь просто переключают "лицо/зад"
			#if Input.is_action_just_pressed("key_e") or Input.is_action_just_pressed("key_q"):
				#visual_is_flipped = !visual_is_flipped
			#
			#_update_wagon_transform()
	#else:
		## На земле просто таскаем меш как коробку
		#rail_ready = false
		#global_position = cursor_pos + delta_cursor
		#global_position.y = 0.0
		#if Input.is_action_pressed("key_e"): rotation_degrees.y -= 2.0
		#if Input.is_action_pressed("key_q"): rotation_degrees.y += 2.0
		#visual_is_flipped = false			
			

## Попытка найти кривую под датчиками прямо во время перемещения
func _try_snap_sensors() -> void:
	# Force update для RayCast-ов внутри датчиков, если они выключены в процессе перемещения
	if sensors.front.curve:
		# Если датчик поймал кривую, мы можем подсветить вагон или подготовить _init_logic
		pass
		
		
	
