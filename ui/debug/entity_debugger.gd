class_name EntityController extends PanelContainer

@export var with_props := false
#@onready var ui_controller: UIController = $"../../UIController"
@onready var tool_controller: ToolController = $"../../ToolController"


var target: Entity
var _refresh_timer := 0.0
const REFRESH_RATE := 0.5 # Обновление каждые 0.2 секунды (5 раз в сек)


func _ready() -> void:
	pass



#### +++++++++++#############

##  Выбираем объект для дебага
func set_target(entity: Entity):
	target = entity
	# Принудительно обновляем UI сразу при клике на новый таргет
	_refresh_timer = REFRESH_RATE 
	on_update_debug_info(target)


func _process(delta: float):
	if not target or not is_visible_in_tree(): return
	
	_refresh_timer -= delta
	if _refresh_timer <= 0:
		_refresh_timer = REFRESH_RATE
		on_update_debug_info(target)
	

# ⚡Сигнал обработка из госта, подключен в ui контроллере
func on_update_debug_info(_entity):
	
	target = _entity
	clear_ui()
	
	if !_entity: return
	
	var title_label = Label.new()
	
	title_label.text = target.get_script().get_global_name() + ' : ' + str(target.name)	
	%CompListContainer.add_child(title_label)
	#Список компонентов
	for comp in target.get_children():
		if comp is Component:
			add_component_block(comp)	

	%ToolLabel.text = str(tool_controller.active_tool.name)


func add_component_block(comp):
	var comp_label = Label.new()
	comp_label.text = comp.get_script().get_global_name()
	%CompListContainer.add_child(comp_label)
	
	if comp.is_state:
		comp_label.text += ' - state'
		comp_label.modulate = Color.YELLOW
	
	var props = get_component_properties(comp)
	
	for p in props:
		var value = comp.get(p)
		var row = Label.new()
		if str(value) != '' and with_props:
			row.text = str(p) + ": " + str(value)
			%CompListContainer.add_child(row)



func get_component_properties(comp):
	var result = []

	for p in comp.get_property_list():    
		if p.usage & PROPERTY_USAGE_EDITOR:
			result.append(p.name)
	
	return result
	

func clear_ui():
	for child in %CompListContainer.get_children():
		child.queue_free()
