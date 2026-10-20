class_name CameraBounds extends Node

########################
## Подаёт Gimbal границы комнаты (RoomConfig.bounds).
## Сами ограничения живут внутри Gimbal (на целевом состоянии), здесь только связка:
## комната скрыта (кнопка Room) -> границы выключаются, показана -> включаются.
########################

var gimbal: Gimbal


func _ready() -> void:
	gimbal = get_node_or_null("/root/GameRoot/Gimbal") as Gimbal
	if gimbal == null:
		return
	# RoomRoot встаёт в группу в своём _ready, ждём кадр
	await get_tree().process_frame
	var room := get_tree().get_first_node_in_group(&"room_root") as RoomBuilder
	if room == null:
		gimbal.set_bounds_enabled(false)
		return
	gimbal.set_bounds(room.get_bounds(), true)
	room.room_visible_changed.connect(func(on: bool): gimbal.set_bounds_enabled(on))
