class_name CategoryButton extends Button

#####################################
## Класс для создания кнопок 2лвл в панели
#####################################

##TODO кнопка  77x36 неплохо выглядит

var category: StringName

## ⚡Сигнал нажатия на кнопку
signal category_selected(category)



func _ready() -> void:
	# ⚡ Коннект к стандартному сигналу кнопки
	pressed.connect(_on_pressed) 



### Конфигурация кнопки при создании
func config(_cat) -> void:
	self.category = _cat['id']
	self.text = str(_cat['name']) # или локализация
	self.icon = _cat['icon']



## ⚡Сигнал будет подключен к билдконтроллеру (через UIGenerator при создании кнопки), 
func _on_pressed() -> void:
	emit_signal("category_selected", category)
