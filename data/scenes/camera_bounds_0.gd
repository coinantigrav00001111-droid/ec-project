class_name CameraBounds0 extends Node

########################
## Держит камеру Gimbal внутри границ комнаты (RoomConfig.bounds), не трогая код Gimbal.
########################
## Если камера вышла за границы, сдвигаем весь Gimbal на разницу: поворот и зум остаются как были.
## Когда комната скрыта (кнопка Room), ограничение выключается.
## Если у Gimbal своя целевая позиция с lerp и он сам тянет себя обратно, clamp надо перенести внутрь Gimbal.

var gimbal: Node3D
var cam: Camera3D
var bounds := AABB(Vector3(-230.0, 3.0, -180.0), Vector3(460.0, 190.0, 360.0))
var active := true


func _ready() -> void:
	process_priority = 100   # после Gimbal
	gimbal = get_node_or_null("/root/GameRoot/Gimbal")
	if gimbal:
		cam = gimbal.get_node_or_null("Elevation/Camera")
	# RoomRoot встаёт в группу в своём _ready, ждём кадр
	await get_tree().process_frame
	var room := get_tree().get_first_node_in_group(&"room_root") as RoomBuilder
	if room:
		bounds = room.get_bounds()
		room.room_visible_changed.connect(func(on: bool): active = on)
	else:
		active = false


func _process(_delta: float) -> void:
	if not active or not is_instance_valid(cam) or not is_instance_valid(gimbal):
		return
	var p := cam.global_position
	var q := p.clamp(bounds.position, bounds.end)
	if q != p:
		gimbal.global_position += q - p
