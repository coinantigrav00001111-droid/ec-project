class_name OperateController extends Node

########################
##    OperateController - UI
## 💡 Адаптер режима OPERATE для ToolbarController 💡
########################
## Кнопки и анимация теперь в ToolbarController. Здесь осталось то, что знает только Operate:
## какие объекты показывать (каталог) и что делать с выбранным (создать 2D контроллер питания).

## Текущая 2D панель питания. Владелец панели это OperateController (D2), PGM о панелях не знает:
## питание хранится в PowerSource, панель его только забирает (PGM.register_source)
var dc_panel: DCController


func _ready() -> void:
	%ToolbarController.register_mode(&"operate", EntityCatalogProvider.new(&"operate"), on_object_selected)
	# Мини-панель, лежащая в сцене UI, получает свои настройки (без ожидания кадра: гонки нет)
	dc_panel = _find_panel()
	if dc_panel:
		dc_panel.setting = preload("res://ui/dc_controllers/objects/dc_2d_mini.tres")


func _find_panel() -> DCController:
	for child in get_parent().get_children():
		if child is DCController:
			return child
	return null


## ⚡Приемник: объект из кнопки каталога
func on_object_selected(setting: Resource) -> void:
	if setting.tag == &'2d' and setting is DCControllerSetting: # точно плоский?
		# Снимаем старую панель из дерева сразу (не отложенно): её источник освобождается в _exit_tree,
		# новая панель той же модели забирает его с командами, питание не пропадает и не дублируется
		if is_instance_valid(dc_panel):
			dc_panel.hide()
			dc_panel.get_parent().remove_child(dc_panel)
			dc_panel.queue_free()
		dc_panel = create_2d_dc_controller(setting)
	elif setting is EntitySetting: # 3D-пульт и инструмент «Провод»: тот же путь, что у стройки (призрак, клик)
		var tc := get_tree().get_first_node_in_group(&"tool_controller") as ToolController
		if tc:
			tc.select_build_object(setting)


## 💡 Создаем контроллер плоский
func create_2d_dc_controller(setting) -> DCController:
	var new_contr
	var _scene: PackedScene = setting.scene
	new_contr = _scene.instantiate()	# создали экземпляр сцены
	new_contr.new_setting(setting)
	get_node('..').add_child(new_contr) # Корень UI

	return new_contr
