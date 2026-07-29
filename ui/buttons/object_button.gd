class_name ObjectButton extends Button

#####################################
## Класс для создания кнопок объектов 4lvl 
#####################################
## 
## При создании экземпляра кнопки ObjectButton в UIgenerator ⚡Сигнал object_selected коннектится  к билд-контроллеру(ui), у которого есть свой ⚡Сигнал object_selected. ⚡Сигнал Билд-контроллера уже ловит и обрабатывает Tool контроллер.

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
	$IndexLabel.text = str(_obj.id)
	
	# для 2d тегов(вс контроллеры делаем побольше кнопки) (68 обычные)
	if object.tag == &'2d':
		$".".add_theme_constant_override("icon_max_width", 112)

## Если надо Имитировать нажатие, чтобы сработал скрипт смены контента
func select_as_default() -> void:
	# 1. Заставляем кнопку визуально выглядеть нажатой (фокус)
	grab_focus() 
	
	# 2. Имитируем нажатие, чтобы сработал скрипт 
	emit_signal("pressed") 



## ⚡Сигнал будет подключен к билдконтроллеру (через UIGenerator при создании кнопки), 
func _on_pressed() -> void:
	emit_signal("btn_pressed_object_selected", object)
