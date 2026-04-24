class_name ObjectButton extends Button

#####################################
## Класс для создания кнопок объектов 4lvl 
#####################################

##💡 Все свойства объекта тут
var object: EntitySetting

## ⚡Сигнал нажатия на кнопку
signal object_selected(object)



func _ready() -> void:
	# ⚡ Коннект к стандартному сигналу кнопки
	pressed.connect(_on_pressed) 



### Конфигурация кнопки при создании
func config(_obj: EntitySetting) -> void:
	object = _obj
	$NameLabel.text = _obj.name
	self.icon = _obj.icon
	$IndexLabel.text = str(_obj.id)



## Если надо Имитировать нажатие, чтобы сработал скрипт смены контента
func select_as_default() -> void:
	# 1. Заставляем кнопку визуально выглядеть нажатой (фокус)
	grab_focus() 
	
	# 2. Имитируем нажатие, чтобы сработал скрипт 
	emit_signal("pressed") 



## ⚡Сигнал будет подключен к билдконтроллеру (через UIGenerator при создании кнопки), 
func _on_pressed() -> void:
	emit_signal("object_selected", object)
