class_name InfoTab extends RefCounted

###########################
## InfoTab. Базовый класс вкладки InfoPanel (U5)
###########################
## Вкладка получает цель (bind), решает, показываться ли ей у этой цели (can_show), и обновляет свои значения
## в refresh(): InfoPanel зовет его 10 раз в секунду и только у активной вкладки.
## Вкладки сцены (Main, Power, Transform, Debug) находят свои узлы по имени (_n), код-вкладки (Механизмы,
## Материал, Стрелка) создают контролы сами (make_page).

var panel: InfoPanel
## Контрол вкладки в TabContainer
var control: Control
## Выбранная сущность, null пока вкладка не привязана
var target: Entity


## Зовет InfoPanel один раз. control_in_scene: готовая вкладка из info_panel.tscn или null для код-вкладки
func setup(p: InfoPanel, control_in_scene: Control = null) -> void:
	panel = p
	control = control_in_scene
	_setup()


## Показывать ли вкладку у этой сущности. Определяется компонентами цели, а не номером вкладки
func can_show(_entity: Entity) -> bool:
	return true


func bind(entity: Entity) -> void:
	target = entity
	_on_bind()


func unbind() -> void:
	target = null
	_on_unbind()


## Периодическое обновление живых значений (10 Гц, только активная вкладка). Команд не шлет
func refresh() -> void:
	pass


## У цели добавили или убрали компонент
func components_changed() -> void:
	pass


# --- для наследников ---

func _setup() -> void:
	pass


func _on_bind() -> void:
	pass


func _on_unbind() -> void:
	pass


## Узел панели по имени (узлы info_panel.tscn с unique_name_in_owner и без)
func _n(node_name: String) -> Variant:
	return panel.find_child(node_name, true, false)


## Создает код-вкладку: страницу в TabContainer с отступами. Возвращает контейнер для содержимого
func make_page(title: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = title
	panel.tab_container.add_child(page)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	page.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	control = page
	return box


## Пишет значение в SpinBox без сигнала и не мешает вводу (поле в фокусе не трогаем)
static func set_spin(spin: SpinBox, value: float) -> void:
	if spin.get_line_edit().has_focus():
		return
	spin.set_value_no_signal(value)


## Ставит параметр вагона: подвеска, сцепление, масса. Без нужных компонентов ничего не делает
func set_tuning(key: String, value: Variant) -> void:
	if target == null:
		return
	var chassis := target.get_comp(C_Chassis) as C_Chassis
	var kinemat := target.get_comp(C_Kinematics) as C_Kinematics
	match key:
		'enable_suspension': if chassis: chassis.enable_suspension = value
		'debug_susp_vertical': if chassis: chassis.debug_susp_vertical = value
		'debug_susp_pitch': if chassis: chassis.debug_susp_pitch = value
		'debug_susp_roll': if chassis: chassis.debug_susp_roll = value
		'debug_susp_lateral': if chassis: chassis.debug_susp_lateral = value
		'effect_multiplier': if chassis: chassis.effect_multiplier = value
		'longitudinal_grip': if kinemat: kinemat.longitudinal_grip = value
		'min_curve_radius': if kinemat: kinemat.min_curve_radius = value
		'max_yaw_deg': if kinemat: kinemat.max_yaw_deg = value
		'yaw_spring': if kinemat: kinemat.yaw_spring = value
		'roll_resistance': if kinemat: kinemat.roll_resistance = value
		'mass': if kinemat: kinemat.mass = value
		'max_grip': if kinemat: kinemat.max_grip = value
		'friction': if kinemat: kinemat.rb.physics_material_override.friction = value
		'linear_damp': if kinemat: kinemat.rb.linear_damp = value
		'angular_damp': if kinemat: kinemat.rb.angular_damp = value
