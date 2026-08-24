class_name C_Path extends ICapability

####################
## Способность, Библиотека действий. Она живет на объекте всегда.
####################
## Описывает физическое свойство объекта («у меня есть Path3d» «у меня есть Ballast»),
## содержит внутри себя логику расчета 
##
## Path3d генерится в ентити
## 
## Коллизия Балласт в слое 4 по умолчанию
## Коллизии Балласта генерятся, если в сцене есть нода балласт и у нее нет коллизий,
## иначе используется коллизия сцены или игнорируется создание балласта вовсе - нет в 
## сцене - нет в объекте.

# Радиус и угол заполняются в редакторе в pat_setting при создании ентити 
var radius: float 
var deg: float 

var path_node: Path3D
var curve: Curve3D
var ballast_node: Area3D

# TODO Ноды рельсов надо сделать как балласт
var headl_node: StaticBody3D
var headr_node: StaticBody3D

var pivot_offset := Vector3.ZERO 

# Ballast

#var b_gap := 0.0 # зазор между сегментами.
var b_start_end_padding: float = -0.1	#  минус - внутрь трака, плюс =0 .


func on_added():
	pass

func on_entity_ready() -> void:
	var identity = get_comp(C_Identity)
	if not identity or not identity.setting:
		return
	
	var pivot = get_comp(C_Pivot)
	if pivot: pivot_offset = pivot.offset
	
	# Генерируем математически точную кривую
	curve = generate_track_curve(radius, deg)
	
	# Синхронизируем её с визуальной нодой Path3D, если она есть в сцене
	path_node = _generate_path()
	
	# Синхронизируем коллизии балласта с нодой Ballast, если она есть в сцене
	_sync_with_visual_ballast()
	
	# Синхронизируем коллизии рельсов с нодами сцены
	_sync_with_visual_heads()


# Генерируем ноду Path3D и новый оффсет в C_Pivot 
func _generate_path() -> Path3D:

	var _path_n = Path3D.new()
	entity.add_child(_path_n)
	_path_n.name = 'Path3d_generated'
	
	_path_n.curve = curve
	var curve_length = _path_n.curve.get_baked_length()

	# Середина кривой
	var _new_offset = - _path_n.curve.sample_baked_with_rotation(curve_length/2).origin
	
	# И пересчет offset по новой кривой
	_path_n.position = _new_offset
	entity.send_event('on_offset_changed', {"new_offset": _new_offset}) # В C_Pivot
	pivot_offset = _new_offset

	return _path_n



## Синхронизируем ноду "Ballast" с нодой сцены внутри C_Visual
func _sync_with_visual_ballast():
	var visual = get_comp(C_Visual)
	if not visual or not visual.instance: return

	# Находим ноду балласта 
	ballast_node = _find_ballast_recursive(visual.instance)
	
	# Проверка сцены. Eсли в ней балласта нет, то значит он не нужен, выходим
	if not ballast_node: return 

	#Если коллизия есть, то она сделана в сцене специально для оптимизации (прямая состоит из одного сегмента например) или намеренно - оставляем.
	# Расчет балласта. Если у балласта нет коллизий, то будем генерить.
	var gs_ballast = Global.settings.track_ballast_segment
	if ballast_node.get_child_count() == 0: 
		generate_ballast_collisions(gs_ballast.count,gs_ballast.size, gs_ballast.padding, gs_ballast.gap)
	
	
	#INFO цвет коллизий для дебага
	var _debug_color=Color("00b929ff")
	var collision_shapes =  ballast_node.get_children()
	for seg in collision_shapes:
		seg.set_debug_color(_debug_color)



## Синхронизируем ноды "Head_L Head_R" с нодами сцены внутри C_Visual
func _sync_with_visual_heads():
	var visual = get_comp(C_Visual)
	if not visual or not visual.instance: return

	# Находим ноды рельсов
	# TODO организовать поиск рельсов как балласта. Или в одну функцию запихнуть
	headl_node = visual.instance.get_node('HeadL')
	headr_node = visual.instance.get_node('HeadR')
	# Проверка сцены. Eсли в ней рельсов, то значит он не нужен, выходим
	#if not headl_node or not headr_node: return 

	#Если коллизия есть, то она сделана в сцене специально для оптимизации (прямая состоит из одного сегмента например) или намеренно - оставляем.
	# Расчет балласта. Если нет коллизий, то будем генерить.
	var gs_head = Global.settings.track_head_segment
	if not headl_node or headl_node.get_child_count() == 0: 
		generate_head_collisions(headl_node, gs_head.count, gs_head.size, gs_head.padding, gs_head.gap, gs_head.offset)
	if not headr_node or headr_node.get_child_count() == 0: 
		generate_head_collisions(headr_node, gs_head.count, gs_head.size, gs_head.padding, gs_head.gap, gs_head.offset)
	
	#INFO цвет коллизий для дебага
	var _debug_color=Color("c40070ff")
	var collision_shapes =  headl_node.get_children()
	for seg in collision_shapes:
		seg.set_debug_color(_debug_color)
	collision_shapes =  headr_node.get_children()
	for seg in collision_shapes:
		seg.set_debug_color(_debug_color)
	
		


## Процедурный генератор кривой с идеальными касательными на торцах
func generate_track_curve(_radius: float, _deg: float) -> Curve3D:
	var new_curve = Curve3D.new()
	
	if abs(deg) < 0.01:
		# --- ЧАСТНЫЙ СЛУЧАЙ: ПРЯМОЙ ТРАК ---
		# Первая точка в нуле, вторая уходит по оси -Z на расстояние radius (длину)
		# Ручки строго нулевые, так как это идеальная прямая
		new_curve.add_point(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
		new_curve.add_point(Vector3(0, 0, -radius), Vector3.ZERO, Vector3.ZERO)
		
	else:
		# --- РАДИУСНЫЙ ТРАК (ДУГА ОКРУЖНОСТИ) ---
		var alpha = deg_to_rad(abs(deg))
		var dir_sign = sign(deg)
		if dir_sign == 0: dir_sign = 1.0 # Предохранитель
		
		# Идеальная длина управляющих векторов Безье для дуги окружности
		var L = (4.0 / 3.0) * tan(alpha / 4.0) * radius
		
		# 1. СТАРТОВАЯ ТОЧКА (всегда в нуле, направлена строго вперед по -Z)
		var start_pos = Vector3.ZERO
		var start_in = Vector3.ZERO
		var start_out = Vector3(0, 0, -L) # Смотрит вперед, обеспечивая идеальный торец
		new_curve.add_point(start_pos, start_in, start_out)
		
		# 2. КОНЕЧНАЯ ТОЧКА (вычисляется через тригонометрию дуги)
		# Если dir_sign = 1 (вправо), координата X положительная. Если -1 (влево) — отрицательная.
		var end_pos = Vector3(
			dir_sign * radius * (1.0 - cos(alpha)), 
			0, 
			-radius * sin(alpha)
			)
		
		# Ручка "внутрь" (end_in) должна быть направлена строго назад по касательной к окружности
		var end_in = Vector3(-dir_sign * sin(alpha), 0, cos(alpha)) * L
		var end_out = Vector3.ZERO
		new_curve.add_point(end_pos, end_in, end_out)
		
	return new_curve



# Генерация сегментов коллизии балласта
func generate_ballast_collisions(count: int, cross_size: Vector2, start_end_padding: float = 0.0, gap: float = 0.0) -> void:
	
	if not curve or curve.get_baked_length() == 0 or count < 1:
		push_warning("C_Path: Кривая не инициализирована или count < 1.")
		return

	var total_length = curve.get_baked_length()
	
	# Вычисляем дистанции (минус padding сдвигает старт в плюс, т.е. внутрь)
	var start_distance = -start_end_padding
	var end_distance = total_length + start_end_padding
	var usable_length = end_distance - start_distance
	
	# Вычисляем размер одного сегмента по оси Z
	var total_gap = gap * (count - 1)
	var z_size = (usable_length - total_gap) / float(count)
	var box_size = Vector3(cross_size.x, cross_size.y, z_size)
	
	for i in range(count):
		# t от 0.0 (первый сегмент) до 1.0 (последний)
		var t = float(i) / (count - 1) if count > 1 else 0.5
		
		# Дистанция выборки на кривой
		var d = lerp(start_distance, end_distance, t)
		
		# Встроенная защита: Godot автоматически зажмет d в пределах [0, total_length],
		# поэтому даже если padding плюсовой (наружу), мы возьмем правильный крайний тангенс.
		var segment_transform = curve.sample_baked_with_rotation(d)
		
		# Магия выравнивания:
		# На t=0 мы сдвигаем бокс вперед (-Z в Godot) на z_size/2, чтобы его край совпал со стартом.
		# На t=1 мы сдвигаем бокс назад (+Z) на z_size/2, чтобы его край совпал с финишем.
		var z_shift = lerp(-z_size / 2.0, z_size / 2.0, t)
		segment_transform = segment_transform.translated_local(Vector3(0.0, Global.settings.track_ballast_segment.size.y/2, z_shift))
		
		var collision_shape = CollisionShape3D.new()
		collision_shape.name = "BallastShape_%d" % i
		
		var box_shape = BoxShape3D.new()
		box_shape.size = box_size
	
		collision_shape.shape = box_shape
		collision_shape.transform = segment_transform
		
		ballast_node.add_child(collision_shape)


# Генерация сегментов коллизии балласта
func generate_head_collisions(owner_node : Node3D, count: int, cross_size: Vector2, start_end_padding: float = 0.0, gap: float = 0.0, offset = 0.865) -> void:
	
	if not curve or curve.get_baked_length() == 0 or count < 1:
		push_warning("C_Path: Кривая не инициализирована или count < 1.")
		return

	var total_length = curve.get_baked_length()
	# Вычисляем дистанции (минус padding сдвигает старт в плюс, т.е. внутрь)
	var start_distance = -start_end_padding
	var end_distance = total_length + start_end_padding
	var usable_length = end_distance - start_distance
	
	# Вычисляем размер одного сегмента по оси Z
	var total_gap = gap * (count - 1)
	var z_size = (usable_length - total_gap) / float(count)
	var box_size = Vector3(cross_size.x, cross_size.y, z_size)
	
	for i in range(count):
		# t от 0.0 (первый сегмент) до 1.0 (последний)
		var t = float(i) / (count - 1) if count > 1 else 0.5
		
		# Дистанция выборки на кривой
		var d = lerp(start_distance, end_distance, t)
		
		# Встроенная защита: Godot автоматически зажмет d в пределах [0, total_length],
		# поэтому даже если padding плюсовой (наружу), мы возьмем правильный крайний тангенс.
		var segment_transform = curve.sample_baked_with_rotation(d)
		
		# Магия выравнивания:
		# На t=0 мы сдвигаем бокс вперед (-Z в Godot) на z_size/2, чтобы его край совпал со стартом.
		# На t=1 мы сдвигаем бокс назад (+Z) на z_size/2, чтобы его край совпал с финишем.
		var z_shift = lerp(-z_size / 2.0, z_size / 2.0, t)
		segment_transform = segment_transform.translated_local(Vector3(0.0, cross_size.y/2, z_shift))
		print(segment_transform)
		var collision_shape = CollisionShape3D.new()
		collision_shape.name = "BallastShape_%d" % i
		
		var box_shape = BoxShape3D.new()
		box_shape.size = box_size
	
		collision_shape.shape = box_shape
		collision_shape.transform = segment_transform
		
		owner_node.add_child(collision_shape)

#------SAVE\LOAD----

## Данные для сохранения.
## Этот компонент отвечает за path и ballast. На данном этапе из этих значений можно получить копию трака
func save_data() -> Dictionary:
	return {
		'comp_path':get_script().resource_path,		# "res://core/components/c_power_clip.gd"
		'comp_name':get_script().resource_path.get_file().get_basename(),
		"radius": radius,
		"deg": deg
	}


func load_data(data: Dictionary) -> void:
	if data.has("radius"):
		radius = data.radius
	if data.has("deg"):
		deg = data.deg


# -----HELPERS------

func _find_ballast_recursive(node: Node) -> Area3D:
	if node.name == 'Ballast' :	return node
	
	for child in node.get_children():
		var found = _find_ballast_recursive(child)
		if found:
			return found
	return null


## Меняет активный слой объекта при перетаскивании
func on_select_layer(_data):
	# нужные слои (collision_layer / collision_mask)
	#area.set_collision_layer_value(3, true) # вкл этот слой 
	if _data.enabled:
		ballast_node.collision_layer =  1 << 10	# заменяет активный слой на 11
		ballast_node.collision_mask = 1 << 2 # гост видит только 3 слой
		
		headl_node.collision_layer =  1 << 10	# заменяет активный слой на 11
		headr_node.collision_layer =  1 << 10	# заменяет активный слой на 11
		headl_node.collision_mask = 1 << 2 # гост видит только 3 слой
		headr_node.collision_mask = 1 << 2 # гост видит только 3 слой
	else:
		ballast_node.collision_layer = 1 << 2 	# заменяет активный слой на 3
		ballast_node.collision_mask = 1 << 2
		
		headl_node.collision_layer =  1 << 2	# заменяет активный слой на 11
		headr_node.collision_layer =  1 << 2	# заменяет активный слой на 11
		headl_node.collision_mask = 1 << 2 # гост видит только 3 слой
		headr_node.collision_mask = 1 << 2 # гост видит только 3 слой
	pass


func get_length() -> float:
	return snapped(radius * deg_to_rad(deg), 0.1) if deg !=0.0 else snapped(radius,0.1)


# Больше не ищем, только генерация
#func _find_path3d_recursive(node: Node) -> Path3D:
	#if node is Path3D:
		#return node
	#for child in node.get_children():
		#var found = _find_path3d_recursive(child)
		#if found:
			#return found
	#return null
