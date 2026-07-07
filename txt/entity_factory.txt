class_name EntityFactory extends Node

##############################
## 📦 EntityFactory Factory (создание сущностей)
##############################
## Вызывается в build_tool при создании госта(нажали на кнопку) и реал объекта(клон госта по лкм)

func create_from_setting(_setting: EntitySetting) -> Entity:
	var entity = Entity.new()
	
	# 1. Автоматически вешаем C_Identity (без массива components)
	var identity = C_Identity.new()
	identity.setting = _setting
	entity.add_component(identity)
	
	# 2.Прикрутим массив кастомных способностей из инспектора
	for comp_setting in _setting.components:
		comp_setting.create_component(entity)

	return entity
