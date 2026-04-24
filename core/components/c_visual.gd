class_name C_Visual extends Component

var instance: Node3D 
var scene: PackedScene
var settings: VisualStateSettings

var mesh_nodes: Array[MeshInstance3D] 

## Массив статикбоди сцены и их collision layers
var static_nodes: Dictionary [CollisionObject3D, int] 

var blocked_material #  врем


## Вызов из ентити при создании комп
func on_added():
	instance = scene.instantiate() # Создаем сцену
	entity.add_child(instance)
	update_visual() #- лишний при создании сущн, а при добавлении комп нужен
	# Осталось пока
	_collect_meshes()
	_collect_statics()


func on_component_added(_type: Script):
	# Если на сущность "нацепили" состояние призрака или блокировки
	#if type == C_Ghost or type == C_Blocked or type == C_Selected or type == C_Hovered:
		update_visual()
		
func on_component_removed(type):
	# Смотрит удаляемый комп, если увидит, то сбросит в нормальный вид
	update_visual(type)


"""  Остановка на блокед. Сам комп сделан, но когда сработка - нет. см также Таски.
	вот тут и проверяем!! """
func _on_component_changed():
	print('cha')
	var blocked = entity.get_comp(C_Blocked)
	if blocked and blocked.is_blocked:
		_set_blocked() 
	else:
		_reset()
		
		
## ========= OLD =====================

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



## -----STATICS-------

func _collect_statics():
	static_nodes = {}
	_find_statics(instance)



## Заполняем словарь {статик, его лэйер}
func _find_statics(node): 
	if node is CollisionObject3D: 
		static_nodes[node] = node.collision_layer 

	for child in node.get_children(): 
		_find_statics(child)



###############################
# Смотрит удаляемый комп, если увидит, то сбросит в нормальный вид
func update_visual(_removing_type: Script = null): 
	#print('c-visual update_visual')
	if entity.has_comp(C_Ghost):
		_set_ghost()
	elif entity.has_comp(C_Blocked): 
		_set_blocked() 
	elif entity.has_comp(C_Selected) and _removing_type != C_Selected:
		_set_selected() 
	elif entity.has_comp(C_Hovered) and _removing_type != C_Hovered:
		_set_hovered() 
	else: 
		_reset()



func _set_ghost():
	for mesh in mesh_nodes:
		mesh.set_material_overlay( settings.ghost_material)




func _set_selected(): 
	# Для меша контур
	for mesh in mesh_nodes: 
		mesh.set_material_overlay( settings.selected_material)
	
	# статик в слой 11 (selected)
	for coll in static_nodes:
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
	for coll in static_nodes:
		coll.collision_layer = static_nodes[coll] 



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
