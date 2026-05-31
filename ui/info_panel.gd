class_name InfoPanel extends PanelContainer

@onready var header_label = %HeaderLabel
@onready var tab_container = %TabContainer
@onready var debug_text = %DebugTab 

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



func _populate_data():
	# Заголовок
	header_label.text = current_target.name # Или current_target.e_name
	
	# Вкладка Main (Например, ищем C_Track, если он есть)
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
	var text_dump = "[b]Components:[/b]\n"
	for child in current_target.get_children():
		if child is Component:
			text_dump += "- " + child.get_script().get_global_name() + "\n"
			
	# Присваиваем текст один раз. Никаких утечек памяти!
	debug_text.text = text_dump

# Для TransformTab (если нужны живые координаты)
# Только ЭТУ вкладку имеет смысл обновлять в _process, и только если она открыта!
func _process(_delta):
	if visible and current_target and tab_container.current_tab == 2: # Допустим, TransformTab = 2
		var _pos = current_target.global_position
		var _rot = current_target.rotation_degrees
		# Обновляем лейблы координат...
