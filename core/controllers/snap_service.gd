class_name SnapService extends Node

#########################
## 💡‼️Атавизм. Больше не используется!
#########################


@export var snap_radius := 1.5
@export var entities_root: Node3D

func find_snap(dragging_entity: Entity, _mouse_pos: Vector3) -> Dictionary:
	# Если сокеты есть, идем дальше
	var c_socket = dragging_entity.get_comp(C_Socket)
	if not c_socket: 
		return {"is_snapped": false}
	
	var best_snap = {
		"is_snapped": false,
		"target_socket": {
			"position": 0,
			"direction":0
		},
		"dragging_socket": 0
	}
					
	return best_snap
