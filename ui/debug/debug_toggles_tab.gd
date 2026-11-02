class_name DebugTogglesTab extends DebugTab

###########################
## Вкладка «Toggles»: отладочные выключатели и действия (U14)
###########################
## Выключатели читают и пишут флаги Global (и V-Sync окна). Флаги может переключить и клавиша (например, V-Sync на F8),
## поэтому refresh() возвращает галочки в синхрон с реальным состоянием.
## Старые пункты меню-заглушки: «ничего» (очистка сцены) переехал сюда кнопкой с подтверждением. Пункты «++» и
## «jolt profile» ничего не делали (код закомментирован), их переносить нечего: убираются из TopPanel вместе с меню (U10).

## Выключатели: {check: CheckBox, get: Callable}
var _toggles: Array[Dictionary] = []
var _save_manager: SaveManager
var _confirm: ConfirmationDialog


func _init() -> void:
	name = &"Toggles"
	add_child(make_header("Маркеры и рельсы"))
	_add_toggle("Маркеры (куб над Entity, сокеты)", "Рисуются у объектов, созданных после включения", "Global.debug_markers",
			func() -> bool: return Global.debug_markers,
			func(on: bool) -> void: Global.debug_markers = on)
	_add_toggle("Лимиты flex (L)", "Применяется к тракам при следующем пересчете", "Global.flex_limits",
			func() -> bool: return Global.flex_limits,
			func(on: bool) -> void: Global.flex_limits = on)
	_add_toggle("Зоны проблем flex (Z)", "Зоны проблем flex цветной полосой над рельсами", "Global.flex_zones",
			func() -> bool: return Global.flex_zones,
			func(on: bool) -> void: Global.flex_zones = on)
	_add_toggle("Препятствия по ходу вагона", "Выключатель на случай просадки производительности", "Global.rail_obstacles",
			func() -> bool: return Global.rail_obstacles,
			func(on: bool) -> void: Global.rail_obstacles = on)
	_add_toggle("Физика вагона при драге", "Включено: вагон догоняет курсор и его можно бросить", "Global.drag_physics",
			func() -> bool: return Global.drag_physics,
			func(on: bool) -> void: Global.drag_physics = on)

	add_child(make_header("Экран"))
	_add_toggle("V-Sync", "Без V-Sync fps не упирается в частоту монитора. Клавиша F8 в редакторе Godot занята (стоп игры)", "DisplayServer.window_set_vsync_mode",
			func() -> bool: return DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED,
			_set_vsync)

	add_child(make_header("Сцена"))
	var clear := Button.new()
	clear.text = "Очистить сцену..."
	clear.pressed.connect(func() -> void: _confirm.popup_centered())
	add_child(clear)
	_confirm = ConfirmationDialog.new()
	_confirm.dialog_text = "Удалить все объекты со сцены? Несохраненное пропадет."
	_confirm.confirmed.connect(_clear_scene)
	add_child(_confirm)


func setup(save_manager: SaveManager) -> void:
	_save_manager = save_manager


func _add_toggle(text: String, tip: String, var_name: String, getter: Callable, setter: Callable) -> void:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override(&"separation", -4)
	add_child(cell)
	var cb := CheckBox.new()
	cb.text = text
	cb.tooltip_text = tip
	cb.set_pressed_no_signal(getter.call())
	cb.toggled.connect(func(on: bool) -> void: setter.call(on))
	cell.add_child(cb)
	var vl := make_var_label(var_name)
	cell.add_child(vl)
	_toggles.append({"check": cb, "get": getter})


func refresh() -> void:
	for t in _toggles:
		(t.check as CheckBox).set_pressed_no_signal(t.get.call())


func _set_vsync(on: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0


func _clear_scene() -> void:
	if is_instance_valid(_save_manager):
		_save_manager.clear_scene()
