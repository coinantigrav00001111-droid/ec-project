class_name InfoController extends Node


#@onready var ui_controller: UIController = $"../../UIController"
@onready var tool_controller: ToolController = $"../../ToolController"

func _ready() -> void:
	#⚡Сигнал обновления инфы. 
	#ui_controller.update_info.connect(on_update_info)
	tool_controller.update_info.connect(on_update_info)
	%ModeController.update_info.connect(on_update_info)
	%BuildController.update_info.connect(on_update_info)


# ⚡Сигнал обработка из ui контроллера 
func on_update_info():
	#%ModeLabel.text = ui_controller.get_current_mode() + '   ' + %BuildController.current_cat + '   ' + %BuildController.current_tag
	%ModeLabel.text = tool_controller.get_current_mode() + '   ' + %BuildController.current_cat + '   ' + %BuildController.current_tag

	
