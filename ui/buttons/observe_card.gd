class_name ObserveCard extends Button

#####################################
## Карточка режима Observe (пресет, время суток, закладка камеры, переключатель)
#####################################
## Создается кодом из ObserveController, отдельная сцена не нужна. Оформление позже через theme variation.
## Данные карточки: {"id", "title", "group"?, "toggle"?, "locked"?, "icon"?}
## group: карточки одной группы это радио-кнопки (Look, Time, Quality). toggle: одиночный переключатель.
## Без group и toggle: разовое действие (закладка камеры, снимок).

var category: StringName
var id: StringName

## ⚡Сигнал нажатия. Для toggle и radio pressed = новое состояние
signal card_pressed(category, id, pressed)


func _ready() -> void:
	pressed.connect(_on_pressed)


func config(_cat: StringName, _data: Dictionary, _group: ButtonGroup = null) -> void:
	category = _cat
	id = _data.id
	text = str(_data.title)
	custom_minimum_size = Vector2(110, 56)
	if _data.has("icon"):
		icon = _data.icon

	toggle_mode = _data.get("toggle", false) or _group != null
	if _group:
		button_group = _group

	if _data.has("tip"):
		tooltip_text = str(_data.tip)
	if _data.get("locked", false):
		disabled = true
		tooltip_text = "Скоро"


func _on_pressed() -> void:
	printt(category, id, button_pressed)
	card_pressed.emit(category, id, button_pressed)
