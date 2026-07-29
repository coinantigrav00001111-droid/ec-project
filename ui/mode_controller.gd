class_name ModeController extends Node

########################
##    ModeController 
## 💡 LVL1 - Переключает текущий режим игры, обрабатывает события mode 
########################


@onready var tool_controller: ToolController = $"../../ToolController"
@onready var GR : GameRoot = $"../../"

## ⚡ Сигнал наружу о смене режима
signal current_mode_changed(_current_mode)
signal update_info


func _ready() -> void:
	#⚡Сигнал о выборе режима из панели коннектится с контроллером
	%ModePanel.mode_selected.connect(on_mode_selected)

	# Задежка, чтобы создались кнопки в билдпанели
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Выбор режима для старта по GR переменной
	var _mode := GR.current_mode.capitalize()
	var _controller = get_node('%' + _mode + 'Controller')
	var _panel = get_node('%' + _mode + 'Panel')
	_controller.animate_wrapper(_panel)# Показывает lvl2 контейнеры
	#%OperateController.animate_wrapper(%OperatePanel)# Показывает lvl2 контейнеры
	get_node("../ModePanel/VBoxContainer/" + _mode + 'Button').button_pressed = true
	#DD дебаг Запускаем категорию тракс
	if GR.debug_mode:
		var _container = get_node('%' + _mode + 'BtnLvl2Container')
		_container.get_child(0)._on_pressed()
		#%OperateBtnLvl2Container.get_child(0)._on_pressed()



##⚡ Сигнал из панели ModePanel. Ставим новый режим
func on_mode_selected(new_mode: StringName) -> void:
	var current_m : = GR.current_mode
	
	if new_mode == current_m:	return

	# Выключаем текущую панель lvl2 (категории)
	var current_panel := '%' + current_m.capitalize() + 'Panel'
	get_node(current_panel).hide()
	
	# Отключаем кнопку категории
	var cur_controller_name := '%' + current_m.capitalize() + 'Controller'
	var current_controller := get_node(cur_controller_name)
	current_controller.current_cat = &'idle'
	
	# Выключаем контейнер объектов(кнопок)
	var _obj_containers = %MainControl.get_children()
	for _cont in _obj_containers:
		_cont.hide()

	# Отключаем все кнопки
	var _group = get_tree().get_nodes_in_group('category_buttons')
	for _btn in _group:
		_btn.button_pressed = false
		
	# Включаем новую кат lvl2
	current_m = new_mode
	current_panel = '%' + current_m.capitalize() + 'Panel'

	# Выезд контейнера
	var _new_panel = get_node(current_panel)
	current_controller.animate_wrapper(_new_panel)

	# ⚡Сигнал наружу
	current_mode_changed.emit(current_m)
	# ⚡Сигнал обновление инфы
	update_info.emit()



## Отключает кнопки лвл2 на выходе из состояния
func _toggle_off_panel_buttons(_group_name):
	#var _group = get_tree().get_nodes_in_group(_group_name)
	#
	### Отключаем категорию
	##%BuildController.current_cat = &'idle' 
#
	#for _btn in _group:
		#_btn.button_pressed = false
	pass
