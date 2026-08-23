class_name C_Visual extends Component

###################################
## Логика. Обработка файла сцены объекта
###################################

#TODO  Тут надо будет еще поработать и перепроверить, потому что как то сыро, другие компоненты лезут в сцену (C_Path, C_Socked). Возможно, это работа этого компонента - перекидывать невизуалы в ноду  ентити.

var instance: Node3D 
var scene: PackedScene
var visual_settings: VisualStateSettings

var mesh_nodes: Array[MeshInstance3D] 

# Массив статикбоди сцены и их collision layers
var area_nodes: Dictionary [CollisionObject3D, int] 

#--- POWER Layer ---
var is_power_view_active: bool = false
#var power_shader: Shader = preload("res://core/visual/materials/shader_power_track.gdshader") 
# Индекс слота металла. Обычно это 0 или 1, в зависимости от порядка материалов в Blender.
var rail_surface_index :int = 1
# Кэш материалов: ключ - contour_id, значение - ShaderMaterial
static var power_materials_cache: Dictionary = {}
# Палитра цветов для контуров (0 - ошибка/нейтралка, 1..MAX - рабочие)

#const CONTOUR_COLORS = { # перенес в визуал сетиинги
	#0: Color(0.5, 0.5, 0.5), # Серый (нет контура)
	#1: Color(0.0, 0.8, 1.0), # Голубой
	#2: Color(0.72, 0.666, 0.313, 1.0), # замена Оранжевый в резерве
	#3: Color(0.2, 1.0, 0.2), # Салатовый
	#4: Color(0.7, 0.2, 0.9), # Фиолетовый
	#5: Color(1.0, 0.4, 0.8), # Розовый (Маджента)
	#6: Color(0.0, 0.6, 0.6), # Бирюзовый / Морская волна
	#7: Color(0.8, 0.6, 1.0), # Сиреневый / Лаванда
	#8: Color(0.5, 0.3, 0.1), # Коричневый
	#9: Color(0.357, 0.6, 0.071, 1.0), # Белый / Светло-кремовый
	#10: Color(0.3, 0.0, 0.5), # Индиго / Глубокий фиолетовый
#}


## Вызов из ентити при создании комп
func on_added():
	instance = scene.instantiate() # Создаем сцену
	entity.add_child(instance)

	# Осталось пока
	_collect_meshes()
	_collect_collision_nodes()
	
	## XX баги с обновлением клипа
	#PGM.grid_recalculated.connect(update_visual)


func on_component_added(_type: Script):
	#if _type in VISUAL_STATES:
		update_visual()  # нужный



func on_component_removed(_type: Script):
	# Смотрит удаляемый комп, если увидит, то сбросит в нормальный вид
	#if _type in VISUAL_STATES:
	update_visual(_type)  # нужный



###############################
## Смотрит удаляемый комп, если увидит, то сбросит в нормальный вид

func update_visual(_removing_type: Script = null): 
	if has_comp(C_Blocked) and _removing_type != C_Blocked:
		_set_blocked() 
	elif has_comp(C_Ghost) and _removing_type != C_Ghost:
		_set_ghost()
	elif has_comp(C_Selected) and _removing_type != C_Selected:
		_set_selected() 
	elif has_comp(C_Hovered) and _removing_type != C_Hovered:
		_set_hovered()
	else:
		_reset_overlays() # Сбрасываем ТОЛЬКО глобальные оверлеи
		
	# --- БЛОК 2: Слой электрики (Surface Override) ---
	if is_power_view_active:
		_set_power_view()
	else:
		_reset_power_view() # Сбрасываем ТОЛЬКО материал в слоте рельса

	

# Очищает глобальную пленку (Hover, Selected, Ghost и т.д.)
func _reset_overlays():
	for mesh in mesh_nodes:
		mesh.set_material_overlay(null)




func get_visual_offset() -> Vector3:
	# Вместо математики AABB, лучше просто возвращать Vector3.ZERO, 
	# если мы хотим держать рельс за его начало (Socket 0).
	return Vector3.ZERO



## Центр ентити по первому мешу
func get_center_world() -> Vector3:
	var mesh = mesh_nodes[0]
	var aabb = mesh.get_aabb()
	var local_center = aabb.size*0.5
	# По Х меш не смещен, поэтому его в 0
	local_center.x = 0 
	local_center.y = 0 
	return instance.to_global(local_center)	



## -----MESH-------

func _collect_meshes():
	mesh_nodes = [] 
	_find_meshes(instance) 


func _find_meshes(node): 
	if node is MeshInstance3D: 
		mesh_nodes.append(node)

	for child in node.get_children(): 
		_find_meshes(child)



## -----Сбор нод с коллизиями (Area3D и StaticBody3D)-------

func _collect_collision_nodes():
	area_nodes = {}
	_find_collisions(instance)


## Заполняем словарь {статик, его лэйер}
func _find_collisions(node): 
	if node is CollisionObject3D: 
		area_nodes[node] = node.collision_layer 

	for child in node.get_children(): 
		_find_collisions(child)


## ---- SET по СТЕЙТАМ ----

func _set_ghost():
	for mesh in mesh_nodes:
		mesh.set_material_overlay( visual_settings.ghost_material)



func _set_selected(): 
	# Для меша контур
	for mesh in mesh_nodes: 
		mesh.set_material_overlay(visual_settings.selected_material)
	
	#FIXME Исправил, гост слой непонятно зачем нужен? статик в слой 11 (selected)
	#for coll in area_nodes:
	# ВАЖНО: Меняем слой ТОЛЬКО если он реально отличается!
	# Это спасает от перезапуска физики и спама body_exited
		#if coll.collision_layer != (1 << 10):
			#coll.collision_layer = 1 << 10



func _set_hovered(): 
	for mesh in mesh_nodes: 
		mesh.set_material_overlay(visual_settings.hover_material)



func _set_blocked():
	for mesh in mesh_nodes: 
		mesh.set_material_overlay(visual_settings.blocked_material) 


# не исп.
func _reset(): 
	print('c_visual-reset')
	#for mesh in mesh_nodes: 
		#mesh.set_material_overlay( null)
		#
	## статик в родной слой (трак, вагон и тд)
	#for coll in area_nodes:
		#var original_layer = area_nodes[coll]
		#if coll.collision_layer != original_layer:
			#coll.collision_layer = original_layer
	pass


## ----  МАТЕРИАЛЫ ----

## Вставляет материал в последний next_pass 
func apply_material(mesh_instance: MeshInstance3D, _material: Material):
	# 1. Берем основной материал (индекс 0 для примера)
	var current_mat = mesh_instance.get_active_material(0)
	
	if not current_mat:
		return # Если материала нет вообще
		
	# 2. Идем по цепочке next_pass до самого последнего материала
	while current_mat.next_pass != null:
		# Если наш шейдер уже там есть, выходим, чтобы не дублировать
		if current_mat.next_pass is StandardMaterial3D and current_mat.next_pass == _material:
			return
		current_mat = current_mat.next_pass
		
		# 3. Создаем новый слой подсветки
	#var new_mat = Material.new()
	#new_mat = _material
	# 4. Прикрепляем его в самый конец цепочки
	current_mat.next_pass = _material




func apply_shader(mesh_instance: MeshInstance3D, _shader: Shader):
	# 1. Берем основной материал (индекс 0 для примера)
	var current_mat = mesh_instance.get_active_material(0)
	
	if not current_mat:
		return # Если материала нет вообще
		
	# 2. Идем по цепочке next_pass до самого последнего материала
	while current_mat.next_pass != null:
		# Если наш шейдер уже там есть, выходим, чтобы не дублировать
		if current_mat.next_pass is ShaderMaterial and current_mat.next_pass.shader == _shader:
			return
		current_mat = current_mat.next_pass
	
	# 3. Создаем новый слой подсветки
	var highlight_mat = ShaderMaterial.new()
	highlight_mat.shader = _shader
	
	# 4. Прикрепляем его в самый конец цепочки
	current_mat.next_pass = highlight_mat



# ---- POWER LAYER ---

## 1️⃣  --- Секция логики слоя ---
# Слушаем событие от шины Entity
func on_power_view_changed(data: Dictionary):
	is_power_view_active = data.active

	update_visual()



func _set_power_view():
	var power_comp = get_comp(C_PowerTrack)
	if not power_comp:
		_reset_power_view() # Сбрасываем только ток
		return
	
	# Если узел уже вышел из дерева (при закрытии), игнорируем вызов
	if is_inside_tree(): 
		await get_tree().physics_frame
	
	var cid = power_comp.contour_id
	#var _volt = power_comp.voltage # вольтаж
	
	var _volt = PGM.power_pwm[cid].voltage if cid != 0 else 0# вольтаж
	var is_flipped = power_comp.is_flipped
	var mat = _get_or_create_power_material(cid, _volt,  is_flipped)
	
	for mesh in mesh_nodes:
	# Проверяем, есть ли у ноды сам ресурс mesh и хватает ли в нем слотов
		if mesh.mesh and mesh.mesh.get_surface_count() > rail_surface_index:
			# Накладываем шейдер ТОЛЬКО на нужный слот (рельсы)
			mesh.set_surface_override_material(rail_surface_index, mat)
		
		
		
# Отдельный сброс для слоя электрики
func _reset_power_view():
	for mesh in mesh_nodes:
		# Такая же защита при сбросе
		if mesh.mesh and mesh.mesh.get_surface_count() > rail_surface_index:
			mesh.set_surface_override_material(rail_surface_index, null)	



# --- Хелпер сборки материала ---
func _get_or_create_power_material(cid: int, _volt: float, is_flipped: bool) -> ShaderMaterial:
	
	var cache_key = str(cid) + "_" + str(is_flipped)
	#Если материал для такого состояния уже есть — возвращаем его
	if power_materials_cache.has(cache_key):
		return power_materials_cache[cache_key] 
		
	# Если нет — создаем НОВЫЙ независимый экземпляр
	var new_mat = ShaderMaterial.new()
	new_mat.shader = visual_settings.power_shader

	# Задаем базовый цвет из палитры (настроек)
	var color = visual_settings.CONTOUR_COLORS.get(cid, Color.RED) # Красный, если контур вышел за пределы палитры
	var _flip = - 1 if is_flipped else  1
	new_mat.set_shader_parameter("contour_color", color)
	new_mat.set_shader_parameter("scroll_speed", _volt * _flip * 0.01)
	power_materials_cache[cache_key] = new_mat

	return new_mat
