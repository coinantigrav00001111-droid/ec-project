class_name ObserveTool extends Node

##########################
## Инструмент режима Observe
##########################
## Без выбора, ховера и драга. Короткий клик ЛКМ по вагону отдает его ObserveCameraRig (Follow).
## Все режимы камер и Esc ведет ObserveCameraRig, здесь только выбор цели.

var controller: ToolController

var lmb_start_pos := Vector2.ZERO


func enter():
	pass


func exit(_to_drag: bool = false):
	var rig := _rig()
	if rig:
		rig.set_mode(ObserveCameraRig.Mode.NONE)


func process_tick(_delta):
	$"../../UI/ModeLabel".text = name


func handle_input(event: InputEvent):
	# Короткий клик ЛКМ (не драг): выбираем вагон. Камерой управляет Gimbal
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			lmb_start_pos = event.position
		elif lmb_start_pos.distance_to(event.position) < 5:
			_pick()


func _pick() -> void:
	var rig := _rig()
	if rig == null:
		return
	var hit = controller.get_mouse_ray(Global.active_layers(['trains']))
	if hit.is_empty() or not hit.collider:
		return   # клик в пустоту ничего не сбрасывает, для этого Esc
	var e := _find_entity(hit.collider)
	if e != null:
		rig.pick_target(e)


func _rig() -> ObserveCameraRig:
	return get_tree().get_first_node_in_group(&"observe_camera_rig") as ObserveCameraRig


func _find_entity(node) -> Entity:
	var curr = node
	while curr:
		if curr is Entity:
			return curr
		curr = curr.get_parent()
	return null
