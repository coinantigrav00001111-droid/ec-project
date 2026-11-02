class_name DebugTab extends VBoxContainer

###########################
## DebugTab. Базовый класс вкладки DebugPanel (U14)
###########################
## Вкладка получает выбранный объект (bind) и обновляет живые значения в refresh().
## DebugPanel зовет refresh() 10 раз в секунду и только у открытой вкладки, пока панель видна.
## Вкладка не лезет в игру напрямую, если ей не нужно: что именно ей нужно, панель передает в setup().


## Объект, выбранный в игре (null: ничего не выбрано)
var target: Entity


## Выбор в игре сменился. Зовется и при открытии панели
func bind(entity: Entity) -> void:
	target = entity
	_on_bind()


## Периодическое обновление живых значений. Команд в игру не шлет
func refresh() -> void:
	pass


## Панель открыли или вкладку переключили
func opened() -> void:
	refresh()


func _on_bind() -> void:
	pass


## Строка-заголовок группы
static func make_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override(&"font_color", Color(0.75, 0.85, 1.0))
	return l


## Строка текста с переносом
static func make_note(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 300.0
	l.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.7))
	return l


## SpinBox с границами и шагом. allow_greater: значение можно ввести руками выше max
static func make_spin(min_v: float, max_v: float, step: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.allow_greater = true
	s.custom_minimum_size.x = 110.0
	s.size_flags_horizontal = Control.SIZE_SHRINK_END
	return s


## Пишет значение в SpinBox без сигнала и не мешает вводу (поле в фокусе не трогаем)
static func set_spin(spin: SpinBox, value: float) -> void:
	if spin.get_line_edit().has_focus():
		return
	spin.set_value_no_signal(value)
