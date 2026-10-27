class_name TrainVisualSettings extends ComponentSettings

## Собирает C_TrainVisual
## Подключается в массив сеттингов компонентов в редакторе ентити. Сцена по умолчанию, нужная цепляется в редакторе.

# Сцена грузится из идентити
#var scene: PackedScene = preload("res://data/trains/default_wagon.tscn")

## Фабрика запустит эту функцию создания
func create_component(entity: Entity) -> Component:
	var comp = C_TrainVisual.new()
	var identity = entity.get_comp(C_Identity)

	if identity:
		comp.scene = identity.get_config('scene', null)	
		
	comp.name = 'C_TrainVisual'
	entity.add_component(comp) # Добавили комп к объекту
	
	return comp
