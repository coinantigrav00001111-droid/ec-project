class_name BuildController extends Node 

########################
##    BuildController 
## 💡 Занимается обработкой нажатий в режиме игры BUILD 💡
########################
## Ловит Сигнал из панелей build 

@export var anim_time := 0.4

@onready var mode_controller: ModeController = %ModeController

# ⚡Сигнал обновление инфы
signal update_info
# ⚡Сигнал объект выбран
signal object_selected(setting)

var current_cat = &'idle'
var current_tag = &'idle'

## Список категорий
var category_list = {
	&"track": {
		"id": &"track",
		"name": "Tracks",
		"icon": preload("res://ui/icons/transport/railway.svg")
	},
	&"train": {
		"id": &"train",
		"name": "Trains",
		"icon": preload("res://ui/icons/transport/steam-locomotive.svg")
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
	}
}



func _ready() -> void:

	pass



## ⚡Сигнал Универсальная функция приема объекта для спавна из кнопок объектов 
func on_object_selected(_asset :EntitySetting):
	#ui_controller.object_selected(_asset)
	object_selected.emit(_asset)


## ⚡Сигнал из кнопок тегов
func on_tag_selected(_new_tag : StringName):
	current_tag = _new_tag
	%UIGenerator.create_btn_objects(current_cat, _new_tag)
	# ⚡Сигнал инфа
	update_info.emit()


## ⚡Сигнал из кнопок кат.
func on_category_selected(_new_cat : StringName):
	if _new_cat == current_cat: 
		_new_cat = &'idle' # Если кнопка отжата, то в идл
		current_tag = &'idle'
	current_cat = _new_cat
	
	## Надо показать панели выбранной кат.
	on_show_panel(current_cat)
	# ⚡Сигнал инфа
	update_info.emit()
	
	
##=========== ex ToolController ==============================================
##⚡Сигнал из BUILDCONTR принимаем - Показать\спрятать панели
func on_show_panel(_cat: StringName) -> void:
	# Включаем панель. Теперь уже только одну, которую будем набивать кнопками
	if _cat != &'idle':
		
		%UIGenerator.create_btn_tags(current_cat) # кнопки тегов
		%CatTitle.text = (current_cat) # Заголовок окна
		animate_wrapper(%CatContainer)# Показывает lvl2 контейнеры
	
	else: 
		%CatContainer.hide()



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
	
