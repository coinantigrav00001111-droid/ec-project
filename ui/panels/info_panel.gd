class_name InfoPanel extends PanelContainer

###########################
## InfoPanel. Панель сведений о выбранном объекте
###########################
## Только реестр вкладок. Вся логика во вкладках ui/panels/info/ (базовый класс InfoTab, U5):
## панель привязывает цель, показывает вкладки по can_show (а не по номеру) и 10 раз в секунду
## обновляет только активную вкладку.
## Цель приходит сигналом ToolController.selection_changed.

@onready var tab_container: TabContainer = %TabContainer

## Частота обновления живых значений активной вкладки, раз в секунду
const REFRESH_HZ := 10.0

var current_target: Entity

## ⚡Сигнал для спидометра
signal s_select_entity( sel_entity:Variant, spdmetr_on: bool, vert :bool)

var _tabs: Array[InfoTab] = []
var _power: InfoPowerTab
var _transform: InfoTransformTab
var _debug: InfoDebugTab
var _acc := 0.0


func _ready() -> void:
	add_to_group(&"info_panel")   # по группе её находит спидометр
	hide() # Прячем панель на старте
	# ⚡Сигнал из ToolController: какой объект показывать
	var _tc := get_node_or_null("../../ToolController")
	if _tc:
		_tc.selection_changed.connect(set_target)

	_power = InfoPowerTab.new()
	_transform = InfoTransformTab.new()
	_debug = InfoDebugTab.new()
	# Вкладки из сцены, в порядке сцены; затем вкладки, создаваемые кодом
	_add_tab(InfoMainTab.new(), tab_container.get_node("MainTab"))
	_add_tab(_power, tab_container.get_node("PowerTab"))
	_add_tab(_transform, tab_container.get_node("TransformTab"))
	_add_tab(_debug, tab_container.get_node("DebugTab"))
	_add_tab(InfoMechTab.new())
	_add_tab(InfoTerrainTab.new())
	_add_tab(InfoSwitchTab.new())
	_update_tab_visibility()

	# Трак питания обновляется по сигналам менеджера, поезд живыми значениями вкладки
	PGM.power_tab_updated.connect(_power.update_tab)
	PGM.power_updated.connect(_power.on_power_track_updated)


func _add_tab(tab: InfoTab, scene_control: Control = null) -> void:
	tab.setup(self, scene_control)
	_tabs.append(tab)


func _process(delta: float) -> void:
	if not visible or current_target == null:
		return
	_acc += delta
	if _acc < 1.0 / REFRESH_HZ:
		return
	_acc = 0.0
	var active := tab_container.get_current_tab_control()
	for tab in _tabs:
		if tab.control == active:
			tab.refresh()
			break


## Вызывается ToolController (selection_changed), когда выбор сменился
func set_target(entity: Entity) -> void:
	# Камера вагона включена: этот клик ее только выключает
	if _debug.wagon_camera_active():
		_debug.release_wagon_camera()
		return

	# 1. Отписываемся от старого объекта
	if is_instance_valid(current_target):
		current_target.component_added.disconnect(_on_components_changed)
		current_target.component_removed.disconnect(_on_components_changed)
	for tab in _tabs:
		tab.unbind()

	current_target = entity

	# 2. Если кликнули в пустоту - прячем панель
	if not current_target:
		s_select_entity.emit(null, false, false)
		hide()
		return

	# 3. Подписываемся на новый объект (компоненты добавляются и убираются)
	current_target.component_added.connect(_on_components_changed)
	current_target.component_removed.connect(_on_components_changed)

	# INFO Панель спидометра: его переключатели живут на вкладке «Положение»
	var spd := _transform.speedometer_state()
	s_select_entity.emit(current_target, spd[0], spd[1])

	show()

	# 4. Привязываем вкладки и выставляем видимость по can_show
	for tab in _tabs:
		tab.bind(current_target)
	_update_tab_visibility()


## Прячет вкладки, которые не подходят цели. Если активная спряталась, открывается первая
func _update_tab_visibility() -> void:
	for tab in _tabs:
		var idx := tab_container.get_tab_idx_from_control(tab.control)
		tab_container.set_tab_hidden(idx, not tab.can_show(current_target))
	var current := tab_container.get_current_tab_control()
	var idx_now := tab_container.get_tab_idx_from_control(current)
	if idx_now < 0 or tab_container.is_tab_hidden(idx_now):
		tab_container.current_tab = 0


## Вызывается ТОЛЬКО когда у цели добавился или удалился компонент
func _on_components_changed(_type: Script) -> void:
	for tab in _tabs:
		tab.components_changed()
