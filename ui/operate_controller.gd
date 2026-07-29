class_name OperateController extends Node 

########################
##    OperateController -  UI
## 💡 Занимается обработкой нажатий в режиме игры OPERATE 💡
########################
## Ловит Сигнал из панелей operate
## OperateController также сам обрабатывает создание 2D объектов\контроллеров
## управляет своим контейнером OperateObjectsContainer для кнопок объектов и OperatePanel для кнопок категорий(2д, 3д). 

@export var anim_time := 0.4

@onready var mode_controller: ModeController = %ModeController
# сюда кнопки объектов режима operate 
@onready var obj_container: GridContainer = %OpBtnGridContainer 



#загрузка кнопки объекта. Можно заменить на побольше или поменять ее настройки
var obj_btn_scene := preload("res://ui/buttons/object_button.tscn") 

var current_cat = &'idle'
var current_tag = &'idle'

## Список категорий
var category_list = {
	&"dc_controller": {
		"id": &"dc_controller",
		"name": "DC Controllers",
		"icon": preload("res://ui/icons/settings-knobs.svg")
	},
	&"dcc_controller": {
		"id": &"dcc_controller",
		"name": "DCC Controllers",
		"icon": preload("res://ui/icons/transport/steam-locomotive.svg")
	},
}



## ⚡Сигнал ИЗ КНОПОК прием объекта для спавна  объектов. 
func on_object_selected(setting :Resource):
	#if setting == null :
	## Очищаем селекта в UI если null 
	## Отменяет нажатие кнопок объектов при пкм в режиме билд
		#object_deselected()
		#return
		
	if setting.tag == &'2d' and setting is DCControllerSetting: # точно плоский?
		# если индекс тот же то пропускаем
		#if PGM.dc_controller and PGM.dc_controller.setting.id != setting.id:
			# удаляем старый контроллер
			PGM.dc_controller.free()
			PGM.dc_controller = create_2d_dc_controller(setting)
		
	else : # Если не плоский то entity
		printt('operate selected 3д entity')
		#_on_build_selected(setting) # ушли в стройку ентити?



## Отменяет нажатие кнопок объектов при пкм в режиме билд
func object_deselected():
	for _btn in obj_container.get_children():
		_btn.button_pressed = false



## ⚡Сигнал из кнопок тегов
func on_tag_selected(_new_tag : StringName):
	current_tag = _new_tag
	create_btn_objects(current_cat, _new_tag)
	# ⚡Сигнал инфа
	#update_info.emit()


## ⚡Сигнал из кнопок кат.
func on_category_selected(_new_cat : StringName):
	if _new_cat == current_cat: 
		_new_cat = &'idle' # Если кнопка отжата, то в идл
		current_tag = &'idle'
	current_cat = _new_cat
	
	# Надо показать панели выбранной кат.
	show_category_panel(current_cat)
	# ⚡Сигнал инфа
	#update_info.emit()
	
	
	
func _ready() -> void:
	await get_tree().physics_frame
	# Подзагрузка настроек контроллера мини при старте игры
	PGM.dc_controller.setting = preload("res://ui/dc_controllers/objects/dc_2d_mini.tres")



## 💡 Создаем контроллер плоский 
func create_2d_dc_controller(setting) -> DCController:
	var new_contr
	var  _scene :PackedScene  = setting.scene
	new_contr =  _scene.instantiate()	# создали экземпляр сцены
	new_contr.new_setting(setting)
	get_node('..').add_child(new_contr) # Корень UI

	return new_contr



# ==============================================
##⚡Сигнал принимаем - Показать\спрятать панели
func show_category_panel(_cat: StringName) -> void:
	# Включаем панель. Теперь уже только одну, которую будем набивать кнопками
	if _cat != &'idle':
		
		%UIGenerator.create_btn_tags(current_cat, 'Operate') # Создаем кнопки тегов
		%OpCatTitle.text = (current_cat) # Заголовок окна
		animate_wrapper(%OperateObjectsContainer)# Показывает lvl2 контейнеры
	
	else: 
		%OperateObjectsContainer.hide()



func create_btn_objects(_cat : StringName, _tag : StringName):
	for _btn in %OpBtnGridContainer.get_children():
		_btn.queue_free()
	
	var obj_list = %UIGenerator.get_objects(_cat, _tag)
	if obj_list.size() == 0: 
		return # Если нет тегов, то выход
		
	for _obj in obj_list:
		var btn : ObjectButton = obj_btn_scene.instantiate() #экземпляр кнопки
		btn.config(_obj)
		%OpBtnGridContainer.add_child(btn)
		# подключение сигнала кнопки к контроллеру
		btn.btn_pressed_object_selected.connect(on_object_selected)	
		

#
## Анимированный показ панели
func animate_wrapper(_panel) -> void:
	var wrapper = _panel.get_node_or_null('AnimatedWrapper')
	
	if !wrapper: # Если без враппера то и  без аниме
		_panel.show()
		return

	var _tween := create_tween().set_parallel(true)\
						.set_trans(Tween.TRANS_QUINT)\
						.set_trans(Tween.TRANS_BACK)\
						.set_ease(Tween.EASE_OUT)

	# Используем оболочку враппер для анимаций
	wrapper.get_parent().show()

	# смещение вниз перед анимацией на высоту панели
	var start_offset :int = wrapper.size.y

	wrapper.modulate.a = 0 # Но делаем прозрачной
	
	wrapper.offset_transform_position.y = start_offset

	_tween.tween_property(wrapper, "offset_transform_position:y",0, anim_time)
	_tween.tween_property(wrapper, "modulate:a", 1.0, anim_time)
	
