class_name InfoTransformTab extends InfoTab

###########################
## Вкладка «Положение»: координаты, поворот, «на траке»
###########################
## Узлы в info_panel.tscn (TransformTab). Тюнинг физики вагона и скорость переехали в DebugPanel (U14),
## спидометр и его галочка убраны до U23 (ATTN_17 §17.x «Инструменты-сущности»).

const ON_TRACK_COLOR := Color(0.4, 1.0, 0.5)

var _chassis: C_Chassis


func _on_bind() -> void:
	components_changed()
	refresh()


func _on_unbind() -> void:
	_chassis = null


func components_changed() -> void:
	if target == null:
		return
	_chassis = target.get_comp(C_Chassis) as C_Chassis


func refresh() -> void:
	if target == null:
		return
	var pos := target.global_position
	var rot := target.rotation_degrees
	_n("PosLabel").text = "(%.2f, %.2f, %.2f)" % [pos.x, pos.y, pos.z]
	_n("RotLabel").text = "(%.2f, %.2f, %.2f)" % [rot.x, rot.y, rot.z]
	_set_on_track()


## «На траке»: да (зеленым) или нет (цвет по умолчанию). У объектов без шасси прочерк
func _set_on_track() -> void:
	var label := _n("OnTrackLabel") as Label
	if _chassis == null:
		label.text = "-"
		label.remove_theme_color_override(&"font_color")
	elif _chassis.is_on_rails:
		label.text = "Да"
		label.add_theme_color_override(&"font_color", ON_TRACK_COLOR)
	else:
		label.text = "Нет"
		label.remove_theme_color_override(&"font_color")
