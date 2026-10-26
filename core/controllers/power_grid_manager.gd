extends Node
# class_name PowerGridManager название класса отменяем, так как теперь это синглтон PGM
###########################
##💡 PGM - Системный сервис(autoload), контроль енергосети
############################
##
## Хранит массив состояний всех доступных цепей
##
## Пульт (UI Panel или 3D Entity): Выступает просто устройством ввода. Когда игрок дергает ручку, пульт лишь передает команду в PGM: "Обнови target_voltage в цепи №2 на 60".
## 
## Подключает распределяет питание по тракам
## Подача питания  в цепь осуществляет поверклип компонент, который можно подключить на некоторые типы траков.
## 
## power_pwm - Словарь, в котором есть все контуры и питание на них, и останов
@onready var dc_controller: Panel #= $"/root/GameRoot/UI/DCControlPanel" #$"/root/GameRoot/Gimbal"
# Максимальное количество контуров в сети. Не связано с DCC контроллером, там отдельно регулировать слайдер
const MAX_CONTOURS = 10

# pwm - принцип ШИМ. словарь контуров заполняется нулями на старте
# текущее питание в цепи ключ - contour_id, значение - словарь:
#power_pwm {"voltage": 0, "is_stopped": false}
var power_pwm : Dictionary = {}

# Для сохранения состояния контуров при выключении контроллера
var power_memory : Dictionary = {}

# Список всех активных КЛИПОВ на столе
var active_clips: Array[C_PowerClip] = []

# Флаг включения визуального повер-слоя
var is_power_layer_active: bool = false

# флаг ожидания пересчета сети 
var _recalc_pending: bool = false 

## ⚡Сигналы
# ⚡Сигнал о включении визуального повер-слоя на столе
signal power_layer_toggled(is_active: bool)

# ⚡Сигналы в UI
@warning_ignore("unused_signal")
signal power_tab_updated()  # вся панель обновляется  
signal power_updated(contour_id: int, new_voltage: float) # Обновл. данные трака по ручке



func _ready() -> void:
	# Преаллокация при старте игры
	for i in range(1, MAX_CONTOURS + 1):
		power_pwm[i] = {
			"voltage": 0, 
			"is_stopped": false # Для аварийного тормоза
		}



func _process(_delta: float) -> void:
	#var labeltest: Label = $"/root/GameRoot/UI/Labeltest"
	#labeltest.text = 'Act cl: '+str(active_clips) + 
	#labeltest.text = '\n PowerPwm: '+ str(power_pwm)
	#labeltest.text = str(dc_controller)
	pass


# --- ИНТЕРФЕЙС ДЛЯ ПУЛЬТА (UI или 3D Entity) ---

# передача питания во все в контуры, если _contour == -1 
# передача питания в никуда, если _contour == 0 
func set_power_pwm( _cid: int = 0, _voltage :int = 0) -> void: 
	if _cid == 0: 
		return # Нейтралка

	if _cid == -1: # передача питания во все в контуры
		# 1. Записываем в память сети и обновляем шейдеры по ключам контуров
		for cid in power_pwm.keys():
			power_pwm[cid]["voltage"] = _voltage
			#обновляем визуал (анимацию шейдера) для этого контура
			_update_shader_voltage(cid, _voltage) # Используем реальный ID контура!
		
		# 2. Обновляем данные во всех клипах на столе
		for clip in active_clips:
			#print(clip )
			clip.set_power(clip.contour_id, _voltage)

	elif _cid != 0: # если указан номер != 0 
		# 1. Записываем в память сети
		if power_pwm.has(_cid):
			power_pwm[_cid]["voltage"] = _voltage
	
			# 2. Записываем вольтаж в клип
			for clip in active_clips:
				if clip.contour_id == _cid:
					clip.set_power(_cid, _voltage)
					# break если в будущем вешать 2 клипа на 1 контур, то брек не нужен
			
		# 3. ИЗ КЕША Visual МГНОВЕННО обновляем визуал (анимацию шейдера) для этого контура
		_update_shader_voltage(_cid, _voltage)

	# ⚡Сигнал для UI 
	power_updated.emit(_cid, _voltage)



func get_power(_cid: int) -> float:
	if power_pwm.has(_cid) and not power_pwm[_cid]["is_stopped"]:
		return power_pwm[_cid]["voltage"]
	return 0.0



# ---Хелпер для связи с C_TrackVisual---
func _update_shader_voltage(cid: int, voltage: float) -> void:
	# Ищем оба варианта материала в кэше (прямой и перевернутый)
	var key_normal = str(cid) + "_false"
	var key_flipped = str(cid) + "_true"
	
	if C_TrackVisual.power_materials_cache.has(key_normal):
		var mat: ShaderMaterial = C_TrackVisual.power_materials_cache[key_normal]
		# Передаем напряжение в шейдер 
		mat.set_shader_parameter("scroll_speed", voltage * 0.01) 

	if C_TrackVisual.power_materials_cache.has(key_flipped):
		var mat_flip: ShaderMaterial = C_TrackVisual.power_materials_cache[key_flipped]
		# Для перевернутых траков инвертируем скорость/направление
		mat_flip.set_shader_parameter("scroll_speed", -voltage * 0.01)



# ⚡Сигнал выключения питания
func emergency_stop(_stop : bool) -> void:
	for cid in power_pwm.keys():
		power_pwm[cid]["is_stopped"] = _stop
		
		# 1. Высчитываем эффективное напряжение для отображения
		var _effective_voltage = 0.0 if _stop else power_pwm[cid]['voltage']
		
		# 2. Передача напряжения в UI панели
		power_updated.emit(cid, _effective_voltage)
		
		# 3. Обновляем метки (Label3D) на физических клипах на столе
		for clip in active_clips:
			if clip.contour_id == cid:
				clip.set_power(cid, _effective_voltage)
				
		# 4. Останавливаем (или запускаем) анимацию шейдеров тока на рельсах
		if has_method("_update_shader_voltage"):
			_update_shader_voltage(cid, _effective_voltage)



# Создает клип на траке по кнопке инфопанели
func create_power_clip(_entity: Entity, _cid: int, _pressed: bool) -> int:
	
	# Проверяем: если контур равен 0 (игрок не выбрал конкретный канал)
	if _cid == 0:
		_cid = get_free_contour_id()
	
	#💡 нажата 
	if  _pressed: 
		# Вешаем C_PowerClip 
		var power_clip = C_PowerClip.new()

		#power_clip.contour_id = target_contour # set_power сделает 
		_entity.add_component(power_clip)
		
		# Задает электрику в клип из пгм
		power_clip.set_power(_cid, PGM.power_pwm[_cid].voltage) 
		
		# Вешаем на трак контур
		_entity.get_comp(C_PowerTrack).contour_id = _cid

	else : # отжата 
		_entity.remove_component(C_PowerClip)
		# Снимаем контур с трака
		_entity.get_comp(C_PowerTrack).contour_id = 0

	return _cid


# --- ИНТЕРФЕЙС ДЛЯ ТОПОЛОГИИ (Вызывается из C_PowerClip ) ---
# Регистрация клипов в сети
func register_clip(_clip):
	if not active_clips.has(_clip):
		active_clips.append(_clip)
		request_recalculate() # запрос пересчета



func unregister_clip(_clip):
	if active_clips.has(_clip):
		active_clips.erase(_clip)
		request_recalculate() # запрос пересчета



# Возвращает список ID контуров, которые СЕЙЧАС заняты
func get_occupied_contours() -> Array[int]:
	var occupied: Array[int] = []
	for clip in active_clips:
		if is_instance_valid(clip) and clip.contour_id > 0:
			if not clip.contour_id in occupied:
				occupied.append(clip.contour_id)
	return occupied



## Возвращает первый свободный ID контура в диапазоне от 1 до MAX_CONTOURS.
## Если все контуры заняты, возвращает 0.
func get_free_contour_id() -> int:
	var occupied = get_occupied_contours()
	for id in range(1, MAX_CONTOURS + 1):
		if not id in occupied:
			return id
	return 0



# буферный метод, который ждет, пока физика Godot уложит все рельсы на места.
func request_recalculate() -> void:
	if _recalc_pending: return # если ожидание вкл - выход
	_recalc_pending = true
	# Ждем 2 кадра физики, чтобы двойные угловые снапы и Area3D успели обновить overlap
	await get_tree().physics_frame
	await get_tree().physics_frame 
	
	recalculate_grid()
	_recalc_pending = false
	#await get_tree().physics_frame 


# Пересчет всей сети
func recalculate_grid() -> void:
	_reset_all_tracks()
	# ⚡ ВАЖНО: Создаем копию массива для безопасной итерации
	var clips_copy = active_clips.duplicate() 
	for clip in clips_copy:
		if is_instance_valid(clip):
			_build_contour_from_clip(clip)



func _reset_all_tracks() -> void:
	# Получаем список всех сущностей с C_PowerTrack
	var all_tracks = get_tree().get_nodes_in_group("power_track")
	for track_entity in all_tracks:
		var comp = track_entity.get_comp(C_PowerTrack)
		if comp:
			comp.reset()   # XX claude-switch: все лучи (у кросса с раздельными цепями их два)
			
			# 🚧 Гасим визуал перед новым пересчетом
			track_entity.send_event("on_power_view_changed", {"active": is_power_layer_active})
						



# ================================
# алгоритм BFS (поиск в ширину).
# Запускается при пересчете всей цепи в recalculate_grid()
func _build_contour_from_clip(_clip: C_PowerClip) -> void:
	# Базовые проверки
	if not is_instance_valid(_clip) or not is_instance_valid(_clip.entity): return
	if _clip.contour_id == 0: return

	var start_track = _clip.entity.get_comp(C_PowerTrack)
	if not start_track: return

	# 🛡️ Защита старта: Если стартовый трак УЖЕ запитан другим клипом (на этой же сети),
	# этот клип лишний. Сносим его и прерываем обход.
	if start_track.contour_id != 0 and start_track.contour_id != _clip.contour_id:
		# call_deferred спасает от краша и сбоев итерации [cite: 30]
		_clip.entity.call_deferred("remove_component", C_PowerClip)
		return

	# XX claude-switch: узел обхода = (сущность, луч питания). У обычных траков и стрелок луч всегда 0, обход как раньше.
	# У кросса с раздельными цепями два луча: контур идет только по своему пути, на соседний путь не переходит
	var queue: Array[Dictionary] = [{"e": _clip.entity, "leg": 0}]
	start_track.set_leg(0, _clip.contour_id, false)   # Эталон полярности от клипа

	while queue.size() > 0:
		var node: Dictionary = queue.pop_front()
		var current_ent: Entity = node.e
		var cur_leg: int = node.leg
		var current_track = current_ent.get_comp(C_PowerTrack)
		var current_sock = current_ent.get_comp(C_Socket)

		if not current_track or not current_sock: continue

		# get_connected_entities() отдает только живых соседей
		var neighbors = current_sock.get_connected_entities()

		for neighbor_ent in neighbors:
			var neighbor_track = neighbor_ent.get_comp(C_PowerTrack)
			if not neighbor_track: continue

			# Стык: какие сокеты соприкасаются. От них зависят лучи и полярность
			var joint := _find_joint(current_ent, neighbor_ent)
			var n_leg := 0
			if not joint.is_empty():
				if current_sock.leg_of_socket(joint.id1) != cur_leg:
					continue   # этот стык принадлежит другому лучу сущности (другому пути кросса)
				var n_sock = neighbor_ent.get_comp(C_Socket)
				# E1 (power routing): мертвый сокет стрелки не проводит ток ни наружу, ни внутрь
				if not current_sock.is_socket_live(joint.id1):
					continue
				if n_sock and not n_sock.is_socket_live(joint.id2):
					continue
				n_leg = n_sock.leg_of_socket(joint.id2) if n_sock else 0

			# Вычисляем разворот ДО проверок
			var calc_flip = _flip_at(current_ent, neighbor_ent, joint, current_track.flip_of(cur_leg))
			var n_cid: int = neighbor_track.contour_of(n_leg)

			if n_cid == 0:
				# 🟢 1. Чистый трак: забираем в контур
				neighbor_track.set_leg(n_leg, _clip.contour_id, calc_flip)
				
				# 🟢 2. Проверка на лишние клипы по ходу сети (клип стоит на луче 0)
				var neighbor_clip = neighbor_ent.get_comp(C_PowerClip)
				if neighbor_clip and neighbor_clip != _clip and n_leg == 0:
					# Уничтожаем дубликат клипа безопасно
					neighbor_ent.call_deferred("remove_component", C_PowerClip)
				
				# 🟢 3. Добавляем в очередь
				queue.append({"e": neighbor_ent, "leg": n_leg})

			elif n_cid == _clip.contour_id:
				# 🟡 Трак УЖЕ в нашем контуре (Замыкание кольца). 
				# Сверяем полярность для защиты от физического КЗ (реверсивная петля).
				if neighbor_track.flip_of(n_leg) != calc_flip:
					print("⚡ АВАРИЯ (КЗ Полярности)! Цепь ", current_ent.name, " столкнулась с ", neighbor_ent.name)
					# Здесь можно вызвать PGM.emergency_stop(true)

			else:
				# 🔴 Трак принадлежит ДРУГОМУ контуру. Две разные цепи соединились!
				print("⚡ Столкновение контуров: ", _clip.contour_id, " и ", n_cid)
				# Удаляем клип-агрессор, чтобы цепь слилась в одну при следующем пересчете
				var neighbor_clip = neighbor_ent.get_comp(C_PowerClip)
				if neighbor_clip and n_leg == 0:
					neighbor_ent.call_deferred("remove_component", C_PowerClip)
					
	PGM.power_tab_updated.emit()



## --- Хелпер для расчета полярности ---  Вычисляет разворот флип по питанию
func _calc_flip(current_entity: Entity, neighbor_entity: Entity, current_flip: bool) -> bool:
	return _flip_at(current_entity, neighbor_entity, _find_joint(current_entity, neighbor_entity), current_flip)


## XX claude-switch. Стык двух сущностей: индексы ближайших друг к другу сокетов {id1, id2}.
## Пусто, если у кого-то нет сокетов или пути
func _find_joint(current_entity: Entity, neighbor_entity: Entity) -> Dictionary:
	var sock_comp1 = current_entity.get_comp(C_Socket)
	var sock_comp2 = neighbor_entity.get_comp(C_Socket)
	
	# Достаем C_Path, чтобы получить доступ к нодам путей
	var path_comp1 = current_entity.get_comp(C_Path)
	var path_comp2 = neighbor_entity.get_comp(C_Path)
	
	if not sock_comp1 or not sock_comp2 or not path_comp1 or not path_comp2:
		return {}
		
	var min_dist = INF
	var id1 = 0
	var id2 = 0
	
	# Ищем точку стыковки через точные глобальные координаты Path3D
	for i in range(sock_comp1.sockets.size()):
		# ВАЖНО: Используем path_node.to_global вместо current_entity.to_global
		var p1 = path_comp1.path_node.to_global(sock_comp1.sockets[i].pos)
		
		for j in range(sock_comp2.sockets.size()):
			var p2 = path_comp2.path_node.to_global(sock_comp2.sockets[j].pos)
			var dist = p1.distance_squared_to(p2) 
			
			if dist < min_dist:
				min_dist = dist
				id1 = i
				id2 = j
	return {"id1": id1, "id2": id2}


## Логика полярности по стыку (см. _find_joint). Без стыка полярность сохраняется
func _flip_at(current_entity: Entity, neighbor_entity: Entity, joint: Dictionary, current_flip: bool) -> bool:
	if joint.is_empty():
		return current_flip
	var sock_comp1 = current_entity.get_comp(C_Socket)
	var sock_comp2 = neighbor_entity.get_comp(C_Socket)
	var id1: int = joint.id1
	var id2: int = joint.id2

	var is_start1 = (id1 == 0)
	var is_start2 = (id2 == 0)
	# XX claude-switch: начало маршрута берем из флага сокета (у кросса два начала). Без флага как раньше
	if id1 < sock_comp1.sockets.size():
		is_start1 = bool(sock_comp1.sockets[id1].get("start", id1 == 0))
	if id2 < sock_comp2.sockets.size():
		is_start2 = bool(sock_comp2.sockets[id2].get("start", id2 == 0))
	
	if is_start1 and is_start2:
		# Начало к Началу
		return not current_flip
	elif not is_start1 and not is_start2:
		# Конец к Концу (Теперь железно отработает как надо)
		return not current_flip
	else:
		# Начало к Концу
		return current_flip



# Срабатывает при переключении слоя электрики в топ панели
func toggle_power_layer(state: bool):
	is_power_layer_active = state
	power_layer_toggled.emit(state)
	# Получаем список всех сущностей с C_PowerTrack
	var all_tracks = get_tree().get_nodes_in_group("power_track")
	for track_entity in all_tracks:
		track_entity.send_event("on_power_view_changed", {"active": state})
