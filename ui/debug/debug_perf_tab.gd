class_name DebugPerfTab extends DebugTab

###########################
## Вкладка «Perf»: fps, вызовы отрисовки, физика (U14)
###########################
## Читает Performance-мониторы Godot. Обновляется 10 раз в секунду, пока вкладка открыта.

## Строки: подпись -> Label со значением
var _values: Dictionary = {}


func _init() -> void:
	name = &"Perf"
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 16)
	add_child(grid)
	for title in ["FPS", "Кадр (process), мс", "Физика (physics), мс", "Вызовы отрисовки", "Объекты в кадре",
			"Примитивы в кадре", "Активные тела физики", "Пары столкновений", "Острова физики",
			"Узлов в дереве", "Видеопамять, МБ", "V-Sync"]:
		var l := Label.new()
		l.text = title
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		var v := Label.new()
		v.size_flags_horizontal = Control.SIZE_SHRINK_END
		grid.add_child(v)
		_values[title] = v


func refresh() -> void:
	_put("FPS", str(Engine.get_frames_per_second()))
	_put("Кадр (process), мс", "%.2f" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0))
	_put("Физика (physics), мс", "%.2f" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0))
	_put("Вызовы отрисовки", str(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))))
	_put("Объекты в кадре", str(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))))
	_put("Примитивы в кадре", str(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))))
	_put("Активные тела физики", str(int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))))
	_put("Пары столкновений", str(int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))))
	_put("Острова физики", str(int(Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT))))
	_put("Узлов в дереве", str(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))))
	_put("Видеопамять, МБ", "%.1f" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0))
	_put("V-Sync", "вкл" if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED else "выкл")


func _put(title: String, value: String) -> void:
	(_values[title] as Label).text = value
