class_name UIGenerator extends Node

########################
## UIGenerator
## Остаток после U3: кнопки категорий Observe и начальное состояние панелей
########################
## Каталог объектов (категории, теги, объекты) и кнопки Build и Operate теперь в
## ui/toolbar/ (ToolbarController, EntityCatalogProvider). Здесь осталось то, что делает Observe.
## Уйдет в U4, когда Observe перейдет на общий каталог (провайдер карточек).

@onready var observe_controller: ObserveController = get_node_or_null('%ObserveController')

#загрузка кат кнопки
var cat_btn_scene := preload("res://ui/buttons/category_button.tscn") 


func _ready() -> void:
	if observe_controller and not Global.fast_debug:
		_create_btn_categories(observe_controller, %ObserveBtnLvl2Container)
	if Global.fast_debug:
		# Режим быстрой загрузки: Observe недоступен
		var ob := get_tree().root.find_child("ObserveButton", true, false)
		if ob:
			ob.hide()

	# Задержка, чтобы создались кнопки, иначе нулевые размеры врапперов
	await get_tree().process_frame
	# После создания размеров врапперов выключаем видимость контейнеров
	if observe_controller:
		%ObserveObjectsContainer.hide()
		%ObservePanel.hide()


## Создает кнопки категорий контроллера в контейнер
func _create_btn_categories(_controller: Node, _container: Node) -> void:
	for _cat in _controller.category_list: # проход по категориям
		var _cat_btn: CategoryButton = cat_btn_scene.instantiate()
		_cat_btn.config(_controller.category_list[_cat])
		_container.add_child(_cat_btn)
		# подключение сигнала кнопки к контроллеру
		_cat_btn.category_selected.connect(_controller.on_category_selected)
