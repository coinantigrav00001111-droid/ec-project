class_name ObserveController extends Node

########################
##    ObserveController
## 💡 Логика режима OBSERVE: вход и выход, нажатия карточек наружу 💡
########################
## Кнопки и данные карточек теперь в ToolbarController и CardCatalogProvider (U4).
## Про графику и камеры контроллер ничего не знает: нажатие карточки уходит сигналом observe_action,
## на него подписаны GraphicsManager, камеры, комната и фоторежим.
## Выбор и выделение отключает ToolController (переключает инструмент на ObserveTool).

@onready var mode_controller: ModeController = %ModeController

## ⚡Сигнал: нажата карточка. pressed осмыслен для toggle и radio карточек
signal observe_action(category: StringName, id: StringName, pressed: bool)
## ⚡Вошли в режим Observe / вышли из него
signal observe_entered
signal observe_exited

var _active := false
var _power_layer_was_on := false
var _cards := CardCatalogProvider.new()


func _ready() -> void:
	add_to_group(&"observe_controller")   # по группе его находит RoomBuilder (%-имя не виден из другой сцены)
	# Каталог карточек и приемник нажатий для панели инструментов
	%ToolbarController.register_mode(&"observe", _cards, _on_card_pressed)
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
	# TODO S9: photo_mode = false, вернуть UI, если был скрыт
	Outline.enabled = true
	observe_exited.emit()


# ==============================================
# Карточки
# ==============================================

## ⚡Приемник: нажата карточка (из CardCatalogProvider)
func _on_card_pressed(category: StringName, id: StringName, pressed: bool) -> void:
	if Global.debug_mode:
		print("[Observe] ", category, " / ", id, " : ", pressed)
	observe_action.emit(category, id, pressed)


## Программная смена выбранной карточки группы (GFX при смене Look/Time из кода). Сигнал карточки не шлется
func set_group_state(group: StringName, id: StringName) -> void:
	_cards.set_group_state(group, id)


## То же для переключателя
func set_toggle_state(id: StringName, on: bool) -> void:
	_cards.set_toggle_state(id, on)
