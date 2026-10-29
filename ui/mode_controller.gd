class_name ModeController extends Node

########################
##    ModeController 
## 💡 LVL1 - Переключает текущий режим игры, обрабатывает события mode 
########################
## Реестр режимов: у каждого режима есть обработчик его панели. Контракт обработчика:
##   show_mode_ui(mode: StringName)   показать панель режима (с анимацией)
##   hide_mode_ui()                   спрятать панель режима, сбросить выбранную категорию
##   debug_open_category(index: int)  необязательно: открыть категорию по номеру (Global.active_ui_category)
## Build, Operate и Observe обслуживает ToolbarController (каталог режима регистрирует адаптер).
## У режима без обработчика (Library, заглушка) показывается простая панель из PLAIN_PANELS.


@onready var tool_controller: ToolController = $"../../ToolController"
#@onready var GR : GameRoot = $"../../"

## ⚡ Сигнал наружу о смене режима
signal current_mode_changed(_current_mode)

## режим -> обработчик
var _handlers := {}
## режим -> панель без обработчика
var _plain_panels := {}


func _ready() -> void:
	#⚡Сигнал о выборе режима из панели коннектится с контроллером
	%ModePanel.mode_selected.connect(on_mode_selected)
	# Метка с именем активного инструмента (временная, уйдёт вместе с ModeLabel в U9)
	tool_controller.tool_changed.connect(func(tool_name: StringName): %ModeLabel.text = str(tool_name))

	var toolbar := get_node_or_null("%ToolbarController")
	_handlers = {
		&"build": toolbar,
		&"operate": toolbar,
		&"observe": toolbar,
	}
	_plain_panels = {&"library": get_node_or_null("%LibraryPanel")}

	# Режим быстрой загрузки: Observe недоступен, кнопка режима скрыта
	if Global.fast_debug:
		var observe_btn := %ModePanel.get_node_or_null("VBoxContainer/ObserveButton") as Control
		if observe_btn:
			observe_btn.hide()

	# Задежка, чтобы создались кнопки в билдпанели
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Выбор режима для старта по Global переменной
	var _mode := Global.current_mode
	_show_mode_ui(_mode)
	var _mode_button := %ModePanel.get_node_or_null("VBoxContainer/" + _mode.capitalize() + "Button") as Button
	if _mode_button:
		_mode_button.button_pressed = true
	
	#DD дебаг Запускаем активную категорию 
	if Global.debug_mode:
		var handler = _handlers.get(_mode)
		if handler != null and handler.has_method("debug_open_category"):
			handler.debug_open_category(Global.active_ui_category)




##⚡ Сигнал из панели ModePanel. Ставим новый режим
func on_mode_selected(new_mode: StringName) -> void:
	var current_m := Global.current_mode
	
	if new_mode == current_m:	return

	# Выключаем панель категорий текущего режима и сбрасываем его выбор
	_hide_mode_ui(current_m)
	
	# Выключаем контейнеры объектов (кнопок) и остальные панели
	for _cont in %MainControl.get_children():
		_cont.hide()

	# Отключаем все кнопки
	for _btn in get_tree().get_nodes_in_group('category_buttons'):
		_btn.button_pressed = false
		
	# Включаем панель нового режима
	_show_mode_ui(new_mode)

	# Режим пишем сюда, не в ToolController: ModeController владелец режима
	Global.current_mode = new_mode
	# ⚡Сигнал наружу
	current_mode_changed.emit(new_mode)



func _show_mode_ui(mode: StringName) -> void:
	var handler = _handlers.get(mode)
	if handler != null:
		handler.show_mode_ui(mode)
		return
	var panel := _plain_panels.get(mode) as Control
	if panel:
		panel.show()


func _hide_mode_ui(mode: StringName) -> void:
	var handler = _handlers.get(mode)
	if handler != null:
		handler.hide_mode_ui()
