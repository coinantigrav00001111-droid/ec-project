class_name EntityFactory extends Node

##############################
## 📦 EntityFactory Factory (создание сущностей)
##############################

## Создает объект\сущность в uicontroller
func create_from_setting(_setting: EntitySetting) -> Entity:
	
	var entity = Entity.new() 
	entity.name = _setting.name
	# Проходим по всем ресурсам-настройкам в EntitySetting
	for s in _setting.components:
		s.create_component(entity)

	
	return entity
