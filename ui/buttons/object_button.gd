class_name ObjectButton extends Button

#####################################
## Класс для создания кнопок объектов 4lvl 
#####################################
## 
## Кнопку создает ToolbarController и подключает к себе ⚡Сигнал btn_pressed_object_selected. Дальше объект уходит приемнику режима
## (Build: сигнал ToolbarController.object_selected, его ловит ToolController).

##💡 Все свойства объекта тут
var object: Resource

## ⚡Сигнал нажатия на кнопку
signal btn_pressed_object_selected(object)



func _ready() -> void:
	# ⚡ Коннект к стандартному сигналу кнопки
	pressed.connect(_on_pressed) 



### Конфигурация кнопки при создании
func config(_obj: Resource) -> void:
	object = _obj
	$NameLabel.text = _obj.name
	self.icon = _obj.icon
	# Вторая строка: сводка признаков (дерево · с балластом). Пусто у объектов без признаков
	var summary := ""
	if _obj is EntitySetting:
		summary = CatalogMeta.facet_summary(_obj.category, _obj.get_facet)
	$SummaryLabel.text = summary
	$SummaryLabel.visible = summary != ""
	# Ключ мелко внизу только в debug
	$IndexLabel.visible = Global.debug_mode
	$IndexLabel.text = str(_obj.get_key()) if _obj is EntitySetting else str(_obj.id)
	if _obj is EntitySetting:
		tooltip_text = str(_obj.description)
	
	# для 2d тегов(вс контроллеры делаем побольше кнопки) (68 обычные)
	if object.tag == &'2d':
		$".".add_theme_constant_override("icon_max_width", 112)

## Если надо Имитировать нажатие, чтобы сработал скрипт смены контента
func select_as_default() -> void:
	# 1. Заставляем кнопку визуально выглядеть нажатой (фокус)
	grab_focus() 
	
	# 2. Имитируем нажатие, чтобы сработал скрипт 
	emit_signal("pressed") 



## ⚡Сигнал подключает ToolbarController при создании кнопки
func _on_pressed() -> void:
	emit_signal("btn_pressed_object_selected", object)
