extends Node
# class_name PowerGridManager название класса отменяем, так как синглтон
###########################
##💡 PowerGridManager - Системный сервис(autoload), контроль енергосети
############################
##
## Хранит массив состояний всех доступных цепей
##
## Пульт (UI Panel или 3D Entity): Выступает просто устройством ввода. Когда игрок дергает ручку, пульт лишь передает команду в PowerGridManager: "Обнови target_voltage в цепи №2 на 60".


## -OLD-
## Принимает питание DCController и  занимается дальнейшей его обработкой
## 
## Подключает распределяет питание по тракам
## Подача питания осуществл. через поверклип компонент, который можно подключить на некоторые типы траков.

## 
## Было. --Группа-- модуль номера клипа. Используется для быстрого доступа ко всем тракам группы, а значит контура
## 
## power_pwm - Словарь, в котором есть все контуры и питание на них

## Ссылка на узел дерева, где лежат все рельсы
@onready var world_entities_root = "/root/GameRoot/World/EntitiesRoot"

# Максимальное количество контуров в сети
const MAX_CONTOURS = 10

## текущее питание в цепи ключ - contour_id, значение - словарь:
##power_pwm {"voltage": 0, "is_stopped": false}

## pwm - принцип ШИМ 
## словарь контуров заполняется нулями на старте
var power_pwm : Dictionary = {}

## Для сохранения состояния контуров при выключении контроллера
var power_memory : Dictionary = {}

## Список всех активных клипов на столе
var active_clips: Array[C_PowerClip] = []


## ⚡Сигналы
signal contoir_updated(contour_id: int, new_voltage: float)
signal grid_recalculated() # ⚡Сигнал для UI или визуала, что топология изменилась


func _ready() -> void:
	# Преаллокация при старте игры
	for i in range(1, MAX_CONTOURS + 1):
		power_pwm[i] = {
			"voltage": 0, 
			"is_stopped": false # Для аварийного тормоза
		}



func _process(_delta: float) -> void:
	#var labeltest: Label = $"/root/GameRoot/UI/Labeltest"
	#if power_pwm[1].voltage !=null:
		#labeltest.text = str(active_clips) + '\n'+ str(power_pwm)
	pass


# --- ИНТЕРФЕЙС ДЛЯ ПУЛЬТА (UI или 3D Entity) ---

##  обработка сигнала change_power_pwm из ui-контроллера(пока) питания
## _new_power - новое значение power, _contour - контур питания
## передача питания во все в контуры, если _contour == -1 
## передача питания в никуда, если _contour == 0 

func set_power_pwm( _contour_id: int = 0, _voltage :int = 0) -> void: 
	# Для групп
	#var _name_contour : String = 'contour_' + str(abs(_contour_id))

	if _contour_id == -1: # передача питания во все в контуры
		for i in power_pwm:
			power_pwm[i]["voltage"] = _voltage
		for ac in range(0, active_clips.size()):
				active_clips[ac].set_power(active_clips[ac].contour_id, _voltage)
			# Для групп
			#_name_contour  = 'contour_' + str(abs(_p))
			#get_tree().call_group(_name_contour, 'on_change_power_track', power_pwm[_p]) 

	elif _contour_id != 0: # если указан номер != 0 
		if power_pwm.has(_contour_id):
			power_pwm[_contour_id]["voltage"] = _voltage
			
			for ac in active_clips:
				if ac.contour_id == _contour_id:
					ac.set_power(_contour_id, _voltage)
					break
			#для групп
			#get_tree().call_group(_name_contour, 'on_change_power_track', _voltage)
			
	else: # == 0 не передает никуда(нейтралка)
		pass

	# ⚡Сигнал для реактивного UI (чтобы другие панели обновились)
	contoir_updated.emit(_contour_id, _voltage)
	#TODO Запускаем обновление физических рельсов (если они есть)
	#_apply_voltage_to_physical_contours(_contour_id)



func get_voltage(_contour_id: int) -> float:
	if power_pwm.has(_contour_id) and not power_pwm[_contour_id]["is_stopped"]:
		return power_pwm[_contour_id]["voltage"]
	return 0.0



# ⚡Сигнал выключения питания
func emergency_stop(_stop : bool) -> void:
	for i in power_pwm.keys():
		power_pwm[i]["is_stopped"] = _stop
		# Передача напряжения в UI
		var _emit_voltage = 0.0 if _stop else power_pwm[i]['voltage']
		contoir_updated.emit(i, _emit_voltage)



# --- ИНТЕРФЕЙС ДЛЯ ТОПОЛОГИИ (Вызывается из C_PowerClip ) ---

func register_clip(_clip):

	if not active_clips.has(_clip):
		active_clips.append(_clip)
		recalculate_grid()

func unregister_clip(_clip):
	if active_clips.has(_clip):
		active_clips.erase(_clip)
		recalculate_grid()
	
	
	
# Возвращает список ID контуров, которые СЕЙЧАС заняты другими объектами
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



# Пересчет всей цепи
func recalculate_grid() -> void:
	## 1. Сбрасываем всем C_PowerTrack в мире contour_id в 0
	_reset_all_tracks()
	
	# 2. Запускаем обход графа от каждого активного клипа
	for clip in active_clips:
		_build_contour_from_clip(clip)
		
	grid_recalculated.emit()
	pass


func _reset_all_tracks() -> void:
	# Получаем список всех сущностей с C_PowerTrack
	var all_tracks = get_tree().get_nodes_in_group("power_track")
	for track_entity in all_tracks:
		var comp = track_entity.get_comp(C_PowerTrack)
		if comp:
			comp.contour_id = 0
			comp.is_flipped = false


var s = 0
func _build_contour_from_clip(_clip: C_PowerClip) -> void:
	s+= 1
	# Здесь будет алгоритм BFS (поиск в ширину).
	# Он будет читать C_Socket сущности клипа, находить соседей,
	# и прописывать им clip.circuit_index в их C_PowerTrack.
	printt(' алгоритм BFS из', _clip.name, s )


#------ POWER LAYER ------

# ⚡Сигнал о включении визуального повер-слоя
signal power_layer_toggled(is_active: bool)

# Флаг включения визуального повер-слоя
var is_power_layer_active: bool = false


func toggle_power_layer(state: bool):
	is_power_layer_active = state
	power_layer_toggled.emit(state)

	# Собираем все сущности на столе
	var root_node = get_node_or_null(world_entities_root)
	if root_node:
		# проход по всем ентити 
		for _entity in root_node.get_children():
			if _entity is Entity:
				_entity.send_event("on_power_view_changed", {"active": state})
