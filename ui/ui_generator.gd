class_name UIGenerator extends Node

########################
## UIGenerator
## Генератор кнопок UI BUILD режима (пока только его)
########################
 
## Генерит кнопки для категорий, тегов и объектов
 
## ⭐ золотое правило: «Сигналы — вверх, вызовы функций — вниз».
#Родитель знает о дочерних узлах и может вызывать их функции напрямую.
#Дочерние узлы не должны знать о родителе, поэтому они сообщают о событиях через сигналы.




@export var icon_from_config := true # иконки собираем из объектов 

@onready var build_controller: BuildController = %BuildController

## Словарь ССЫЛОК на ресурсы category → tag → objects
var data := {} 
# Структура data
#data = {
	#"track": {
		#"straight": [obj1, obj2],
		#"curve": [obj3]
	#}
#}

## Еще словарь с объектами
var objects_by_id := {}
# Структура objects_by_id
#objects_by_id = {
	#1: obj1,
	#2: obj2
#}

	#printt(_object_list.size())
	#printt(get_categories())
	#printt(get_tags(get_categories()[0]))
	#printt(get_tags(get_categories()[1]))
	#printt('======')
	#printt(get_objects(&"train", &"loco")) #
	#printt(get_objects(&"track", &"straight")) #
	#printt('=== Obj===')
	#printt(objects_by_id, objects_by_id.size()) #
	#printt('Obj  0')
	#printt(objects_by_id[1]) #



## Папки с объектами
##TODO вынести в конфиг папки с объектами
var objects_dirs := ["res://data/tracks/objects/"]
var cat_btn_scene := preload("res://ui/buttons/category_button.tscn") #загрузка кат кнопки
var tag_btn_scene := preload("res://ui/buttons/tag_button.tscn") #загрузка тег кнопки 
var obj_btn_scene := preload("res://ui/buttons/object_button.tscn") #загрузка тег кнопки 


## Заполняет контейнер кнопками 2 lvl. Вызывается в gameroot 
func _ready() -> void:
	var _object_list := _collect_data() 	# Собрали список объектов

	_build_data(_object_list) 			# Пересобрали списки по кат\тегам и id 
	create_btn_categories()

	# Задержка, чтобы создались кнопки, иначе нулевые размеры врапперов
	await get_tree().process_frame
	# После создания размеров врапперов выключаем видимость контейнеров
	%CatContainer.hide()
	%BuildPanel.hide()


##======= Objects ===========

func create_btn_objects(_cat : StringName, _tag : StringName):
	for _btn in %ObjContainer.get_children():
		_btn.queue_free()
	
	var obj_list = get_objects(_cat, _tag)
	if obj_list.size() == 0: 
		return # Если нет тегов, то выход
		
	for _obj in obj_list:
		var btn : ObjectButton = obj_btn_scene.instantiate() #экземпляр кнопки
		btn.config(_obj)
		%ObjContainer.add_child(btn)
		# подключение сигнала кнопки к билдконтроллеру
		btn.object_selected.connect(build_controller.on_object_selected)	

	



## Создает кнопки тегов при нажатии на категорию (см UIGenerator)
func create_btn_tags(_cat : StringName):
	# Очистили от старых кнопок
	for _btn in %TagPanel.get_children():
		_btn.queue_free()
	
	if !data.has(_cat): return # Если нет тегов, то выход

	var is_first_btn: bool = true # для фокуса на первой кнопке
	
	for _tag in data[_cat].keys():
		var btn : TagButton = tag_btn_scene.instantiate() #экземпляр кнопки
		# Словарь настроек для кнопки
		var btn_data ={
			"id": _tag,
			"name": _tag,
			"icon": get_tag_icon(_cat, _tag) # Из объекта
		}
		btn.config(btn_data)
		%TagPanel.add_child(btn)
		# подключение сигнала кнопки к билдконтроллеру
		btn.tag_selected.connect(build_controller.on_tag_selected)	
		
		# Если это первая кнопка — «нажимаем» её
		if is_first_btn:
			btn.select_as_default() 
			is_first_btn = false
			
	%CatTitle.text = (_cat) # Заголовок окна


## Создает кнопки для категорий
func create_btn_categories()-> void:
	for _cat in build_controller.category_list:
		var btn : CategoryButton = cat_btn_scene.instantiate() #экземпляр кнопки
		btn.config( build_controller.category_list[_cat])

		%BuildLvl2Container.add_child(btn)
		
		# подключение сигнала кнопки к билдконтроллеру
		btn.category_selected.connect(build_controller.on_category_selected)




## Собираем данные из объектов для кнопок
func _collect_data() -> Array: 
	var objects_list: Array=[]  # список объектов 
	
	for _dir in objects_dirs: # массив с путями к папкам объектов
		for _file in DirAccess.get_files_at(_dir): # Загрузка ресурс файлов траков в массив
			if !_file.ends_with('.tres'): continue # Контроль на .tres 
			
			var res :EntitySetting = load(_dir + _file)  # ресурс трака

			objects_list.append(res)

	#_objects_array.sort_custom(func(a, b): return a.id < b.id) # сортировка по индексу
	return objects_list



## Формирует data с категориями, тегами, и объектами
func _build_data(_object_list) -> void:
	for _obj in _object_list: # Крутим весь список объектов
		var cat = _obj.category 
		var tag = _obj.tag
		
		add_tag(cat, tag) # добавляет тег и кат
		data[cat][tag].append(_obj)
	
		if objects_by_id.has(_obj.id): # Пропускаем если повтор id 
			push_error("Duplicate ID: %s" % _obj.name)
			continue
		
		objects_by_id[_obj.id] = _obj # добавили объект с id 



# --------------Helpers---------------

## Получаем иконку первого объекта категории или из конфига кат
func get_category_icon(_cat) -> Texture2D:
	var _i : Texture2D
	
	if icon_from_config: # из конфига кат
		_i = build_controller.category_list[_cat].icon
		return _i
		
	# из объекта 
	var tags : Array= data[_cat].keys()
	if tags.size() == 0:
		return null
	
	var first_tag : StringName = tags[0] # первый тег в категории
	var objects : Array = data[_cat][first_tag] # Объекты с первым тегом
	
	_i = objects[0].icon # Первый объект в этом  списке
	if objects.size() == 0:
		return null

	return _i



## Получаем иконку первого объекта 
func get_tag_icon(_cat, _tag) -> Texture2D:
	var tags : Array = data[_cat].keys()
	if tags.size() == 0:
		return null
	var objects : Array = data[_cat][_tag] # Объекты с тегом
	
	if objects.size() == 0:
		return null
		
	var _icon : Texture2D = objects[0].icon # Первый объект в этом  списке
	return _icon



func add_category(_cat) -> void:
	if not data.has(_cat):
		data[_cat] = {}
		#data[_cat]['id'] = _cat



func add_tag(_cat, _tag) -> void:
	add_category(_cat)
	if not data[_cat].has(_tag):
		data[_cat][_tag] = []



## Все категории
func get_categories() -> Array:
	return data.keys()

## Все теги в категории
func get_tags(category) -> Array:
	return data[category].keys()
	
## Все объекты с тегом в категории
func get_objects(category, tag) -> Array:
	return data[category][tag]
