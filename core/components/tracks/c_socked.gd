class_name C_Socket extends ISnappable

####################
## Способность, Библиотека действий. Она живет на объекте всегда.
####################
## 💡Должен загружаться после C_Path 
## содержит внутри себя логику расчета (парсинг Path3D) точек стыковки
## Хранит точки стыковки (локальные координаты и вектор направления "наружу")


var sockets: Array[Dictionary] = []

## Массив ссылок на валидные соседние сущности (для графа сети)
var connected_entities: Array[Entity] = []

# XX claude-terra 13.1.4
## Чужие сокеты, снап к которым отклонён (излом или подземное положение). Пока список не пуст,
## призрак или трак в драге красный (C_Invalid) и не ставится. Только жесткие траки: у flex свой C_Invalid
var _snap_rejected: Array[Area3D] = []
## Причина последнего отказа: "kink" (излом по вертикали), "underground" (трак уходит под землю) или "".
## Нужна для подсказки про разворот на 180°
var snap_reject_reason := ""
## Метка с причиной отказа (Label3D над траком, создается по требованию)
var _hint: Label3D

# Настройки формы сокета
var  capsule_radius := 0.6
var capsule_height := 1.49

# Используем on_entity_ready, чтобы гарантировать, что C_TrackVisual 
# уже добавил свои инстансы (Path3D) в дерево.
# Вызывается ядром Entity после того, как все компоненты добавлены
# XX claude-terra
func on_added() -> void:
	entity.add_to_group(&"track_socket")   # для вертикального магнита в C_TrackDraggable


func on_entity_ready():
	_parse_paths()




# Парсим path , ищем его, а в нем curve 
func _parse_paths():
	# Стучимся в логический компонент пути
	var path_comp = get_comp(C_Path)
	if path_comp and path_comp.path_node:
		# XX claude-switch: у стрелки сокеты со всех маршрутов (носок общий, сливается в _add_socket_if_unique)
		for c in path_comp.all_curves():
			_parse_curve(c, path_comp.path_node)



# Парсим кривую из path3d для вычисления сокетов
func _parse_curve(c: Curve3D, p: Path3D):
	if c.get_point_count() < 2: return

	# Берем точные координаты первой и последней точек
	var p_first = c.get_point_position(0)
	var p_last = c.get_point_position(c.get_point_count() - 1)

	# Направление на старте — это направление ручки `out`, либо просто вперед, если ручки нет
	var d_first = -c.get_point_out(0).normalized()
	if d_first.is_zero_approx(): #true если значения этого вектора приблизительно равны нулю
		d_first = -(c.get_point_position(1) - p_first).normalized()
	else:
		d_first = d_first # Смотрит наружу по направлению ручки
		
	# Направление на конце — это инвертированная ручка `in` (чтобы смотреть "наружу")
	var d_last = -c.get_point_in(c.get_point_count() - 1).normalized()
	
	if d_last.is_zero_approx():
		d_last = -(c.get_point_position(c.get_point_count() - 2) - p_last).normalized()
		
	_add_socket_if_unique(p_first, d_first, true)
	_add_cone(p.transform * p_first, Color.CHARTREUSE)  #debug
	
	
	_add_socket_if_unique(p_last, d_last, false)
	_add_cone(p.transform * p_last, Color.DEEP_PINK)#debug





# Добавляем сокет в массив, только если в этой точке его еще нет (слияние для стрелок)
## XX claude-switch: is_start = начало маршрута. Нужен PGM для полярности: у кросса два начала (сокеты 0 и 2)
func _add_socket_if_unique(pos: Vector3, dir: Vector3, is_start: bool = false):
	for s in sockets:
		if s.pos.distance_to(pos) < 0.01:
			return # Сокет уже зарегистрирован
			
	var new_socket =  _add_socked_area( pos, dir)
	sockets.append({
		"pos": pos,
		"out_dir": dir,
		"socket": new_socket,
		"start": is_start
	})



func _add_socked_area(_pos: Vector3, dir: Vector3) -> Area3D:
	#printt(entity.name)
	var area = Area3D.new()
	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	
	# подрезаем высоту сокета на коротком траке
	for s in sockets:
		if s.pos.distance_to(_pos) <= 1.5 and s.pos.distance_to(_pos) > 0:
			capsule_height = s.pos.distance_to(_pos) - 0.1
			s.socket.get_child(0).shape.height = s.pos.distance_to(_pos) - 0.1
	# Настройки формы сокета 
	capsule.height = capsule_height
	capsule.radius = capsule_radius
	
	collision.shape = capsule
	collision.rotation.x = PI/2 # положить вдоль Z капсулу вперед (-Z)
	
	# Важно: сначала добавляем в дерево сцены, чтобы трансформации работали корректно
	entity.add_child(area)
	area.add_child(collision)
	
	# XX claude-terra позиция и поворот вынесены в _orient_area (его же использует on_curve_changed)
	var piv = entity.get_comp(C_Pivot).offset
	#_orient_area(area, _pos + piv, dir)
	_orient_area(area, _pos + piv + Vector3(0.0, _surface_lift(), 0.0), dir)

		
	# нужные слои (collision_layer / collision_mask)
	#area.set_collision_layer_value(4, true) # вкл этот слой 
	area.collision_layer = 1 << 3 	# Слой 4 # заменяет активный слой этими
	area.collision_mask = 1 << 3
	area.name = entity.name + '_Socket_0' 
	
	# Подключаем сигнал, передавая саму area как второй аргумент
	area.area_entered.connect(_on_socket_area_entered.bind(area))
	area.area_exited.connect(_on_socket_area_exited)
	
	# Визуальный маркер
	_add_marker(collision)

	return area


## СИГНАЛЫ

## TODO Почистить скрипт
## ⚡Сигнал area вход
# s_socket - стац трак, d_socket - драг трак
func _on_socket_area_entered(s_socket: Area3D, d_socket: Area3D) -> void:
	# Чтобы стейты заехали в ентити
	await get_tree().physics_frame
	
	# Из Блокед не может быть снапа
	if entity.has_comp(C_Blocked):
		return
	
	var neighbor_entity = _find_entity_from_collider(s_socket)

	## Добавляем соседа в список. Предохранители:
	# 1. Сущность найдена и это не мы сами. 2. Сущность не является призраком 3. Мы еще не добавили ее в массив.

	if neighbor_entity and neighbor_entity != entity:
		if not neighbor_entity.has_comp(C_Ghost) and not connected_entities.has(neighbor_entity):
			connected_entities.append(neighbor_entity)
			entity.send_event("on_neighbors_changed", {})   # XX claude-terra 13.1.5: опоры на стыке (кто строит общую)
			# новый реальный стык (flex встаёт из призрака, выхода из сокета не будет): пересчитать сеть
			if not entity.has_comp(C_Ghost):
				PGM.request_recalculate()

	# Снаппинг обрабатывается только той сущностью, которую СЕЙЧАС ТАЩАТ
	if not (entity.has_comp(C_Drag) or entity.has_comp(C_Ghost)):
		return
	
	# Если мы уже жестко зафиксированы в снапе, игнорируем новые триггеры
	if entity.has_comp(C_Snapped):
		return

	# Стац ентити. Проверка стац не есть драг
	var s_entity = _find_entity_from_collider(s_socket)
	if not s_entity or s_entity == entity:
		return

	# Проверяем, что объект коллизии — это тоже валидный сокет рельса
	if not s_entity.has_comp(C_Socket):
		return
	
	# ЗАЩИТА "Третьим не будет" и "Объект на объект":
	# Если стационарный сокет уже занят другим рельсом — отмена.
	if _is_socket_occupied(s_socket):
		return
		
	#TODO зачем проверять себя??
	# Если наш собственный уже занят другим рельсом — отмена.
	#if _is_socket_occupied(d_socket):
		#return
	#printt('entered',d_socket.name)
	# XX claude-terra снап по "yaw + позиция": трак остается горизонтальным, уклон живет внутри кривой
	var snap = _snap_transform(s_socket, d_socket)
	if snap == null:
		# XX claude-terra 13.1.4: излом больше joint_kink_max_deg или трак уходит под землю. Красный призрак
		_set_snap_rejected(s_socket, d_socket, true)
		return
	_set_snap_rejected(s_socket, d_socket, false)

	# Передаем управление в C_TrackDraggable
	var _comp = entity.get_comp(C_TrackDraggable)
	if _comp:
		_comp.start_snap(snap)

	# Тут делааем сеть или не делаем
	PGM.request_recalculate() # пересчет сети
	


## Выход ⚡Сигнал area 
func _on_socket_area_exited(_area: Area3D) -> void:
	_set_snap_rejected(_area, null, false)   # XX claude-terra 13.1.4: ушли от сокета, отказ снят
	var neighbor_entity = _find_entity_from_collider(_area)
	
	# Убираем соседа из списка
	if neighbor_entity and connected_entities.has(neighbor_entity):
		connected_entities.erase(neighbor_entity)
		entity.send_event("on_neighbors_changed", {})   # XX claude-terra 13.1.5

	PGM.request_recalculate() # пересчет сети
	
	# ⚡Сигнал для  UI обновление данных трака
	await get_tree().physics_frame



##  -------ДЛЯ ВАГОНА ----------

# Ищет соседа, который пристыкован к указанному краю нашего трака
func get_neighbor_at(is_exiting_end: bool) -> Entity:
	var path_comp = get_comp(C_Path)
	if not path_comp or not path_comp.path_node:
		return null
		
	var curve = path_comp.curve
	# Находим глобальную координату того края, с которого съезжаем
	var local_exit = curve.sample_baked(curve.get_baked_length() if is_exiting_end else 0.0)
	var global_exit = path_comp.path_node.to_global(local_exit)

	# Перебираем всех живых соседей
	for neighbor in get_connected_entities():
		var n_path = neighbor.get_comp(C_Path)
		if not n_path or not n_path.path_node:
			continue
			
		var n_curve = n_path.curve
		var n_node = n_path.path_node
		
		# Получаем глобальные координаты начала и конца соседа
		var n_start = n_node.to_global(n_curve.sample_baked(0.0))
		var n_end = n_node.to_global(n_curve.sample_baked(n_curve.get_baked_length()))
		
		# Если край соседа совпадает с нашей точкой выхода (с погрешностью 0.1м)
		if global_exit.distance_to(n_start) < 0.1 or global_exit.distance_to(n_end) < 0.1:
			return neighbor
			
	return null
	
	





# ---- HELPERS ---

#лямбда-фильтр  для защиты от крашей. Если игрок удалил рельс через инструмент удаления (вызвался queue_free()), физический сигнал exited может не успеть отработать. Фильтр гарантирует, что диспетчер получит только живые объекты.
# Возвращает массив живых соседей для PGM
func get_connected_entities() -> Array[Entity]:
	# Очищаем массив от "мертвых" ссылок перед отдачей
	connected_entities = connected_entities.filter(
		func(e): return is_instance_valid(e) and not e.is_queued_for_deletion()
	)
	return connected_entities
	


func get_sockets() -> Array[Dictionary]:
	return sockets



## Проверка: занят ли сокет стабильно установленным (не таскиваемым) рельсом
func _is_socket_occupied(socket_area: Area3D) -> bool:
	var my_entity = _find_entity_from_collider(socket_area)
	
	for area in socket_area.get_overlapping_areas():
		# 1. Игнорируем сам этот же сокет
		if area == socket_area:
			continue
			
		var other_entity = _find_entity_from_collider(area)
		
		# 2. Игнорируем ВСЕ коллизии нашей же сущности (балласт, другие сокеты)
		if other_entity == my_entity:
			continue
			
		# 3. Игнорируем гостов и объекты, которые сейчас находятся в режиме Drag
		if other_entity and (other_entity.has_comp(C_Ghost) or other_entity.has_comp(C_Drag)):
			continue
			
		# Если мы дошли сюда, значит в сокете лежит стабильный, чужой рельс!
		return true
		
	return false





# Хелпер подъема по дереву до Entity (аналогично c_blockable)
func _find_entity_from_collider(node: Node) -> Entity:
	var current = node
	while current:
		if current is Entity:
			return current
		current = current.get_parent()
	return null



# Рекурсивный поиск всех Path3D в визуале
func _find_paths_recursive(node: Node) -> Array[Path3D]:
	var result: Array[Path3D] = []
	if node is Path3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_paths_recursive(child))
	return result
	
	

# XX claude-terra ===== Террейн: снап по yaw, магнит, flex =====

## Ориентирует Area3D сокета: -Z смотрит наружу вдоль dir (dir может иметь наклон по y)
func _orient_area(area: Area3D, _pos: Vector3, dir: Vector3) -> void:
	area.position = _pos
	if dir.is_zero_approx():
		return
	var z_axis = -dir.normalized()
	var x_axis = Vector3.UP.cross(z_axis).normalized()
	# Защита от коллинеарности (если сокет смотрит ровно в небо)
	if x_axis.is_zero_approx():
		x_axis = Vector3.RIGHT.cross(z_axis).normalized()
	var y_axis = z_axis.cross(x_axis).normalized()
	area.transform.basis = Basis(x_axis, y_axis, z_axis)


## Поза Entity для стыка сокетов (только yaw + позиция) или null, если излом больше допуска.
## s_socket - стоящий сокет, d_socket - мой (локальный, базис Entity = только yaw)
func _snap_transform(s_socket: Area3D, d_socket: Area3D) -> Variant:
	snap_reject_reason = ""
	var t_dir := -s_socket.global_basis.z    # "наружу" у стоящего сокета
	var d_dir := -d_socket.basis.z           # "наружу" у моего, локально
	# Стык гладкий, если наружные векторы почти противоположны и по вертикали
	var kink := absf(rad_to_deg(asin(clampf(t_dir.y, -1.0, 1.0)) + asin(clampf(d_dir.y, -1.0, 1.0))))
	if kink > Global.settings.joint_kink_max_deg:
		snap_reject_reason = "kink"
		return null
	var want := Vector2(-t_dir.x, -t_dir.z)
	var have := Vector2(d_dir.x, d_dir.z)
	if want.length_squared() < 0.0001 or have.length_squared() < 0.0001:
		return null
	# поворот вокруг Y на угол a меняет угол вектора в (x,z) на -a
	var yaw := have.angle() - want.angle()
	var b := Basis(Vector3.UP, yaw)
	var xf := Transform3D(b, s_socket.global_position - b * d_socket.position)
	# XX claude-terra снап, при котором трак уходит под землю, отклоняем (пандус вниз к траку на столе: развернуть на 180°)
	var path := get_comp(C_Path) as C_Path
	if path and path.underground_depth(xf) > Global.settings.underground_tolerance:
		snap_reject_reason = "underground"
		return null
	return xf


# XX claude-terra 13.1.4
## Отметить или снять отказ снапа к чужому сокету. Пока есть хоть один отказ, на сущности висит C_Invalid.
## d_socket нужен только при отметке: если сокеты уже разошлись (ждали физкадр), отказ не ставим
func _set_snap_rejected(other: Area3D, d_socket: Area3D, on: bool) -> void:
	if entity.has_comp(C_FlexShape):
		return   # у flex свой C_Invalid (форма, пределы), не мешаем
	if on:
		if d_socket == null or not is_instance_valid(other) or not d_socket.overlaps_area(other):
			return
		if not _snap_rejected.has(other):
			_snap_rejected.append(other)
	else:
		_snap_rejected.erase(other)
	# сокеты соседа могли удалиться без сигнала выхода
	_snap_rejected = _snap_rejected.filter(
		func(a): return is_instance_valid(a) and not a.is_queued_for_deletion())
	var bad := not _snap_rejected.is_empty()
	if bad and not entity.has_comp(C_Invalid):
		entity.add_component(C_Invalid.new())
	elif not bad and entity.has_comp(C_Invalid):
		entity.remove_component(C_Invalid)
	if not bad:
		snap_reject_reason = ""
	_update_reject_hint()


## Метка над призраком или траком в драге: почему снап отклонён и что делать. Для подземного положения это разворот
## на 180° (пандус вниз к траку на столе: стыковать нижним концом). Q/E крутят на ROT_STEP = 45°, значит 4 нажатия
func _update_reject_hint() -> void:
	if _snap_rejected.is_empty() or snap_reject_reason == "":
		if _hint:
			_hint.queue_free()
			_hint = null
		return
	if _hint == null:
		_hint = Label3D.new()
		_hint.name = "SnapRejectHint"
		_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_hint.fixed_size = true
		_hint.no_depth_test = true
		_hint.pixel_size = 0.0015
		_hint.font_size = 32
		_hint.outline_size = 8
		_hint.modulate = Color(1.0, 0.35, 0.35)
		_hint.position = Vector3(0.0, 6.0, 0.0)
		entity.add_child(_hint)
	if snap_reject_reason == "underground":
		_hint.text = "Под землёй: разверни на 180° (Q/E ×4)"
	else:
		_hint.text = "Излом по вертикали больше %.0f°" % Global.settings.joint_kink_max_deg


## Есть ли отказ снапа (DragTool: на дропе такой трак возвращается на место)
func has_snap_rejection() -> bool:
	return not _snap_rejected.is_empty()


## Сброс отказов, например после драга
func clear_snap_rejection() -> void:
	_snap_rejected.clear()
	snap_reject_reason = ""
	_update_reject_hint()
	if not entity.has_comp(C_FlexShape) and entity.has_comp(C_Invalid):
		entity.remove_component(C_Invalid)


## Публичная проверка для вертикального магнита: сокет свободен (нет стабильного соседа)
func is_socket_free(area: Area3D) -> bool:
	return not _is_socket_occupied(area)


## Форма пути изменилась (flex): переставляем СУЩЕСТВУЮЩИЕ Area3D, не пересоздаем.
## Пересоздание сбрасывает overlaps (угроза Infinite Rebuild Loop из TDD).
func on_curve_changed(_data: Dictionary) -> void:
	var path_comp := get_comp(C_Path) as C_Path
	if not path_comp or not path_comp.curve or not path_comp.path_node or sockets.size() < 2:
		return
	if path_comp.is_multi_route():
		return   # XX claude-switch: форма стрелки статична, сокеты не двигаем (3 штуки, не 2)
	var c := path_comp.curve
	var length := c.get_baked_length()
	var xf := path_comp.path_node.transform
	var p0 := c.sample_baked(0.0)
	var p1 := c.sample_baked(length)
	# наружу: в начале назад по касательной, в конце вперед
	var d0 := -(-c.sample_baked_with_rotation(0.0).basis.z).normalized()
	var d1 := (-c.sample_baked_with_rotation(length).basis.z).normalized()
	var ends := [[p0, d0], [p1, d1]]
	for i in 2:
		sockets[i].pos = ends[i][0]
		sockets[i].out_dir = ends[i][1]
		#_orient_area(sockets[i].socket, xf * ends[i][0], ends[i][1])
		_orient_area(sockets[i].socket, xf * ends[i][0] + Vector3(0.0, _surface_lift(), 0.0), ends[i][1])

# XX claude-terra
## Включает/выключает конкретный сокет (index 0 начало, 1 конец, -1 все). Шлет flex-призрак:
## пока ставится начало/тянется конец, сокеты не должны сами снапить призрак.
func on_socket_enabled(data: Dictionary) -> void:
	var idx: int = data.get("index", -1)
	var on: bool = data.get("enabled", true)
	for k in sockets.size():
		if idx >= 0 and k != idx:
			continue
		var a: Area3D = sockets[k].socket
		a.set_deferred("monitoring", on)
		a.set_deferred("monitorable", on)

## Сокеты на поверхности катания, не у основания: стык двух стилей выравнивается по рельсам
func _surface_lift() -> float:
	var p := get_comp(C_Path) as C_Path
	return p.head_height() if p else 0.0
	
## ==== МАРКЕРЫ ====

# Шарик 
func _add_marker(_node, _color = Color.RED):
	if not Global.debug_markers:
		return
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
	if not Global.debug_markers:
		return
	var marker := MeshInstance3D.new()

	var cone := CylinderMesh.new()
	cone.top_radius = 0.01
	cone.bottom_radius = 0.12
	cone.height = 2
	marker.mesh = cone
	
	#marker.position = _p.transform * (_pos) # Если _p закидываем в функцию
	marker.position = _pos
	marker.position.y += 0.8
	# материал
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _color
	mat.emission_enabled = true
	marker.material_override = mat
	
	entity.add_child(marker)
