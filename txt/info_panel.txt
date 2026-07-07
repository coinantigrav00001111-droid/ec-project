class_name InfoPanel extends PanelContainer


@onready var tab_container = %TabContainer

var current_target: Entity


func _ready():
	hide() # Прячем панель на старте



# Вызывается из SelectTool, когда мы кликаем по объекту
func set_target(entity: Entity):
	# 1. Отписываемся от старого объекта
	if current_target:
		current_target.component_added.disconnect(_on_components_changed)
		current_target.component_removed.disconnect(_on_components_changed)
		
	current_target = entity
	
	# 2. Если кликнули в пустоту - прячем панель
	if not current_target:
		hide()
		return
		
	# 3. Подписываемся на новый объект (для обновления Debug-вкладки)
	current_target.component_added.connect(_on_components_changed)
	current_target.component_removed.connect(_on_components_changed)
	
	show() # Visible = on
	_populate_data()



func _populate_main_tab():
	var identity = current_target.get_comp(C_Identity)
	if identity:
		%HeaderLabel.text = identity.get_name_e()
		%DescriptionLabel.text = identity.get_description()
		%RadiusLabel.text = str(identity.get_radius()) + ' u/sm'
		%DegLabel.text = str(identity.get_degree()) + '°'
		%LengthLabel.text = str(identity.get_length()) + ' u/sm'
		%IconRect.texture = identity.get_icon()
	else:
		# Если это какой-то системный объект без паспорта
		%HeaderLabel.text = "Системный объект"



func _populate_data():
	# Вкладка Main
	_populate_main_tab()
	
	# Вкладка Power (Скрываем, если нет компонента)
	var _power_tab = tab_container.get_node("PowerTab")
	#_power_tab.visible = current_target.has_comp(C_Power) # Условный компонент
	
	# Обновляем вкладку отладки
	_update_debug_tab()



# Вызывается ТОЛЬКО когда компонент добавился/удалился
func _on_components_changed(_type: Script):
	_update_debug_tab()
	# Здесь же можно перепроверять видимость вкладок (вдруг добавили C_Power)

func _update_debug_tab():
	if not current_target: return
	
	# Вместо создания сотен Label.new(), мы просто собираем ОДНУ строку
	var text_dump = "[color=green]Components:[/color]\n"
	for child in current_target.get_children():
		if child is Component:
			if child.is_state:
				text_dump += "[color=yellow]-" + child.get_script().get_global_name() + " - state[/color]\n"
			else:
				text_dump += "- " + child.get_script().get_global_name() + "\n"
			
	# Присваиваем текст один раз. Никаких утечек памяти!
	%DebugTab.text = text_dump



# Для TransformTab (если нужны живые координаты)
# Только ЭТУ вкладку имеет смысл обновлять в _process, и только если она открыта!
func _process(_delta):
	if visible and current_target and tab_container.current_tab == 2: 
		# Допустим, TransformTab = 2
		var _pos = current_target.global_position
		var _rot = current_target.rotation_degrees
		%PosLabel.text =  "(%.2f, %.2f, %.2f)" % [_pos.x, _pos.y, _pos.z]
		%RotLabel.text =  "(%.2f, %.2f, %.2f)" % [_rot.x, _rot.y, _rot.z]
	if visible and current_target and tab_container.current_tab == 4: 
		_update_debug_tab()
