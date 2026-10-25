class_name BuildController extends Node 

########################
##    BuildController -  UI
## 💡 Занимается обработкой нажатий в режиме игры BUILD 💡
########################
## Ловит Сигнал из панелей build 

@export var anim_time := 0.4

@onready var mode_controller: ModeController = %ModeController
@onready var obj_container: GridContainer = %BuBtnGridContainer
#@onready var ui_generator: UIGenerator #= %UIGenerator

#загрузка кнопки объекта
var obj_btn_scene := preload("res://ui/buttons/object_button.tscn") 

# ⚡Сигнал обновление инфы
#signal update_info
# ⚡Сигнал объект выбран
signal object_selected(setting)
# XX claude-terra 13.1.4: ⚡нажата кнопка "Дубль" (последний поставленный объект)
signal duplicate_requested


var current_cat = &'idle'
var current_tag = &'idle'

# XX claude-terra 13.1.4: кнопка дубля создается кодом (под заголовком панели), в ui.tscn ничего не меняется
var _dup_btn: Button


func _ready() -> void:
	_dup_btn = Button.new()
	_dup_btn.text = "Дубль  (V)"
	_dup_btn.focus_mode = Control.FOCUS_NONE   # чтобы Пробел и Enter не нажимали кнопку, а клавиши работали в игре
	_dup_btn.disabled = true
	_dup_btn.tooltip_text = "Еще один такой же, как последний построенный (клавиша V)"
	_dup_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_dup_btn.pressed.connect(func(): duplicate_requested.emit())
	var box: Node = %BuCatTitle.get_parent()
	box.add_child(_dup_btn)
	box.move_child(_dup_btn, %BuCatTitle.get_index() + 1)


## ⚡Сигнал BuildTool.last_changed: появился или сменился последний поставленный объект
func on_last_changed(setting: EntitySetting) -> void:
	_dup_btn.disabled = setting == null
	if setting != null:
		_dup_btn.tooltip_text = "Еще один: %s (клавиша V)" % setting.name

## Список категорий
var category_list = {
	&"train": {
		"id": &"train",
		"name": "Trains",
		"icon": preload("res://ui/icons/transport/steam-locomotive.svg")
	},
	&"track": {
		"id": &"track",
		"name": "Tracks",
		"icon": preload("res://ui/icons/transport/railway.svg")
	},
	&"building": {
		"id": &"building",
		"name": "Building",
		"icon": preload("res://ui/icons/house/house.svg")
	},
	&"decor": {
		"id": &"decor",
		"name": "Decor",
		"icon": preload("res://ui/icons/house/beech.svg")
	},
	&"terrain": {
		"id": &"terrain",
		"name": "Terrain",
		"icon": preload("res://ui/icons/tool/spade.svg")
	},
}


## ⚡Сигнал функция приема объекта для спавна из кнопок объектов 
func on_object_selected(_asset :EntitySetting):
	object_selected.emit(_asset)



## Отменяет нажатие кнопок объектов при пкм в режиме билд
func object_deselected():
	for _btn in obj_container.get_children():
		_btn.button_pressed = false



## ⚡Сигнал из кнопок тегов
func on_tag_selected(_new_tag : StringName):
	current_tag = _new_tag
	if current_cat !=  &'idle':
		create_btn_objects(current_cat, _new_tag)
	# ⚡Сигнал инфа
	#update_info.emit()


## ⚡Сигнал из кнопок кат.
func on_category_selected(_new_cat : StringName):
	if _new_cat == current_cat: 
		_new_cat = &'idle' # Если кнопка отжата, то в идл
		current_tag = &'idle'
	current_cat = _new_cat
	
	## Надо показать панели выбранной кат.
	show_category_panel(current_cat)
	# ⚡Сигнал инфа
	#update_info.emit()



func create_btn_objects(_cat : StringName, _tag : StringName):
	for _btn in %BuBtnGridContainer.get_children():
		_btn.queue_free()
	
	var obj_list = %UIGenerator.get_objects(_cat, _tag)
	if obj_list.size() == 0: 
		return # Если нет тегов, то выход
		
	for _obj in obj_list:
		var btn : ObjectButton = obj_btn_scene.instantiate() #экземпляр кнопки
		btn.config(_obj)
		%BuBtnGridContainer.add_child(btn)
		# подключение сигнала кнопки к билдконтроллеру
		btn.btn_pressed_object_selected.connect(on_object_selected)	
		
		
##==============================================
##⚡Сигнал из BUILDCONTR принимаем - Показать\спрятать панель 
func show_category_panel(_cat: StringName) -> void:
	# Включаем панель. Теперь уже только одну, которую будем набивать кнопками
	if _cat != &'idle':
		
		%UIGenerator.create_btn_tags(current_cat, 'Build') # кнопки тегов
		%BuCatTitle.text = (current_cat) # Заголовок окна
		animate_wrapper(%BuildObjectsContainer)# Показывает lvl2 контейнеры
	
	else: 
		%BuildObjectsContainer.hide()



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
	
