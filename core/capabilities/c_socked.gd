class_name C_Socket extends ISnappable

####################
## Способность, Библиотека действий. Она живет на объекте всегда.
####################
## 💡Должен загружаться после C_Path 
## содержит внутри себя логику расчета (парсинг Path3D) точек стыковки
## Хранит точки стыковки (локальные координаты и вектор направления "наружу")


var sockets: Array[Dictionary] = []

# Используем on_entity_ready, чтобы гарантировать, что C_Visual 
# уже добавил свои инстансы (Path3D) в дерево.
# Вызывается ядром Entity после того, как все компоненты добавлены
func on_entity_ready():
	_parse_paths()


func get_sockets() -> Array[Dictionary]:
	return sockets



func _parse_paths():
	# Стучимся в логический компонент пути
	var path_comp = get_comp(C_Path)
	if path_comp and path_comp.path:
		_parse_curve(path_comp.curve, path_comp.path)



# Парсим кривую из path3d для вычисления сокетов
func _parse_curve(c: Curve3D, p: Path3D):
	if c.get_point_count() < 2: return
	
	# Берем точные координаты первой и последней точек
	var p_first = c.get_point_position(0)
	var p_last = c.get_point_position(c.get_point_count() - 1)

	printt('====entity        : ',entity.transform.origin, entity.global_position) 
	printt('====path        : ',p.position) 

	# Направление на старте — это направление ручки `out`, либо просто вперед, если ручки нет
	var d_first = -c.get_point_out(0).normalized()
	if d_first.is_zero_approx(): #true если значения этого вектора приблизительно равны нулю
		d_first = -(c.get_point_position(1) - p_first).normalized()
		printt('d_0 loc_pos:',p_first, ' dir: ', d_first) #debug
	else:
		d_first = d_first # Смотрит наружу по направлению ручки
		
	# Направление на конце — это инвертированная ручка `in` (чтобы смотреть "наружу")
	var d_last = -c.get_point_in(c.get_point_count() - 1).normalized()
	
	if d_last.is_zero_approx():
		d_last = -(c.get_point_position(c.get_point_count() - 2) - p_last).normalized()
		printt('d_1 loc_pos:',p_last, ' dir: ', d_last)
	_add_socket_if_unique(p_first, d_first)
	add_socked_area( p_first, d_first)
	_add_cone(p.transform * p_first, Color.CHARTREUSE)  #debug
	
	
	_add_socket_if_unique(p_last, d_last)
	add_socked_area(p_last, d_last)
	_add_cone(p.transform * p_last, Color.DEEP_PINK)#debug



##TODO  Сокет можно добавлять через размеры и градусы!!
# Добавляем сокет, только если в этой точке его еще нет (слияние для стрелок)
func _add_socket_if_unique(pos: Vector3, dir: Vector3):
	for s in sockets:
		if s.pos.distance_to(pos) < 0.01:
			return # Сокет уже зарегистрирован
			
	sockets.append({
		"pos": pos,
		"out_dir": dir
	})


func add_socked_area( _pos, dir):
	var area = Area3D.new()
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	
	area.collision_layer = 1 << 3 	# Слой 4
	area.collision_mask = 1 << 3
	area.name = 'Socket_0'
	
	var piv = entity.get_comp(C_Pivot).offset
	area.position = (_pos + piv)
	printt('node :', area.position)
		# позиция → локальные Path3D → локальные entity
		
	capsule.radius = 0.5
	capsule.height = 2.0

	collision.shape = capsule
	collision.rotation.x = -PI/2 # положить вдоль Z капсулу вперед (-Z)
	area.add_child(collision)
	
	entity.add_child(area) # В Entity !!

	# Поворот наружу !!! TODO Переделать в трансформ
	# Направление на лок.поз.   + смещение наружу + глоб смещение ентити  
	area.look_at( (area.position + dir) + entity.position, Vector3.UP)
	
	# Коннекты к сигналам сокетов
	area.area_entered.connect(on_area_entered)
	area.area_exited.connect(on_area_entered)
	
	# Визуальный маркер
	_add_marker(collision)


## ⚡Сигнал area 
func on_area_entered(area: Area3D):
	print('area enter: ', area)


func on_area_exited(area: Area3D):
	print('area exit: ', area)



# Рекурсивный поиск всех Path3D в визуале
func _find_paths_recursive(node: Node) -> Array[Path3D]:
	var result: Array[Path3D] = []
	if node is Path3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_paths_recursive(child))
	return result
	
	

## ==== МАРКЕРЫ ====

# Шарик 
func _add_marker(_node, _color = Color.RED):
	# Визуальный маркер (шарик)
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	marker.mesh = sphere
	
	# Красный материал
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _color
	mat.emission_enabled = true

	marker.material_override = mat
	# поставить на кончик капсулы
	marker.position = Vector3(0, 1.5, 0)
	_node.add_child(marker)



# Конус
func _add_cone(_pos, _color = Color.BURLYWOOD):
	var marker := MeshInstance3D.new()

	var cone := CylinderMesh.new()
	cone.top_radius = 0.01
	cone.bottom_radius = 0.12
	cone.height = 2
	marker.mesh = cone
	
	#marker.position = _p.transform * (_pos) # Если _p закидываем в функцию
	marker.position = _pos
	
	# материал
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _color
	mat.emission_enabled = true
	marker.material_override = mat
	
	entity.add_child(marker)
