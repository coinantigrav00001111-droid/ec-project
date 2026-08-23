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



# ---Хелпер для связи с C_Visual---
func _update_shader_voltage(cid: int, voltage: float) -> void:
	# Ищем оба варианта материала в кэше (прямой и перевернутый)
	var key_normal = str(cid) + "_false"
	var key_flipped = str(cid) + "_true"
	
	if C_Visual.power_materials_cache.has(key_normal):
		var mat: ShaderMaterial = C_Visual.power_materials_cache[key_normal]
		# Передаем напряжение в шейдер 
		mat.set_shader_parameter("scroll_speed", voltage * 0.01) 

	if C_Visual.power_materials_cache.has(key_flipped):
		var mat_flip: ShaderMaterial = C_Visual.power_materials_cache[key_flipped]
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
			comp.contour_id = 0
			comp.is_flipped = false
			
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

	var queue: Array[Entity] = [_clip.entity]
	start_track.contour_id = _clip.contour_id
	start_track.is_flipped = false # Эталон полярности от клипа

	while queue.size() > 0:
		var current_ent = queue.pop_front()
		var current_track = current_ent.get_comp(C_PowerTrack)
		var current_sock = current_ent.get_comp(C_Socket)

		if not current_track or not current_sock: continue

		# get_connected_entities() отдает только живых соседей
		var neighbors = current_sock.get_connected_entities()

		for neighbor_ent in neighbors:
			var neighbor_track = neighbor_ent.get_comp(C_PowerTrack)
			if not neighbor_track: continue

			# Вычисляем разворот ДО проверок
			var calc_flip = _calc_flip(current_ent, neighbor_ent, current_track.is_flipped)

			if neighbor_track.contour_id == 0:
				# 🟢 1. Чистый трак: забираем в контур
				neighbor_track.contour_id = _clip.contour_id
				neighbor_track.is_flipped = calc_flip
				
				# 🟢 2. Проверка на лишние клипы по ходу сети
				var neighbor_clip = neighbor_ent.get_comp(C_PowerClip)
				if neighbor_clip and neighbor_clip != _clip:
					# Уничтожаем дубликат клипа безопасно
					neighbor_ent.call_deferred("remove_component", C_PowerClip)
				
				# 🟢 3. Добавляем в очередь
				queue.append(neighbor_ent)

			elif neighbor_track.contour_id == _clip.contour_id:
				# 🟡 Трак УЖЕ в нашем контуре (Замыкание кольца). 
				# Сверяем полярность для защиты от физического КЗ (реверсивная петля).
				if neighbor_track.is_flipped != calc_flip:
					print("⚡ АВАРИЯ (КЗ Полярности)! Цепь ", current_ent.name, " столкнулась с ", neighbor_ent.name)
					# Здесь можно вызвать PGM.emergency_stop(true)

			else:
				# 🔴 Трак принадлежит ДРУГОМУ контуру. Две разные цепи соединились!
				print("⚡ Столкновение контуров: ", _clip.contour_id, " и ", neighbor_track.contour_id)
				# Удаляем клип-агрессор, чтобы цепь слилась в одну при следующем пересчете
				var neighbor_clip = neighbor_ent.get_comp(C_PowerClip)
				if neighbor_clip:
					neighbor_ent.call_deferred("remove_component", C_PowerClip)
					
	PGM.power_tab_updated.emit()



## --- Хелпер для расчета полярности ---  Вычисляет разворот флип по питанию
func _calc_flip(current_entity: Entity, neighbor_entity: Entity, current_flip: bool) -> bool:
	var sock_comp1 = current_entity.get_comp(C_Socket)
	var sock_comp2 = neighbor_entity.get_comp(C_Socket)
	
	# Достаем C_Path, чтобы получить доступ к нодам путей
	var path_comp1 = current_entity.get_comp(C_Path)
	var path_comp2 = neighbor_entity.get_comp(C_Path)
	
	if not sock_comp1 or not sock_comp2 or not path_comp1 or not path_comp2:
		return current_flip 
		
	var min_dist = INF
	var id1 = 0
	var id2 = 0
	
	# 1. Ищем точку стыковки через точные глобальные координаты Path3D
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
				
	# 2. Логика полярности
	var is_start1 = (id1 == 0)
	var is_start2 = (id2 == 0)
	
	# print("Стык %s[%s] <-> %s[%s] | Было: %s" % [current_entity.name, id1, neighbor_entity.name, id2, current_flip])
	
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


#region Пока оставим, потом удалить

# алгоритм BFS (поиск в ширину). копия. Держим на всякий.
func _build_contour_from_clip0(_clip: C_PowerClip) -> void:
	# 0. Базовые проверки
	if not _clip.entity or _clip.contour_id == 0: return
	
	# 1. Получаем сущность, на которой висит этот клип
	var start_entity = _clip.entity
	var target_contour = _clip.contour_id
	
	# 2. Инициализируем очередь и словарь посещенных нод (защита от замкнутых колец)
	var queue: Array[Entity] = []
	var visited: Dictionary = {}
	
	# Помещаем стартовый трак в очередь
	queue.append(start_entity)
	visited[start_entity] = true

	# 3. Запускаем обход графа
	while queue.size() > 0:
		var current_entity = queue.pop_front()

		# Раздаем питание текущему извлеченному траку
		var track_comp = current_entity.get_comp(C_PowerTrack)
		if track_comp:
			track_comp.contour_id = target_contour
			## 🚧 Дергаем C_Visual, чтобы он применил цвет контура
			current_entity.send_event("on_power_view_changed", {"active": is_power_layer_active})
			
		# 4. Ищем соседей и планируем их обработку
		var socket_comp = current_entity.get_comp(C_Socket)

		if socket_comp:
			await get_tree().physics_frame

			var neighbors = socket_comp.get_connected_entities()
			
			for neighbor in neighbors:
				var neighbor_power = neighbor.get_comp(C_PowerTrack)
				# Пропускаем, если у соседа нет способности проводить ток
				if not neighbor.has_comp(C_PowerTrack):
					continue
					
				# Защита от Короткого Замыкания и повторного прохода
				if neighbor_power.contour_id != 0:
					if neighbor_power.contour_id != _clip.contour_id:
						
						# Вычисляем кого тащат.
						var _cdrag = current_entity.has_comp(C_Drag)
						var _ndrag = neighbor.has_comp(C_Drag)
											
						var _remove_clip = current_entity if _cdrag else neighbor 
						
						print("⚡ АВАРИЯ (КЗ)! Цепь ", current_entity.name, ' ', _cdrag, " столкнулась с цепью ", neighbor.name, ' ', _ndrag)
						
						_remove_clip.remove_component(C_PowerClip)
						
					
						# Трак уже под питанием другой цепи. Дальше ток не пускаем.
						# Опционально: можно здесь кидать alert в UI
					continue # Трак уже обработан, пропускаем
					
				# Если мы у этого соседа еще не были — добавляем в очередь
				if not visited.has(neighbor):
					visited[neighbor] = true # Сразу помечаем, чтобы не добавить дважды
					queue.append(neighbor)
					
				#✳️ Случай А: Мы заряжены. Сосед пустой 
				if track_comp.contour_id != 0 and neighbor_power.contour_id == 0:
					neighbor_power.contour_id = track_comp.contour_id
					
					# 💡 ВСТАВИТЬ ТОЛЬКО ЭТИ ДВЕ СТРОКИ:
					var calculated_flip = _calc_flip(current_entity,  neighbor, track_comp.is_flipped)
					#printt('Случай А')
					neighbor_power.is_flipped = calculated_flip
					
					# Заставляем визуал соседа обновиться, используя глобальный флаг видимости слоя 
					neighbor.send_event("on_power_view_changed", {"active": PGM.is_power_layer_active}) 
					
				# ✳️ Случай Б: Сосед заряжен. Мы пустые
				elif neighbor_power.contour_id!= 0 and track_comp.contour_id== 0:
					track_comp.contour_id = neighbor_power.contour_id
					printt('Случай Б')
					# 💡 ВСТАВИТЬ ТОЛЬКО ЭТИ ДВЕ СТРОКИ:
					var calculated_flip = _calc_flip(current_entity,  neighbor, track_comp.is_flipped)
					track_comp.is_flipped = calculated_flip
			
					current_entity.send_event("on_power_view_changed", {"active": PGM.is_power_layer_active}) 
					
	PGM.power_tab_updated.emit()
#endregion end
