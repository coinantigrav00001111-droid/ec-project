class_name IDraggable extends ICapability

#####################
## Контракт драга объекта
#####################

func start_drag(_hit_pos: Vector3):
	pass
func update_drag(_target_pos: Vector3, _normal: Vector3): 
	pass
func end_drag(): 
	pass
