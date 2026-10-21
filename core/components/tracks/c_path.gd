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
var head_node : StaticBody3D #  Статик нода рельсов

var pivot_offset := Vector3.ZERO 

# XX claude-terra --- пандус и подготовка к Flex ---
var rise := 0.0       # подъем вдоль трака (ю), только прямые
var pitch := 0.0      # угол наклона инстанса, рад
## true: origin сущности в середине кривой (жесткие траки). false: в начале (flex)
var centered := true

var _radii := PackedFloat32Array()   # радиус на каждом шаге baked-кривой (только flex)
var _radii_step := 1.0

## Замена из багнутой
## Высота поверхности катания над origin пути, ю. Все, кто ездит по траку или садится на него, читают только это.
var _head_h := -1.0   # < 0: не задана, берём из конфига при первом обращении


## Высота поверхности катания над origin пути, ю. Все, кто ездит по траку или садится на него, читают только это.
func head_height() -> float:
	if _head_h < 0.0:
		var nominal: float = Global.settings.get_track_height()
		var identity := get_comp(C_Identity) as C_Identity
		_head_h = float(identity.get_config('height', nominal)) if identity else nominal
	return _head_h


## Для стиля (шаг 2): TrackStyle переопределяет высоту
func set_head_height(h: float) -> void:
	_head_h = h
	
## =======================

func on_added():
	pass



func on_entity_ready() -> void:
	var identity = get_comp(C_Identity) as C_Identity
	if not identity or not identity.setting:
		return

	radius = identity.get_config('radius', 0.0)
	deg = identity.get_config('deg', 0.0)
	# XX claude-terra
	rise = identity.get_config('rise', 0.0)
	# Защита от нулевой длины: radius у прямой это её длина (flex стартует прямой 10)
	if absf(deg) < 0.01 and radius < 0.49:
		radius =0.5
	# Пандус на дуге - rise проигнорирован
	if absf(deg) > 0.01 and rise != 0.0:
		rise = 0.0
	pitch = asin(clampf(rise / maxf(radius, 0.01), -1.0, 1.0)) if rise != 0.0 else 0.0
	var pivot = get_comp(C_Pivot)
	if pivot: pivot_offset = pivot.offset
	
	# Генерируем математически точную кривую
	curve = generate_track_curve(radius, deg)
	
	# Синхронизируем её с визуальной нодой Path3D, если она есть в сцене
	path_node = _generate_path()
	
	# Синхронизируем коллизии балласта с нодой Ballast, если она есть в сцене
	_sync_with_visual_ballast()
	
	# Синхронизируем коллизии рельсов с нодами сцены
	# Здесь или в отдельной функции делаем статик
	_sync_with_visual_heads()
## Замена из багнутой
	if absf(head_height() - Global.settings.get_track_height()) > 0.001:
		#push_warning("%s: head_height %.2f != номинал %.2f" % [entity.name, head_height(), Global.settings.get_track_height()])
		pass
	



# Генерируем ноду Path3D и новый оффсет в C_Pivot 
func _generate_path() -> Path3D:

	var _path_n = Path3D.new()
	entity.add_child(_path_n)
	_path_n.name = 'Path3d_generated'
	
	_path_n.curve = curve
	var curve_length = _path_n.curve.get_baked_length()

	# Середина кривой
	var _new_offset = Vector3.ZERO   # XX claude-terra
	if centered:
		_new_offset = - _path_n.curve.sample_baked_with_rotation(curve_length/2).origin
	
	# И пересчет offset по новой кривой
	_path_n.position = _new_offset
	entity.send_event('on_offset_changed', {"new_offset": _new_offset}) # В C_Pivot
	pivot_offset = _new_offset
	entity.send_event('on_slope_changed', {"pitch": pitch})   # XX claude-terra в C_TrackVisual

	return _path_n



## Синхронизируем ноду "Ballast" с нодой сцены внутри C_TrackVisual
func _sync_with_visual_ballast():
	var visual = get_comp(C_TrackVisual)

	if not visual or not visual.instance: return

	# Находим ноду балласта 
	ballast_node = _find_ballast_recursive(visual.instance)
	# Проверка сцены. Eсли в ней балласта нет, то значит он не нужен, выходим
	if not ballast_node: return 

	#Если коллизия есть, то она сделана в сцене специально для оптимизации (прямая состоит из одного сегмента например) или намеренно - оставляем.
	# Расчет балласта. Если у балласта нет коллизий, то будем генерить.
	var _debug_color=Color("00b296ff")
	var gs_ballast = Global.settings.track_ballast_segment
	if ballast_node.get_child_count() == 0: 
		# основной балласт
		var dynamic_count = _calculate_collision_count(radius, deg, gs_ballast.deg_per_segment)
		_generate_collision_segments(ballast_node, dynamic_count, gs_ballast.size,  gs_ballast.offset_x, 0, gs_ballast.start_end_padding , gs_ballast.gap, gs_ballast.align_ends)

		_debug_color=Color("fd3fadff")
		
	#INFO цвет коллизий для дебага
	
	var collision_shapes =  ballast_node.get_children()
	for seg in collision_shapes:
		seg.set_debug_color(_debug_color)



## Синхронизируем ноды "HeadStaticBody3D" с нодами сцены внутри C_TrackVisual
func _sync_with_visual_heads():
	var visual = get_comp(C_TrackVisual) as C_TrackVisual
	if not visual or not visual.instance: return

	# Находим ноды рельсов
	head_node = visual.static_node

	# 1️⃣ Проверка сцены. Eсли в ней рельсов, то значит он не нужен, выходим
	if not head_node: return 

	#Если коллизия есть, то она сделана в сцене специально для оптимизации (прямая состоит из одного сегмента например) или намеренно - оставляем.

	# 2️⃣ Расчет статик. Если нет коллизий, то будем генерить.
	var gs_head = Global.settings.track_head_segment
	var gs_ballast = Global.settings.track_ballast_segment
	var dynamic_count = _calculate_collision_count(radius, deg, gs_head.deg_per_segment)
	
	
	var _debug_color=Color("008427ff")
	
	# 3️⃣ 0️⃣  Вешаем статик на балласт, если надо
	if not head_node or head_node.get_child_count() == 0: # Метод генерации статикбоди трака
		
		if gs_head.static_generation_ballast:
			_generate_collision_segments(head_node, dynamic_count, gs_ballast.size,  gs_ballast.offset_x, 0, gs_ballast.start_end_padding , gs_ballast.gap, gs_ballast.align_ends)

		# 3️⃣ 1️⃣  Вешаем  1 большой  хедстатик 
		if gs_head.static_generation_heads == 1 :  # Метод генерации статик
			_generate_collision_segments(head_node , dynamic_count, gs_head.size,  0 , gs_ballast.size.y, gs_head.start_end_padding , gs_head.gap, gs_ballast.align_ends)
			
			# 3️⃣ 2️⃣  Вешаем 2 статик на хеды
		elif gs_head.static_generation_heads == 2 : # Метод генерации статик
			# Правый хед
			_generate_collision_segments(head_node , dynamic_count, gs_head.size, gs_head.offset_x, gs_ballast.size.y, gs_head.start_end_padding , gs_head.gap, gs_ballast.align_ends)
			# Левый хед
			_generate_collision_segments(head_node , dynamic_count, gs_head.size, -gs_head.offset_x, gs_ballast.size.y, gs_head.start_end_padding , gs_head.gap, gs_ballast.align_ends)

		_debug_color=Color("1722ffff")
		
	#INFO цвет коллизий для дебага
	var collision_shapes =  head_node.get_children()
	for seg in collision_shapes:
		seg.set_debug_color(_debug_color)
	
		


## Процедурный генератор кривой с идеальными касательными на торцах
func generate_track_curve(_radius: float, _deg: float) -> Curve3D:
	var new_curve = Curve3D.new()
	
	if abs(_deg) < 0.01:
		# --- ЧАСТНЫЙ СЛУЧАЙ: ПРЯМОЙ ТРАК ---
		# Первая точка в нуле, вторая уходит по оси -Z на расстояние radius (длину)
		# Ручки строго нулевые, так как это идеальная прямая
		new_curve.add_point(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
		# XX claude-terra _radius = длина вдоль уклона, горизонтальная проекция короче
		var h_len := sqrt(maxf(_radius * _radius - rise * rise, 0.0))
		new_curve.add_point(Vector3(0, rise, -h_len), Vector3.ZERO, Vector3.ZERO)
		
	else:
		# --- РАДИУСНЫЙ ТРАК (ДУГА ОКРУЖНОСТИ) ---
		var alpha = deg_to_rad(abs(_deg))
		var dir_sign = sign(_deg)
		if dir_sign == 0: dir_sign = 1.0 # Предохранитель
		
		# Идеальная длина управляющих векторов Безье для дуги окружности
		var L = (4.0 / 3.0) * tan(alpha / 4.0) * _radius
		
		# 1. СТАРТОВАЯ ТОЧКА (всегда в нуле, направлена строго вперед по -Z)
		var start_pos = Vector3.ZERO
		var start_in = Vector3.ZERO
		var start_out = Vector3(0, 0, -L) # Смотрит вперед, обеспечивая идеальный торец
		new_curve.add_point(start_pos, start_in, start_out)
		
		# 2. КОНЕЧНАЯ ТОЧКА (вычисляется через тригонометрию дуги)
		# Если dir_sign = 1 (вправо), координата X положительная. Если -1 (влево) — отрицательная.
		var end_pos = Vector3(
			dir_sign * _radius * (1.0 - cos(alpha)), 
			0, 
			-_radius * sin(alpha)
			)
		
		# Ручка "внутрь" (end_in) должна быть направлена строго назад по касательной к окружности
		var end_in = Vector3(-dir_sign * sin(alpha), 0, cos(alpha)) * L
		var end_out = Vector3.ZERO
		new_curve.add_point(end_pos, end_in, end_out)
		
	return new_curve
	
	

### Расчет оптимального количества сегментов коллизии
func _calculate_collision_count(track_radius: float, track_deg: float, deg_per_segment: float) -> int:
	# 1. Прямые траки (или нулевой радиус)
	if track_radius == 0.0 or track_deg == 0.0:
		return 1 # Одной длинной коробки достаточно
		
	# 2. Настройки аппроксимации кривой
	# Сколько градусов дуги может покрывать один прямой сегмент коллизии
	
	# 15.0 - отличный баланс: на 90 градусов будет 6 боксов, на 45 градусов — 3 бокса.
	# 3. Считаем количество (округляем вверх, чтобы покрыть весь угол)
	var count = ceil(abs(track_deg) / deg_per_segment)
	
	# Любая кривая должна состоять минимум из 2 сегментов для формирования угла
	return int(max(2, count))
		
	
## ====Вроде рабочая====
## Универсальная генерация сегментов коллизий
func _generate_collision_segments(
	target_node: Node3D, # родительская нода
	count: int, # количество сегментов
	cross_size: Vector2, # размеры без Z
	x_offset: float = 0.0, # смещение влево
	y_offset: float = 0.0, # смещение вверх
	start_end_padding: float = 0.0, # смещение первого последнего сегмента
	gap: float = 0.0, # зазор
	align_ends: bool = true # Выравнивание торцов
) -> void:

	# 1. Вычисление размеров сегмента

	var l_arc = (radius - x_offset) * deg_to_rad(deg) if deg != 0.0 else (radius - x_offset)
	var _segment_size_z = 0.0
	if count == 1:
		_segment_size_z =  radius+start_end_padding * 2.0
	else:
		_segment_size_z = (l_arc - gap * (count - 1) + start_end_padding * 2.0) / count

	var _segment_size = Vector3(cross_size.x, cross_size.y, _segment_size_z)

	
		
	# 2. Оптимизация памяти: один общий ресурс формы на все сегменты
	var shared_shape = BoxShape3D.new()
	shared_shape.size = _segment_size
	
	# 3. Предрасчет неизменяемых значений
	var padding_angle = rad_to_deg(asin(start_end_padding / radius)) if radius != 0.0 else 0.0
	var offset_z_delta = _segment_size_z * 0.5 - start_end_padding
	var _z = radius / 2  if count == 1 else 0.0 # если прямая то сразу в центр
	var return_offset = Vector3(-radius, -cross_size.y * 0.5, _z)
	var base_x = -radius + x_offset   # если прямая то сразу в центр


	# 💡 Генерация сегментов
	for i in range(count):
		var _d: float
		var s_z: float = 0.0
		var _last_segment: int = -1

		# Расчет угла и торцевых смещений
		if i == 0: # Первая коллизия
			if align_ends:
				_d = 0.0
				s_z = -offset_z_delta
			else:
				_d = deg * 0.5 / float(count) - padding_angle

		elif i == count - 1: # Последняя коллизия
			_last_segment = 1
			if align_ends:
				_d = deg
				s_z = offset_z_delta
			else:
				_d = deg * (i + 0.5) / float(count) + padding_angle

		else: # Промежуточные сегменты
			_d = deg * (i + 0.5) / float(count)

		# Инстанцирование и трансформация
		var new_segment = CollisionShape3D.new()
		new_segment.shape = shared_shape
		target_node.add_child(new_segment)

		var _segment_tr = Transform3D(Basis.IDENTITY, Vector3(base_x, y_offset, s_z ))
		_d = 0.0  if count == 1 else _d # если прямая то 0
		_segment_tr = _segment_tr.rotated(Vector3.UP, deg_to_rad(-_d))
		_segment_tr.origin -= return_offset
		
		new_segment.transform = _segment_tr



### ====Моя рабочая, но что выше тоже норм вроде ====
## Универсальная генерация сегментов коллизий
func _generate_collision_segments0(
	target_node: Node3D, # родительская нода
	count: int, # количество сегментов
	cross_size: Vector2, # размеры без Z
	x_offset: float = 0.0, # смещение влево
	y_offset: float = 0.0, # смещение вверх
	start_end_padding: float = 0.0, # смещение первого последнего сегмента
	gap: float = 0.0, # зазор
	align_ends: bool = true # Выравнивание торцов
) -> void:

	# длина  дуги
	var l_arc= (radius - x_offset) * deg_to_rad(deg) 
	var _d = 0.0 # текущий угол для создания коллизии

	# 0. Размер сегмента
	var _segment_size_z = (l_arc - gap * (count - 1) + start_end_padding * 2)/ count
	var _last_segment = -1 # флаг последней коллизии
	var _segment_size = Vector3(cross_size.x, cross_size.y, _segment_size_z) #размер фрагмента 
	

	# 💡 Генерим сегменты
	for i in range(0, count):
		# 1. угол для сегмента	
		# по умолчанию _d = 0 и используется когда i=0, в остальном :
		if i == 0:  # 🅰️ первая коллизия 
			# Доворот на катет паддинг
			_d = deg * 0.5 / float(count) - rad_to_deg(asin( start_end_padding / radius ))
			if align_ends: 
				_d = 0 
				
				
		else : # 🅱️ промежуточные сегменты
			_d = deg * (i+0.5) / float(count)

			if i == count - 1: # 🆑 последняя коллизия  
				#_d = deg
				# Доворот на катет паддинг
				_d = deg *  (i+0.5)/ float(count) + rad_to_deg(asin( start_end_padding / radius ))
				if align_ends: 	
					_d= deg
					_last_segment = 1

		var new_segment = CollisionShape3D.new()
		target_node.add_child(new_segment)
		new_segment.shape = BoxShape3D.new()
		new_segment.shape.set_size(_segment_size)

		# трансформ для коллижн 
		var s_z = 0.0 # смещение от центра последней или первой отличается от остальных
		if align_ends : 
			if _d == 0 or _last_segment ==  1:# первая и последняя смещаются
				s_z = _last_segment * (_segment_size_z /2  - start_end_padding)

		var _segment_tr = Transform3D(Basis.IDENTITY,Vector3(-radius + x_offset, y_offset, s_z))
		# поворот на угол
		_segment_tr = _segment_tr.rotated(Vector3.UP, deg_to_rad(-_d)) 

		## возврат на место
		_segment_tr.origin -= Vector3(-radius, -cross_size.y / 2, 0)
		new_segment.set_transform(_segment_tr)

			
	

#------SAVE\LOAD----

## Данные для сохранения.
## Этот компонент отвечает за path и ballast. На данном этапе из этих значений можно получить копию трака
func save_data() -> Dictionary:
	return {
		'comp_path':get_script().resource_path,		# "res://core/components/c_power_clip.gd"
		'comp_name':get_script().resource_path.get_file().get_basename(),
		"radius": radius,
		"rise": rise,   # XX claude-terra
		"deg": deg
	}


func load_data(data: Dictionary) -> void:
	if data.has("radius"):
		radius = data.radius
	if data.has("deg"):
		deg = data.deg
	if data.has("rise"):   # XX claude-terra
		rise = data.rise


# XX claude-terra ===== Flex-ready API =====
## Радиус кривой в точке s (расстояние вдоль кривой). INF для прямой
func radius_at(s: float) -> float:
	if _radii.is_empty():            # жесткий трак
		return radius if absf(deg) > 0.01 else INF
	return _radii[clampi(roundi(s / _radii_step), 0, _radii.size() - 1)]


# XX claude-terra
## Единственная точка, через которую flex меняет форму пути
func set_curve(c: Curve3D) -> void:
	curve = c
	if path_node:
		path_node.curve = c
	_bake_radii()
	entity.send_event("on_curve_changed", {})


# XX claude-terra
func _bake_radii() -> void:
	_radii = PackedFloat32Array()
	if not curve:
		return
	var length := curve.get_baked_length()
	if length < 0.01:
		return
	var n := maxi(3, ceili(length) + 1)
	_radii_step = length / float(n - 1)
	var pts := PackedVector2Array()
	for i in n:
		var p := curve.sample_baked(_radii_step * i)
		pts.append(Vector2(p.x, p.z))
	_radii = FlexSolver.radii(pts)


# XX claude-terra
## Насколько самая глубокая точка кривой уходит под землю, если Entity стоит в позе xf. 0 = не уходит.
## Землей считается слой 'ground' (стол, позже листы пенопласта).
func underground_depth(xf: Transform3D) -> float:
	if not curve or not path_node or not entity.is_inside_tree():
		return 0.0
	var space := entity.get_world_3d().direct_space_state
	var length := curve.get_baked_length()
	var n := maxi(2, ceili(length / 4.0) + 1)
	var worst := 0.0
	for i in n:
		var p: Vector3 = xf * (path_node.position + curve.sample_baked(length * i / (n - 1)))
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 1000.0, p.z), Vector3(p.x, -1000.0, p.z),
				Global.active_layers(['ground']))
		var hit := space.intersect_ray(q)
		var gy := 0.0
		if not hit.is_empty():
			gy = hit.position.y
		worst = maxf(worst, gy - p.y)
	return worst


# XX claude-terra T5
## Плоский горизонтальный трак: без уклона и не flex. Только такой трак подгоняет под себя листы
## пенопласта (магнит верха листа и обрезка под балласт). У пандусов и flex низ балласта наклонный
func is_flat() -> bool:
	return rise == 0.0 and pitch == 0.0 and not has_comp(C_FlexShape)


# XX claude-terra T5
## Низ балласта в мире. Origin плоского трака = низ балласта
func bottom_y() -> float:
	return entity.global_position.y


# XX claude-terra T5
## Контур балласта в плане (мировые x, z): полоса шириной с балласт вдоль кривой.
## Для обрезки листа под балласт и магнита листа. Вершины идут вдоль левого края вперед, вдоль правого назад
func footprint_world() -> PackedVector2Array:
	var res := PackedVector2Array()
	if not curve or not path_node or not entity.is_inside_tree():
		return res
	var half: float = Global.settings.track_ballast_segment.size.x * 0.5
	var length := curve.get_baked_length()
	var n := maxi(2, ceili(length / 2.0))
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n + 1:
		var t := curve.sample_baked_with_rotation(length * i / n)
		var p := path_node.to_global(t.origin)
		var fwd := path_node.global_basis * -t.basis.z
		fwd.y = 0.0
		if fwd.length_squared() < 0.0001:
			continue
		var side := Vector3.UP.cross(fwd.normalized())
		left.append(Vector2(p.x + side.x * half, p.z + side.z * half))
		right.append(Vector2(p.x - side.x * half, p.z - side.z * half))
	right.reverse()
	res.append_array(left)
	res.append_array(right)
	return res


# -----HELPERS------
### Универсальный рекурсивный поиск ноды по имени
func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name: 
		return node
	for child in node.get_children():
		var found = _find_node_recursive(child, target_name)
		if found: 
			return found
	return null
	
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
		
		head_node.collision_layer =  1 << 10	# заменяет активный слой на 11
		head_node.collision_mask = 1 << 2 # гост видит только 3 слой
		#headl_node.collision_layer =  1 << 10	# заменяет активный слой на 11
		#headr_node.collision_layer =  1 << 10	# заменяет активный слой на 11
		#headl_node.collision_mask = 1 << 2 # гост видит только 3 слой
		#headr_node.collision_mask = 1 << 2 # гост видит только 3 слой
	else:
		ballast_node.collision_layer = 1 << 2 	# заменяет активный слой на 3
		ballast_node.collision_mask = 1 << 2
		head_node.collision_layer =  1 << 2	# заменяет активный слой на 11
		head_node.collision_mask = 1 << 2 # гост видит только 3 слой
		#headl_node.collision_layer =  1 << 2	# заменяет активный слой на 11
		#headr_node.collision_layer =  1 << 2	# заменяет активный слой на 11
		#headl_node.collision_mask = 1 << 2 # гост видит только 3 слой
		#headr_node.collision_mask = 1 << 2 # гост видит только 3 слой
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
