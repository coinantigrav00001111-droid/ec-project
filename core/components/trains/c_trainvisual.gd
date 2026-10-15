class_name C_TrainVisual extends C_Visual

###################################
## Логика. Обработка файла сцены вагона
###################################

##TODO  корневая нода у Вагона  RigidBody3D, поэтому instance можно назвать соответственно. Если не полетит все в контроллерах

## За перемещение физического тела отвечает кинематикс, у него есть ссылка на него.
## Строит вагон согласно данным Identity - WagonConfig

var rb: RigidBody3D # Ссылка на наш физический кузов

const WHEEL_SHADER := preload("res://core/visual/materials/shader_wheel01_material.tres")

# Массив нод с коллизиями
var collision_nodes: Array[CollisionObject3D] 

var bogie_configs: Array[BogieConfig] = []

var bogie_nodes: Array[Node3D] = []

var wheel_nodes: Array[Dictionary] = [] # все колеса {'wheel_node', 'radius'}


# XX claude
func _on_instance_ready() -> void:
	rb = instance as RigidBody3D
	_collect_collision_nodes()
	_build_bogies()          # твой нынешний цикл по bogie_configs
	
##TODO  Если захочешь подсвечивать и их, пересобирай mesh_nodes после _build_bogies(), но тогда придётся исключить WheelPairMesh из _set_overlay, иначе выделение затрёт overlay колёс. Оставь комментарий в коде, чтобы потом не споткнуться.	

## on_added() НЕ переопределяем — базовый C_Visual.on_added()
## уже создаёт instance, собирает меши и вызывает _on_instance_ready().


# XX claude функция вместо скрипта в on_added()
func _build_bogies():
	# достраиваем боги
	bogie_configs = get_comp(C_Identity).get_config('bogie_configs')
	var offset_mesh_y = get_comp(C_Identity).get_config('offset_mesh_y')
	
	for bogie in bogie_configs: 
		# 1. Создаем сцену боги
		var b_scene = bogie.scene.instantiate() 
		## моя‼️Замена b_offset на b_offset_z
		b_scene.position.y = bogie.wheel_pair_position.y  # У боги своя независимая позиция в конфиге
		b_scene.position.z = bogie.b_offset_z  # У боги своя независимая позиция в конфиге
		
		# 2. Добавляем 1 колесо
		var wp_z = bogie.wheel_pair_position.z 
		var wp_scene = bogie.wheel_pair_scene.instantiate() # Создаем сцену колеса
		b_scene.add_child(wp_scene)
		wp_scene.position.z = wp_z # Смещение вперед\назад
		## моя‼️Замена b_offset на b_offset_z
		wheel_nodes.append({'wheel_node':wp_scene, 'radius': bogie.wheel_pair_position.y} )
		
		# 3. Двухосная тележка?: добавляем еще колесо
		## XX claude тележка??
		#if wp_z > abs(0.001)
		if abs(wp_z) > 0.001:
			wp_scene = bogie.wheel_pair_scene.instantiate() # Создаем сцену колеса
			b_scene.add_child(wp_scene)
			wp_scene.position.z = -wp_z # Смещение вперед\назад
			# В массив колес добаляем колесо и радиус
			## моя‼️Замена b_offset на b_offset_z
			wheel_nodes.append({'wheel_node':wp_scene, 'radius': bogie.wheel_pair_position.y})

		# 4. Перестраиваем коллизию боги c колесами к вагону
		var bg_collision = CollisionShape3D.new()
		var sh = BoxShape3D.new()
		# установка размеров коллизии боги
		sh.size = Vector3( 2.02, 
						bogie.wheel_pair_position.y * 2.0, # Диаметр колеса без реборды
						(bogie.wheel_pair_position.z + bogie.wheel_pair_position.y) * 2.0 # расстояние между центрами + радиусы обоих колес
						)
		bg_collision.shape = sh
		bg_collision.position = b_scene.position # коллизию в точку боги
		instance.add_child(bg_collision)
		bg_collision.name = 'BogieCollisionShape3D_01'

		instance.add_child(b_scene) # боги и колеса
		b_scene.name = 'Bogie_01'

		# Ноду добавляем в массив. Дальше им занимается C_Bogie 
		bogie_nodes.append(b_scene)
		
	#INFO  Шейдер на колеса
	for wheel in wheel_nodes:
			var _mesh = wheel.wheel_node.get_node('WheelPairMesh')
			_mesh.set_material_overlay(WHEEL_SHADER)
			
	#поднимаем кузов
	var wagon_collision = instance.get_node('WagonCollisionShape3D')
	wagon_collision.position.y = mesh_nodes[0].position.y + wagon_collision.shape.size.y / 2
	mesh_nodes[0].position.y = offset_mesh_y # из вагон-конфига



# XX claude замена
func on_select_layer(_data) -> void:
	if not rb: return
	if _data.enabled:
		rb.collision_layer = Global.active_layers(['ghost'])
		rb.collision_mask = Global.active_layers(['ground','tracks','trains'])
	else:
		rb.collision_layer = Global.active_layers(['trains'])
		rb.collision_mask = Global.active_layers(['ground','tracks','trains','ghost'])
		


## -----Сбор нод с коллизиями (Area3D, StaticBody3D, RigidBody3D)-------

func _collect_collision_nodes():
	collision_nodes = []
	_find_collisions(instance)


## Заполняем массив коллизий
func _find_collisions(node): 
	if node is CollisionObject3D: 
		collision_nodes.append(node)

	for child in node.get_children(): 
		_find_collisions(child)
		
