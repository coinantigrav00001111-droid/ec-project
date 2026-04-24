class_name ModeController extends Node

########################
##    ModeController 
## 💡 LVL1 - Переключает текущий режим, обрабатывает события mode 
########################


#@onready var ui_controller: UIController = $"../../UIController"
@onready var tool_controller: ToolController = $"../../ToolController"

## ⚡ Сигнал наружу о смене режима
signal current_mode_changed(_current_mode)
signal update_info


func _ready() -> void:
	#⚡Сигнал о выборе режима из панели коннектится с контроллером
	%ModePanel.mode_selected.connect(on_mode_selected)

	# Задежка, чтобы создались кнопки в билдпанели
	await get_tree().process_frame
	await get_tree().process_frame
	%BuildController.animate_wrapper(%BuildPanel)# Показывает lvl2 контейнеры

	#DD дебаг Запускаем категорию тракс
	#if ui_controller.get_debug_mode():
	if tool_controller.get_debug_mode():
		%BuildLvl2Container.get_child(0)._on_pressed()



##⚡ Сигнал из панели ModePanel. Ставим новый режим
func on_mode_selected(new_mode: StringName) -> void:
	#var current_m : = ui_controller.get_current_mode()
	var current_m : = tool_controller.get_current_mode()
	
	if new_mode == current_m:	return

	# Выключаем текущую панель lvl2 
	var current_panel := '%' + current_m.capitalize() + 'Panel'
	get_node(current_panel).hide()
	%CatContainer.hide()

	# Отключить кнопки из этой панели
	var current_btn_group = 'category_buttons'
	_toggle_off_panel_buttons(current_btn_group) 

	# Включаем новую кат lvl2
	current_m = new_mode
	current_panel = '%' + current_m.capitalize() + 'Panel'

	# ⚡Сигнал наружу
	current_mode_changed.emit(current_m)
	
	var _new_panel = get_node(current_panel)
	%BuildController.animate_wrapper(_new_panel)
	
	# ⚡Сигнал обновление инфы
	update_info.emit()



## Отключает кнопки лвл2 на выходе из состояния
func _toggle_off_panel_buttons(_group_name):
	var _group = get_tree().get_nodes_in_group(_group_name)
	
	# Отключаем категорию
	%BuildController.current_cat = &'idle' 

	for _btn in _group:
		_btn.button_pressed = false
