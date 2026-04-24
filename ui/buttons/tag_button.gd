class_name TagButton extends Button

#####################################
## Класс для создания кнопок 3лвл
#####################################


var tag: StringName

## ⚡Сигнал нажатия на кнопку
signal tag_selected(tag)



func _ready() -> void:
	# ⚡ Коннект к стандартному сигналу кнопки
	pressed.connect(_on_pressed) 



### Конфигурация кнопки при создании
func config(_tag) -> void:
	self.tag = _tag['id']
	self.text = str(_tag['name']) # или локализация
	self.icon = _tag['icon']


func select_as_default() -> void:
	# 1. Заставляем кнопку визуально выглядеть нажатой (фокус)
	grab_focus() 
	
	# 2. Имитируем нажатие, чтобы сработал ваш скрипт смены контента
	emit_signal("pressed") 



## ⚡Сигнал будет подключен к билдконтроллеру (через UIGenerator при создании кнопки), 
func _on_pressed() -> void:
	emit_signal("tag_selected", tag)
