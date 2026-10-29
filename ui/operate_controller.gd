class_name OperateController extends Node

########################
##    OperateController - UI
## 💡 Адаптер режима OPERATE для ToolbarController 💡
########################
## Кнопки и анимация теперь в ToolbarController. Здесь осталось то, что знает только Operate:
## какие объекты показывать (каталог) и что делать с выбранным (создать 2D контроллер питания).

func _ready() -> void:
	%ToolbarController.register_mode(&"operate", EntityCatalogProvider.new(&"operate"), on_object_selected)
	await get_tree().physics_frame
	# Подзагрузка настроек контроллера мини при старте игры
	PGM.dc_controller.setting = preload("res://ui/dc_controllers/objects/dc_2d_mini.tres")


## ⚡Приемник: объект из кнопки каталога
func on_object_selected(setting: Resource) -> void:
	if setting.tag == &'2d' and setting is DCControllerSetting: # точно плоский?
		# удаляем старый контроллер
		if is_instance_valid(PGM.dc_controller):
			PGM.dc_controller.hide()
			PGM.dc_controller.queue_free()
		PGM.dc_controller = create_2d_dc_controller(setting)
	else: # Если не плоский, то entity
		printt('operate selected 3д entity')


## 💡 Создаем контроллер плоский
func create_2d_dc_controller(setting) -> DCController:
	var new_contr
	var _scene: PackedScene = setting.scene
	new_contr = _scene.instantiate()	# создали экземпляр сцены
	new_contr.new_setting(setting)
	get_node('..').add_child(new_contr) # Корень UI

	return new_contr
