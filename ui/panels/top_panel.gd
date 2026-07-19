class_name TopPanel extends PanelContainer

########################
## Верхняя панель. Содержит главное меню игры сейв\лоад\итд
########################
## Сигналы меню принимает ToolController

## Кнопка меню сейв\лоад
@onready var menu_button: MenuButton = %MenuButton
# UI не должен знать про тулзы
#@onready var tool_controller: ToolController = $"../../ToolController"

# ⚡Сигнал для ToolController
signal menu_button_pressed 



func _ready() -> void:
	# попап меню, которое вываливается по кнопке, посылает этот сигнал
	menu_button.get_popup().id_pressed.connect(_on_menu_button_pressed)



## Обработка сигнала от попап меню сейв\лоад. Принимает ToolController
func _on_menu_button_pressed(_index : int) -> void:
	menu_button_pressed.emit(_index)
	
	# Ниже уже не тут обрабатывается, а в toolcontroller 
	#match _index:
		#0: # save
			##print($"/root/world/Gimbal"._testsave)
			##save_manager.save_game()
			#_save()
			#pass
			#
		#1: # load
			##saver.load_game()
			#_load()
			##print($"/root/world/Gimbal"._testsave)
			#pass
		#2: # ++
			#pass


## Включение Cлоя power (11) на камере. Режим повер 2лвл
func _on_power_schema_check_toggled(toggled_on: bool) -> void:
	$/root/GameRoot/Gimbal/Elevation/Camera.set_cull_mask_value(3, toggled_on)	
	# Дергаем менеджер питания
	PowerGridManager.toggle_power_layer(toggled_on)
	
	#is_power_layer_active = toggled_on
	#power_layer_toggled.emit(toggled_on)
	
## ⚡Сигнал о включении визуального повер-слоя
#signal power_layer_toggled(is_active: bool)
#
## Флаг  включения визуального повер-слоя
#var is_power_layer_active: bool = false

#func toggle_power_layer(state: bool):
	#is_power_layer_active = state
	#power_layer_toggled.emit(state)
