class_name C_Visual extends Component

###################################
## Логика. Обработка файла сцены объекта
###################################

#TODO  Тут надо будет еще поработать и перепроверить, потому что как то сыро, другие компоненты лезут в сцену (C_Path, C_Socked). Возможно, это работа этого компонента - перекидывать невизуалы в ноду  ентити.

var instance: Node3D 
var scene: PackedScene
var settings: VisualStateSettings

# Массив состояний, которые реально влияют на графику
#var VISUAL_STATES = [C_Ghost, C_Blocked, C_Selected, C_Hovered]

var mesh_nodes: Array[MeshInstance3D] 

## Массив статикбоди сцены и их collision layers
var area_nodes: Dictionary [CollisionObject3D, int] 

#var blocked_material #  врем




## Вызов из ентити при создании комп
func on_added():
	instance = scene.instantiate() # Создаем сцену
	entity.add_child(instance)

	# Осталось пока
	_collect_meshes()
	_collect_collision_nodes()



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
	elif is_power_view_active: # <--- Включаем слой Power
		_set_power_view()
	else:
		_reset()




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
		mesh.set_material_overlay( settings.ghost_material)



func _set_selected(): 
	# Для меша контур
	for mesh in mesh_nodes: 
		mesh.set_material_overlay( settings.selected_material)
	
	# статик в слой 11 (selected)
	for coll in area_nodes:
	# ВАЖНО: Меняем слой ТОЛЬКО если он реально отличается!
	# Это спасает от перезапуска физики и спама body_exited
		if coll.collision_layer != (1 << 10):
			coll.collision_layer = 1 << 10



func _set_hovered(): 
	for mesh in mesh_nodes: 
		mesh.set_material_overlay( settings.hover_material)



func _set_blocked():
	for mesh in mesh_nodes: 
		mesh.set_material_overlay(settings.blocked_material) 



func _reset(): 
	for mesh in mesh_nodes: 
		mesh.set_material_overlay( null)
		
	# статик в родной слой (трак, вагон и тд)
	for coll in area_nodes:
		var original_layer = area_nodes[coll]
		if coll.collision_layer != original_layer:
			coll.collision_layer = original_layer



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
var is_power_view_active: bool = false
var power_materials: Dictionary = {} # Кэш материалов для контуров, чтобы не плодить их на каждый рельс

# Слушаем событие от шины Entity
func on_power_view_changed(data: Dictionary):
	is_power_view_active = data.active
	update_visual()


func _set_power_view():
	var power_comp = get_comp(C_PowerTrack)
	if not power_comp:
		_reset() # Если это дерево или домик без электрики
		return

	var cid = power_comp.contour_id
	var volt = power_comp.voltage
	
	# Получаем или создаем уникальный материал для этого контура
	var mat = _get_power_material(cid, volt)
	
	for mesh in mesh_nodes:
		mesh.set_material_overlay(mat)

# Хелпер для материалов
func _get_power_material(cid: int, voltage: float) -> Material:
	# Здесь ты берешь базовый шейдер электрики и настраиваешь параметры (Albedo, UV-scroll speed)
	# в зависимости от номера контура и напряжения.
	return settings.power_material
	
	pass
