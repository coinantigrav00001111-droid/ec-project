extends Button
class_name Lvl2CategoryButton

#####################################
## Класс для создания кнопок 2лвл в панели
#####################################

## Получает ресурс wagon_setting_res и из него заполняет метки и закладку для размещения в функции config.
## при нажатии запускает GM.select_object()


var object_setting_res  # Ресурс настройки вагона

@onready var name_label: Label = $NameLabel
@onready var index_label: Label = $IndexLabel

# это делается только если кнопка ставится через редактор, иначе там где создается
func _ready() -> void:
	#var _w_res = load("res://trains/objects/ghost_node.tres")
	#config(_w_res)# передача в кнопку трака
	pass
## Конфигурация кнопки при создании
#func config(_wagon_res : WagonSetting):
	#wagon_setting_res = _wagon_res 
	
	
	#FIXME  Вредакторе уже есть гост, поэтому 2 строки ниже убраны, чтобы не било ошибку.
	#  Если все будет динамическе то тут надо сделать как в траке наверн
	#var tab :Container = tab_select() # Выбор закладки для размещения
	#tab.add_child(self) # в контейнер
	#
	#self.icon = wagon_setting_res.icon
	#self.name_label.text = wagon_setting_res.name
	#self.tag_label.text = wagon_setting_res.tag
	#self.index_label.text = str(wagon_setting_res.id)
	#UI.button_unpress.connect(on_button_unpress) # подключение к сигналу отмены нажатия
#


## Выбор закладки для размещения кнопки
#func tab_select() -> Container:
	#var _container
	#match wagon_setting_res.tab:
		#0 : _container =  UI.get_node('%LocoContainer')
		#1 : _container =  UI.get_node('%WagonHBoxContainer1')
		#2 : _container =  UI.get_node('%WagonHBoxContainer2')

	#return _container


########################
## Сигналы
########################

## запускаем обработку нажатия
#func _on_pressed() -> void:
	#GM.select_object(wagon_setting_res, button_pressed)
	#pass


### Для сигнала отмены. При нажатии 1лвл отменяет нажатие кнопки 2лвл 
#func on_button_unpress():
	#if button_pressed:
		#UI.info_panel.info_update.emit(false) # сигнал в панельинфо
		#button_pressed = false
