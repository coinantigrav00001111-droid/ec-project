class_name InfoController extends Node

#########################
## Выводит инфу в UI. 
#########################

## 💡По сути ничего не делает пока, кроме вывода метки режима игры

@onready var tool_controller: ToolController = $"../../ToolController"

func _ready() -> void:
	#⚡Сигнал обновления инфы. 
	#ui_controller.update_info.connect(on_update_info)
	tool_controller.update_info.connect(on_update_info)
	%ModeController.update_info.connect(on_update_info)
	%BuildController.update_info.connect(on_update_info)


# ⚡Сигнал обработка из ui контроллера 
func on_update_info():

	%ModeLabel.text = tool_controller.get_current_mode()


@export var m_colors = {
	'schema_r' 		: preload("res://data/textures/materials/power_schema_r.tres"),
	'schema_l' 		: preload("res://data/textures/materials/power_schema_l.tres"),
	'schema_i' 		: preload("res://data/textures/materials/power_schema_i.tres"),
}

## задает отображение схемы питания трака
## _power_connected - коннект или нет, TODO убрать намбер - _number - номер контура, _isolator изолятор или нет
func set_power_schema(_power_connected = false, _number = 1, _isolator = false):
	#_number = contour_id
	## Стандартные цвета
	var schema_r = m_colors.schema_r
	var schema_l = m_colors.schema_l
	var schema_i = m_colors.schema_i
	#var _sh:Material = Material.new() 
	var _schema
	_schema = (schema_i if _isolator  
			else schema_r if _number >= 0
			else schema_l
			)

	#power_schema.set_material_override(_schema)
	#power_schema.visible = false if _number == 0 and !_isolator else true
	
	
