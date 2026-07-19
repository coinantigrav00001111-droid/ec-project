class_name InfoPanel extends PanelContainer


@onready var tab_container = %TabContainer

var current_target: Entity


func _ready():
	hide() # Прячем панель на старте



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
	
	#4. Обновляем необходимые в моменте вкладки
	_populate_data()



# Выполняется после получения таргета, обновляет необходимые в моменте показа вкладки
func _populate_data():
	# Вкладка Main
	_populate_main_tab()
	
	# Вкладка Power (Скрываем, если нет компонента)
	#var _power_tab = tab_container.get_node("PowerTab")
	#_power_tab.visible = current_target.has_comp(C_Power) # Условный компонент
	
	# Обновляем вкладку отладки
	_update_debug_tab()
	# Обновляем вкладку power
	_update_power_tab()


func _populate_main_tab():
	var identity = current_target.get_comp(C_Identity)
	var path = current_target.get_comp(C_Path)
	
	if identity:
		%HeaderLabel.text = identity.get_name_e()
		%DescriptionLabel.text = identity.get_description()
		%IconRect.texture = identity.get_icon()
		
		#TODO Возможно стоит сделать видимость контейнеров под конкретную категорию отдельной универсальной функцией. Когда не только траки появятся
		if identity.get_category() == &'track':
			%TrackContainer.show()
			%RadiusLabel.text = str(path.radius) + ' u/sm'
			%DegLabel.text = str(path.deg) + '°'
			%LengthLabel.text = str(path.get_length()) + ' u/sm'
		else:
			%TrackContainer.hide()

	else:
		# Если это какой-то системный объект без паспорта
		%HeaderLabel.text = "Системный объект"


''' Нужны актуальные повер значения трака, клип норм.'''

func _update_power_tab():
	if not current_target: return
	var _power_comp = null
	if current_target.has_comp(C_PowerTrack): # Если трак
		_power_comp = current_target.get_comp(C_PowerTrack)
		%PowerClipButton.disabled = false
		%PowerClipButton.button_pressed = false
		%ClipContourIDButton.disabled = true  # запрещаем менять контур
		# TODO Ждем инфу для этого
		%VoltageLabel.text = str(_power_comp.voltage)
		%FlippedLabel.text = str(_power_comp.is_flipped)
		
	else: # Если трака нет, то в дефолт все
		%PowerClipButton.disabled = true
		%PowerClipButton.button_pressed = false
		%ClipContourIDButton.disabled = true  # запрещаем менять контур
		%VoltageLabel.text = str(0)
		%FlippedLabel.text = str(0) 
		return
	
	var _power_clip = null
	if current_target.has_comp(C_PowerClip): # Если клип есть, то он определяет
		_power_clip = current_target.get_comp(C_PowerClip)
		%PowerClipButton.button_pressed = true
		%ClipContourIDButton.disabled = false # разрешаем менять контур
		_power_comp = _power_clip # Переключаемся на клип
	
	# 💡-option_button- Делаем селектор контура-
	var option_button = %ClipContourIDButton as OptionButton
	option_button.clear() # Полностью очищаем старые пункты
	
	# 1.1️⃣ Добавляем базовый вариант (0 - отключено от питания)
	option_button.add_item("0: Отключено", 0)
	
	# Получаем массив контуров, которые УЖЕ заняты другими клеммами на макете
	var occupied_contours = PowerGridManager.get_occupied_contours()
	var current_id = _power_comp.contour_id # Текущий контур этого объекта

	# 2. 2️⃣ Динамически наполняем список доступными контурами
	for i in range(1, PowerGridManager.MAX_CONTOURS + 1):
		# Контур доступен, если он СВОБОДЕН, ИЛИ если это "родной" контур текущего объекта
		if i == current_id or not i in occupied_contours:
			option_button.add_item("Контур " + str(i), i) # Текст и внутренний ID элемента
	
	# 3. 3️⃣ Выставляем визуальный фокус на текущий контур объекта
	# Так как мы передавали реальный ID контура вторым аргументом в add_item,
	# мы можем легко найти индекс нужной строки
	for idx in range(option_button.item_count):
		if option_button.get_item_id(idx) == current_id:
			option_button.select(idx)
			break

	%TrackContourLabel.text = str(current_target.get_comp(C_PowerTrack).contour_id)


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



# Вызывается ТОЛЬКО когда компонент добавился/удалился
func _on_components_changed(_type: Script):
	_update_debug_tab()
	# Здесь же можно перепроверять видимость вкладок (вдруг добавили C_Power)



## ---⚡Сигналы от кнопок---


## Кнопка меняет Номер контура  0 - нет подключения
## должен щелкать только по свободным контурам, 0 и своему, если он есть

func _on_contour_id_item_selected(index: int):
	if not current_target: return
	
	var power_clip = null
	if current_target.has_comp(C_PowerClip):
		power_clip = current_target.get_comp(C_PowerClip)

	if not power_clip: return
	
	# Извлекаем зашитый ID контура из выбранного пункта меню
	var new_contour_id = %ClipContourIDButton.get_item_id(index)
	
	# Если значение изменилось — обновляем данные компонента
	if power_clip.contour_id != new_contour_id:
		power_clip.set_contour(new_contour_id)
		# Вешаем на трак новый контур
		current_target.get_comp(C_PowerTrack).contour_id = new_contour_id

		# Оповещаем менеджер о перерасчете графа дорог (если такой метод есть)
		if PowerGridManager.has_method("recalculate_topology"):
			PowerGridManager.recalculate_topology()

		# На всякий случай перерисовываем панель, чтобы закрепить состояние
		_update_power_tab()
		


	
## Кнопка вешает PowerClip на трак

func _on_power_clip_button_pressed() -> void:
	if not current_target or not current_target.has_comp(C_PowerTrack):
		return # это powertrack?
	
	var target_contour: int = %ClipContourIDButton.selected
		
	# Проверяем: если контур равен 0 (игрок не выбрал конкретный канал)
	if target_contour == 0:
		target_contour = PowerGridManager.get_free_contour_id()
		# Обновляем UI, чтобы игрок сразу визуально увидел, какой контур ему выдали
		%ClipContourIDButton.selected = target_contour

	
	if  %PowerClipButton.button_pressed: # нажата 
		# Вешаем C_PowerClip 
		var power_clip = C_PowerClip.new()
		#power_clip.contour_id = target_contour
		current_target.add_component(power_clip)
		power_clip.set_power(target_contour, 0)
		
		# Вешаем на трак контур
		current_target.get_comp(C_PowerTrack).contour_id = target_contour
		
	else : # отжата 
		current_target.remove_component(C_PowerClip)
		# Снимаем контур с трака
		current_target.get_comp(C_PowerTrack).contour_id = 0
		
	_update_power_tab()
