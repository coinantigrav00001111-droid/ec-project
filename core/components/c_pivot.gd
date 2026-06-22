class_name C_Pivot extends Component

#######################
## 💡 Логика. Pivot offset к центру.
#######################
## Компонент сам переносит центр инстанса сцены в оффсет 

# Это оффсет
var offset: Vector3 = Vector3.ZERO

# Entity запускает это при создании компонента
func on_added():
	# Если визуал уже есть — применяем сразу
	_apply_to_visual()


# Если появился визуал, то по ⚡Сигналу сработает
func on_component_added(type: Script):
	if type == C_Visual:
		_apply_to_visual()



# Сдвигаем инстанс(сцену) в оффсет из сеттинга
func _apply_to_visual():
	var visual = get_comp(C_Visual)
	if visual and visual.instance:
		visual.instance.position = offset



# Изменился офсет(в C_Path например), обновляется он и инстанс
func on_offset_changed(data:Dictionary):
	offset = data.new_offset
	_apply_to_visual()
