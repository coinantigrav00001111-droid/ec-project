class_name TopPanel extends PanelContainer

########################
## Верхняя панель. Содержит главное меню игры сейв\лоад\итд
########################
## Сигналы меню принимает ToolController

## Кнопка меню сейв\лоад
@onready var menu_button: MenuButton = %MenuButton
# UI не должен знать про тулзы
@onready var tool_controller: ToolController = $"../../ToolController"
@onready var save_manager: SaveManager = $"../../SaveManager"
## Чекбокс слоя питания
@onready var power_schema_check: CheckBox = %PowerSchemaCheck
# ⚡Сигнал для ToolController
#signal menu_button_pressed 



func _ready() -> void:
	# попап меню, которое вываливается по кнопке, посылает этот сигнал
	menu_button.get_popup().id_pressed.connect(_on_menu_button_pressed)
	# Слой питания могут переключить не из чекбокса (Observe при входе/выходе): держим вид в синхроне
	PGM.power_layer_toggled.connect(_on_power_layer_toggled)
	power_schema_check.set_pressed_no_signal(PGM.is_power_layer_active)



## Обработка сигнала от попап меню сейв\лоад. Принимает ToolController
func _on_menu_button_pressed(_index : int) -> void:
	#menu_button_pressed.emit(_index)
	match _index:
		0: # save
			#SaveManager.save_game()
			pass
		1: # load
			#SaveManager.load_game('savegame')
			#print(OS.get_data_dir())
			pass
		2: # ++
			pass
		3: #ничего
			save_manager.clear_scene() # Хотя это больше подходит для тулза стройки, но пока тут
			pass
			
		5: #DEFAULT jolt
			#GM. apply_jolt_profile(GM.AssistProfile.DEFAULT) 
			pass
		6: #STABLE jolt
			#GM. apply_jolt_profile(GM.AssistProfile.STABLE) 
			pass
		7: #EXTREME jolt
			#GM. apply_jolt_profile(GM.AssistProfile.EXTREME) 
			pass
	pass
	



## Включение Cлоя power (11) на камере. Режим повер 2лвл
func _on_power_schema_check_toggled(toggled_on: bool) -> void:
	#$/root/GameRoot/Gimbal/Elevation/Camera.set_cull_mask_value(3, toggled_on)	

	# Дергаем менеджер питания
	PGM.toggle_power_layer(toggled_on)


## ⚡Сигнал из PGM: слой питания переключён. Двигаем чекбокс без повторного сигнала
func _on_power_layer_toggled(is_active: bool) -> void:
	power_schema_check.set_pressed_no_signal(is_active)
