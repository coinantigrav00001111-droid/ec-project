class_name C_Path extends Component

####################
## Способность, Библиотека действий. Она живет на объекте всегда.
####################
## Описывает физическое свойство объекта («у меня есть Path3d»),
## содержит внутри себя логику расчета 
##
## Если Path3d есть в сцене (инстанс), то он переносится в ентити и проверяется на длину. Если длина есть, то 
## используется эта кривая. Если длина 0 - то генрится новая кривая и оффсет

var path: Path3D
var curve: Curve3D
var pivot_offset := Vector3.ZERO


func on_entity_ready() -> void:
	var identity = get_comp(C_Identity)
	if not identity or not identity.setting:
		return
	
	var pivot = get_comp(C_Pivot)
	if pivot: pivot_offset = pivot.offset
	
	var radius = identity.get_radius()
	var deg = identity.get_degree()
		
	# Генерируем математически точную кривую
	curve = generate_track_curve(radius, deg)
	
	# Синхронизируем её с визуальной нодой Path3D, если она есть в сцене
	path = _sync_with_visual_path()



## Процедурный генератор кривой с идеальными касательными на торцах
func generate_track_curve(radius: float, deg: float) -> Curve3D:
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



## Хелпер для поиска и обновления ноды Path3D внутри C_Visual
func _sync_with_visual_path() -> Path3D:
	var visual = get_comp(C_Visual)
	if not visual or not visual.instance: return
	
	var path_node = _find_path3d_recursive(visual.instance)
		
	if not path_node: return
	
	# Переносим path из визуал в ентити
	path_node.get_parent().remove_child(path_node)
	entity.add_child(path_node)
	
	var curve_length = path_node.curve.get_baked_length()
	
	# Пересчет кривой
	if curve_length < 0.1: # Если длина нулевая, то подставляется сгенерированная
		path_node.curve = curve
		curve_length = path_node.curve.get_baked_length()

	# Середина кривой
	var _new_offset = - path_node.curve.sample_baked_with_rotation(curve_length / 2).origin
	
	# И пересчет offset по новой кривой
	path_node.position = _new_offset
	entity.send_event('on_offset_changed', {"new_offset": _new_offset})
	return path_node



func _find_path3d_recursive(node: Node) -> Path3D:
	if node is Path3D:
		return node
	for child in node.get_children():
		var found = _find_path3d_recursive(child)
		if found:
			return found
	return null
