class_name TrainVisualSettings extends ComponentSettings

## Собирает C_TrainVisual
## Подключается в массив сеттингов компонентов в редакторе ентити. Сцена по умолчанию, нужная цепляется в редакторе.


@export var scene: PackedScene = preload("res://data/tracks/default_wagon.tscn")

#TODO реализация теперь в EC?? Материалы. 
@export var settings: VisualStateSettings = preload("res://core/visual/visual_state.tres")

## Фабрика запустит эту функцию создания
func create_component(_entity: Entity) -> Component:
	var comp = C_TrainVisual.new()
	comp.scene = scene # Передаем сцену в саму ноду компонента
	
	#TODO реализация теперь в EC?? Материалы. 
	comp.visual_settings = settings 
	comp.name = 'C_TrainVisual'
	_entity.add_component(comp) # Добавили комп к объекту
	
	return comp
