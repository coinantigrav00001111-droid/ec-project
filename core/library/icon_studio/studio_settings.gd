extends Node

########################
## Icon Studio: настройки (ATTN_18 §18.3.4, шаг I0)
########################
## Свой файл user://icon_studio.cfg, настройки игры (user://settings.cfg) не трогаем.
## Запись отложенная: раз в секунду проверяем, что изменилось, и пишем. Кнопка Stop в редакторе
## не присылает сигнал закрытия окна, поэтому одной записи на выходе мало (ATTN_18 §18.2, п. 6).

const PATH := "user://icon_studio.cfg"
const DEFAULT_WINDOW_SIZE := Vector2i(1600, 900)
const MIN_WINDOW_SIZE := Vector2i(900, 560)
const SAVE_PERIOD := 1.0

var _cfg := ConfigFile.new()
var _dirty := false
var _timer: Timer


func _ready() -> void:
	_cfg.load(PATH)
	_timer = Timer.new()
	_timer.wait_time = SAVE_PERIOD
	_timer.timeout.connect(flush)
	add_child(_timer)
	_timer.start()


func get_value(section: String, key: String, default: Variant = null) -> Variant:
	return _cfg.get_value(section, key, default)


func set_value(section: String, key: String, value: Variant) -> void:
	if _cfg.has_section_key(section, key) and _cfg.get_value(section, key) == value:
		return
	_cfg.set_value(section, key, value)
	_dirty = true


## Забирает текущее состояние окна и пишет файл, если что-то изменилось
func flush() -> void:
	_capture_window()
	if not _dirty:
		return
	var err := _cfg.save(PATH)
	if err == OK:
		_dirty = false
	else:
		push_warning("IconStudio: не удалось записать %s (код %d)" % [PATH, err])


## Стирает все настройки (окно сбрасывается отдельно reset_window)
func reset_all() -> void:
	_cfg.clear()
	_dirty = true


# ==========================================
# ОКНО
# ==========================================

func _capture_window() -> void:
	var w := get_window()
	if w == null:
		return
	set_value("window", "mode", int(w.mode))
	# В свёрнутом и развёрнутом режиме размер «окна» не его, запоминаем только обычный
	if w.mode == Window.MODE_WINDOWED:
		set_value("window", "size", w.size)
		set_value("window", "position", w.position)


func restore_window() -> void:
	var w := get_window()
	if w == null:
		return
	w.min_size = MIN_WINDOW_SIZE
	var size := DEFAULT_WINDOW_SIZE
	var stored: Variant = get_value("window", "size", null)
	if stored is Vector2i:
		size = stored
	size = Vector2i(maxi(size.x, MIN_WINDOW_SIZE.x), maxi(size.y, MIN_WINDOW_SIZE.y))
	var usable := _usable_rect(w)
	size = Vector2i(mini(size.x, usable.size.x), mini(size.y, usable.size.y))
	w.size = size
	var pos: Variant = get_value("window", "position", null)
	if pos is Vector2i and _on_some_screen(pos):
		w.position = pos
	else:
		_center(w, size)
	var mode := int(get_value("window", "mode", Window.MODE_WINDOWED))
	if mode == Window.MODE_MAXIMIZED:
		w.mode = Window.MODE_MAXIMIZED


func reset_window() -> void:
	var w := get_window()
	if w == null:
		return
	w.mode = Window.MODE_WINDOWED
	w.size = DEFAULT_WINDOW_SIZE
	_center(w, DEFAULT_WINDOW_SIZE)


func _usable_rect(w: Window) -> Rect2i:
	var screen := w.current_screen
	return DisplayServer.screen_get_usable_rect(screen)


func _center(w: Window, size: Vector2i) -> void:
	var r := _usable_rect(w)
	w.position = r.position + (r.size - size) / 2


## Левый верхний угол окна (с запасом под заголовок) должен попадать на какой-то из экранов
func _on_some_screen(pos: Vector2i) -> bool:
	var probe := pos + Vector2i(60, 20)
	for i in DisplayServer.get_screen_count():
		var r := Rect2i(DisplayServer.screen_get_position(i), DisplayServer.screen_get_size(i))
		if r.has_point(probe):
			return true
	return false
