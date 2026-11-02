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
	_add_toggle("Маркеры (куб над Entity, сокеты)", "Global.debug_markers. Рисуются у объектов, созданных после включения",
			func() -> bool: return Global.debug_markers,
			func(on: bool) -> void: Global.debug_markers = on)
	_add_toggle("Лимиты flex (L)", "Global.flex_limits. Применяется к тракам при следующем пересчете",
			func() -> bool: return Global.flex_limits,
			func(on: bool) -> void: Global.flex_limits = on)
	_add_toggle("Зоны проблем flex (Z)", "Global.flex_zones",
			func() -> bool: return Global.flex_zones,
			func(on: bool) -> void: Global.flex_zones = on)
	_add_toggle("Препятствия по ходу вагона", "Global.rail_obstacles. Выключатель на случай просадки производительности",
			func() -> bool: return Global.rail_obstacles,
			func(on: bool) -> void: Global.rail_obstacles = on)
	_add_toggle("Физика вагона при драге", "Global.drag_physics. Включено: вагон догоняет курсор и его можно бросить",
			func() -> bool: return Global.drag_physics,
			func(on: bool) -> void: Global.drag_physics = on)

	add_child(make_header("Экран"))
	_add_toggle("V-Sync (F8)", "Окно. Без V-Sync fps не упирается в частоту монитора",
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


func _add_toggle(text: String, tip: String, getter: Callable, setter: Callable) -> void:
	var cb := CheckBox.new()
	cb.text = text
	cb.tooltip_text = tip
	cb.set_pressed_no_signal(getter.call())
	cb.toggled.connect(func(on: bool) -> void: setter.call(on))
	add_child(cb)
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
