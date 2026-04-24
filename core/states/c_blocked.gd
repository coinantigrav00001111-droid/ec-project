class_name C_Blocked extends Component

var is_blocked := false
var area: Area3D
var overlaps := 0 

func on_added():
	# Берем первую Area3D из визуала (балласт)
	var visual = entity.get_comp(C_Visual)
	if visual and not visual.static_nodes.is_empty():
		area = visual.static_nodes.keys()[0] 
		area.body_entered.connect(_on_enter)
		area.body_exited.connect(_on_exit)
		# Проверяем на старте (вдруг мы уже в чем-то?)
		_check_initial_overlaps()

func on_removed():
	if area:
		area.body_entered.disconnect(_on_enter)
		area.body_exited.disconnect(_on_exit)

func _check_initial_overlaps():
	# Важно: Area3D может уже стоять внутри чего-то при спавне
	for body in area.get_overlapping_bodies():
		_on_enter(body)

func _on_enter(body):
	if _should_block(body):
		overlaps += 1
		_update_state()

func _on_exit(body):
	if _should_block(body):
		overlaps -= 1
		_update_state()

func _update_state():
	var new_state = overlaps > 0
	if is_blocked != new_state:
		is_blocked = new_state
		entity._notify_components_changed()

func _should_block(body):
	var ent = find_entity_from_collider(body)
	if not ent or ent == entity: return false # Игнорим себя
	if ent.has_comp(C_Ghost): return false    # Игнорим гостов
	return true
	
	## Из коллайдера поднимает его Entity
func find_entity_from_collider(node: Node) -> Entity:
	
	var current = node
	while current:
		if current is Entity:
			return current
		current = current.get_parent()
	
	return null
	
