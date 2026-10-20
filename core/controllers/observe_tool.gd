class_name ObserveTool extends Node

##########################
## Инструмент режима Observe
##########################
## Без выбора, ховера и драга. Клик по вагону включает follow-камеру (C_CameraTarget), Esc выключает.
## Это каркас S1, полноценные Follow / POV / Orbit делаются в S9.

var controller: ToolController

var follow_target: Entity
var lmb_start_pos := Vector2.ZERO


func enter():
	follow_target = null


## При выходе из режима камеру отдаем обратно на Gimbal
func exit(_to_drag: bool = false):
	_release_follow()


func process_tick(_delta):
	$"../../UI/ModeLabel".text = name


func handle_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_release_follow()
		return

	# Короткий клик ЛКМ (не драг): выбираем вагон. Камерой управляет Gimbal
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			lmb_start_pos = event.position
		elif lmb_start_pos.distance_to(event.position) < 5:
			_pick_follow()


func _pick_follow() -> void:
	var hit = controller.get_mouse_ray(Global.active_layers(['trains']))
	if hit.is_empty() or not hit.collider:
		return   # клик в пустоту follow не сбрасывает, для этого Esc
	var e := _find_entity(hit.collider)
	if e == null or not e.has_comp(C_CameraTarget):
		return
	if e == follow_target:
		return
	_release_follow()
	follow_target = e
	follow_target.send_event("on_wagon_camera_selected", {"selected": true})


func _release_follow() -> void:
	if is_instance_valid(follow_target):
		follow_target.send_event("on_wagon_camera_selected", {"selected": false})
	follow_target = null


func _find_entity(node) -> Entity:
	var curr = node
	while curr:
		if curr is Entity:
			return curr
		curr = curr.get_parent()
	return null
