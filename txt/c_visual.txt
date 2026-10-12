class_name C_Visual extends Component

###################################
## База визуала. Инстанс сцены, меши, оверлеи состояний.
## Наследники: C_TrackVisual, C_TrainVisual
###################################
# В базу уходит всё, что у трека и трейна совпадало: инстанс сцены, меши, оверлеи состояний (ghost/selected/hovered/blocked), материалы. Использую шаблонный метод: база строит инстанс, а наследник добавляет своё через хук _on_instance_ready(). Так не нужно вызывать super.on_added().

var instance: Node3D
var scene: PackedScene
var visual_settings: VisualStateSettings
var mesh_nodes: Array[MeshInstance3D] = []


func on_added() -> void:
	instance = scene.instantiate() as Node3D
	entity.add_child(instance)
	_collect_meshes()
	_on_instance_ready()   # хук для наследников


## Переопределяется в наследниках
func _on_instance_ready() -> void:
	pass


# --- Реакция на состояния ---
func on_component_added(_type: Script) -> void:
	update_visual()

func on_component_removed(_type: Script) -> void:
	update_visual(_type)


## Наследник может расширить: super(_removing_type) + свой блок
func update_visual(_removing_type: Script = null) -> void:
	if has_comp(C_Blocked) and _removing_type != C_Blocked:
		_set_overlay(visual_settings.blocked_material)
	elif has_comp(C_Ghost) and _removing_type != C_Ghost:
		_set_overlay(visual_settings.ghost_material)
	elif has_comp(C_Selected) and _removing_type != C_Selected:
		_set_overlay(visual_settings.selected_material)
	elif has_comp(C_Hovered) and _removing_type != C_Hovered:
		_set_overlay(visual_settings.hover_material)
	else:
		_set_overlay(null)


func _set_overlay(mat: Material) -> void:
	for mesh in mesh_nodes:
		mesh.set_material_overlay(mat)


# --- Меши ---
func _collect_meshes() -> void:
	mesh_nodes = []
	_find_meshes(instance)

func _find_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		mesh_nodes.append(node)
	for child in node.get_children():
		_find_meshes(child)


func get_visual_offset() -> Vector3:
	return Vector3.ZERO


func get_center_world() -> Vector3:
	if mesh_nodes.is_empty():
		return instance.global_position
	var local_center := mesh_nodes[0].get_aabb().size * 0.5
	local_center.x = 0
	local_center.y = 0
	return instance.to_global(local_center)


## Вставляет материал в конец цепочки next_pass
func apply_material(mesh_instance: MeshInstance3D, _material: Material) -> void:
	var current_mat = mesh_instance.get_active_material(0)
	if not current_mat:
		return
	while current_mat.next_pass != null:
		if current_mat.next_pass == _material:
			return
		current_mat = current_mat.next_pass
	current_mat.next_pass = _material
