class_name ObserveController extends Node

########################
##    ObserveController -  UI
## 💡 Занимается обработкой нажатий в режиме игры OBSERVE 💡
########################
## Интерфейс как у BuildController / OperateController: ModeController и UIGenerator зовут его по именам
## (current_cat, category_list, on_category_selected, on_tag_selected, animate_wrapper).
## Про графику и камеры контроллер ничего не знает: нажатие карточки уходит сигналом observe_action,
## на него подпишутся GraphicsManager (S3-S5), камеры и фоторежим (S9).
## Выбор и выделение отключает ToolController (переключает инструмент на ObserveTool).

@export var anim_time := 0.4

@onready var mode_controller: ModeController = %ModeController
@onready var obj_container: GridContainer = %ObBtnGridContainer

## ⚡Сигнал: нажата карточка. pressed осмыслен для toggle и radio карточек
signal observe_action(category: StringName, id: StringName, pressed: bool)
## ⚡Вошли в режим Observe / вышли из него
signal observe_entered
signal observe_exited

var current_cat = &'idle'
var current_tag = &'idle'   # у Observe тегов нет, оставлено для единого интерфейса контроллеров

## Список категорий lvl2. TODO иконки
var category_list = {
	&"look": {"id": &"look", "name": "Look", "icon": null},
	&"light": {"id": &"light", "name": "Light", "icon": null},
	&"camera": {"id": &"camera", "name": "Camera", "icon": null},
	&"room": {"id": &"room", "name": "Room", "icon": null},
	&"photo": {"id": &"photo", "name": "Photo", "icon": null},
	&"weather": {"id": &"weather", "name": "Weather", "icon": null},
}

## Карточки по категориям. group: радио-группа, toggle: переключатель, без них: разовое действие.
## Большинство пока заглушки, рабочими их делают шаги S3-S9.
const CARDS := {
	&"look": [
		{"id": &"toy", "title": "Toy", "group": &"look", "default": true},
		{"id": &"workshop", "title": "Workshop", "group": &"look"},
		{"id": &"clean", "title": "Clean", "group": &"look"},
		{"id": &"low", "title": "Low", "group": &"quality"},
		{"id": &"medium", "title": "Medium", "group": &"quality", "default": true},
		{"id": &"high", "title": "High", "group": &"quality"},
	],
	&"light": [
		{"id": &"morning", "title": "Утро", "group": &"time"},
		{"id": &"day", "title": "День", "group": &"time", "default": true},
		{"id": &"evening", "title": "Вечер", "group": &"time"},
		{"id": &"night", "title": "Ночь", "group": &"time"},
		{"id": &"lamp", "title": "Лампа", "toggle": true},
	],
	&"camera": [
		{"id": &"bookmark_1", "title": "1"},
		{"id": &"bookmark_2", "title": "2"},
		{"id": &"bookmark_3", "title": "3"},
		{"id": &"bookmark_4", "title": "4"},
		{"id": &"bookmark_5", "title": "5"},
		{"id": &"follow", "title": "Follow", "toggle": true},
		{"id": &"pov", "title": "POV", "toggle": true},
		{"id": &"orbit", "title": "Orbit", "toggle": true},
	],
	&"room": [
		{"id": &"room_visible", "title": "Комната", "toggle": true, "default": true},
		{"id": &"ceiling", "title": "Потолок", "toggle": true},
	],
	&"photo": [
		{"id": &"hide_ui", "title": "Скрыть UI", "toggle": true},
		{"id": &"snapshot", "title": "Снять"},
	],
	&"weather": [
		{"id": &"soon", "title": "Weather", "locked": true},
	],
}

var _active := false
var _power_layer_was_on := false
var _groups := {}   # имя группы -> ButtonGroup (пересоздаются при каждом показе категории)
# Состояние карточек переживает пересборку категории. TODO S3: источник правды станет GraphicsManager.state
var _group_state := {}    # группа -> id выбранной карточки
var _toggle_state := {}   # id -> bool


func _ready() -> void:
	add_to_group(&"observe_controller")   # по группе его находит RoomBuilder (%-имя не виден из другой сцены)
	# ⚡Сигнал из ModeController о смене режима
	mode_controller.current_mode_changed.connect(on_mode_changed)


# ==============================================
# Вход / выход из режима
# ==============================================

## ⚡Сигнал из ModeController
func on_mode_changed(_new_mode) -> void:
	var now := str(_new_mode) == "observe"
	if now == _active:
		return
	_active = now
	if now:
		_on_enter()
	else:
		_on_exit()


## Всё, что режим выключает при входе, он возвращает при выходе (TDD 14.1)
func _on_enter() -> void:
	# Power layer мешает читать картинку. Запоминаем, чтобы вернуть
	_power_layer_was_on = PGM.is_power_layer_active
	if _power_layer_was_on:
		PGM.toggle_power_layer(false)
	# Выделение, ховер, призрак и InfoPanel снимает ToolController при смене инструмента
	Outline.enabled = false   # без контуров: нет полноэкранных SubViewport, чище кадр
	observe_entered.emit()


func _on_exit() -> void:
	if _power_layer_was_on:
		PGM.toggle_power_layer(true)
		_power_layer_was_on = false
	current_cat = &'idle'
	current_tag = &'idle'
	_clear_cards()
	%ObserveObjectsContainer.hide()
	# TODO S9: photo_mode = false, вернуть UI, если был скрыт
	Outline.enabled = true
	observe_exited.emit()


# ==============================================
# Кнопки
# ==============================================

## ⚡Сигнал из кнопок кат.
func on_category_selected(_new_cat: StringName) -> void:
	if _new_cat == current_cat:
		_new_cat = &'idle'   # Если кнопка отжата, то в идл
	current_cat = _new_cat
	show_category_panel(current_cat)


## ⚡Сигнал из кнопок тегов. В Observe тегов нет
func on_tag_selected(_new_tag: StringName) -> void:
	current_tag = _new_tag


func show_category_panel(_cat: StringName) -> void:
	if _cat == &'idle':
		%ObserveObjectsContainer.hide()
		return
	_fill_cards(_cat)
	%ObCatTitle.text = _cat   # Заголовок окна
	animate_wrapper(%ObserveObjectsContainer)


func _fill_cards(_cat: StringName) -> void:
	_clear_cards()
	for data in CARDS.get(_cat, []):
		var card := ObserveCard.new()
		card.config(_cat, data, _group_for(data))
		if card.toggle_mode:
			card.set_pressed_no_signal(_is_on(data))
		obj_container.add_child(card)
		card.card_pressed.connect(_on_card_pressed)
	# TODO S3+: выставить нажатое состояние карточек из GraphicsManager.state


func _clear_cards() -> void:
	for c in obj_container.get_children():
		obj_container.remove_child(c)
		c.queue_free()
	_groups.clear()


func _group_for(data: Dictionary) -> ButtonGroup:
	var g: StringName = data.get("group", &"")
	if g == &"":
		return null
	if not _groups.has(g):
		_groups[g] = ButtonGroup.new()
	return _groups[g]


## ⚡Сигнал из карточки
func _on_card_pressed(_cat: StringName, _id: StringName, _pressed: bool) -> void:
	var data := _card_data(_cat, _id)
	var g: StringName = data.get("group", &"")
	if g != &"":
		if _pressed:
			_group_state[g] = _id
	elif data.get("toggle", false):
		_toggle_state[_id] = _pressed
	if Global.debug_mode:
		print("[Observe] ", _cat, " / ", _id, " : ", _pressed)
	observe_action.emit(_cat, _id, _pressed)


## Программная смена выбранной карточки группы (GFX при смене Look/Time из кода). Сигнал карточки не шлется
func set_group_state(group: StringName, id: StringName) -> void:
	_group_state[group] = id
	var g: ButtonGroup = _groups.get(group)
	if g == null:
		return
	for b in g.get_buttons():
		if b is ObserveCard:
			b.set_pressed_no_signal(b.id == id)


## То же для переключателя
func set_toggle_state(id: StringName, on: bool) -> void:
	_toggle_state[id] = on
	for c in obj_container.get_children():
		if c is ObserveCard and c.id == id and c.toggle_mode:
			c.set_pressed_no_signal(on)


## Нажата ли карточка при показе: из сохранённого состояния, иначе по "default"
func _is_on(data: Dictionary) -> bool:
	var g: StringName = data.get("group", &"")
	if g != &"":
		if _group_state.has(g):
			return _group_state[g] == data.id
		return data.get("default", false)
	if data.get("toggle", false):
		return _toggle_state.get(data.id, data.get("default", false))
	return false


func _card_data(_cat: StringName, _id: StringName) -> Dictionary:
	for d in CARDS.get(_cat, []):
		if d.id == _id:
			return d
	return {}


## Анимированный показ панели (копия из BuildController / OperateController)
func animate_wrapper(_panel) -> void:
	var wrapper = _panel.get_node_or_null('AnimatedWrapper')

	if !wrapper: # Если без враппера то и  без аниме
		_panel.show()
		return

	var _tween := create_tween().set_parallel(true)\
						.set_trans(Tween.TRANS_QUINT)\
						.set_trans(Tween.TRANS_BACK)\
						.set_ease(Tween.EASE_OUT)

	wrapper.get_parent().show()

	var start_offset :int = wrapper.size.y
	wrapper.modulate.a = 0
	wrapper.offset_transform_position.y = start_offset

	_tween.tween_property(wrapper, "offset_transform_position:y", 0, anim_time)
	_tween.tween_property(wrapper, "modulate:a", 1.0, anim_time)
