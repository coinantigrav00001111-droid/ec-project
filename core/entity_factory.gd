class_name EntityFactory extends Node

##############################
## 📦 EntityFactory Factory (создание сущностей)
##############################
## Вызывается в build_tool при создании госта(нажали на кнопку) и реал объекта(клон госта по лкм)

func create_from_setting(_setting: EntitySetting) -> Entity:
	var entity = Entity.new()
	
	## 1. Автоматически уже не вешаем C_Identity, потому что object_config вешается в инспекторе
	#var identity = C_Identity.new()
	#identity.setting = _setting # этот сеттинг только у identity 
	#identity.name = 'C_Identity'
	#entity.add_component(identity)
	
	# 2.Прикрутим массив кастомных способностей из инспектора
	for comp_setting in _setting.components:
		comp_setting.create_component(entity) # делает то же что и п.1 только без сеттинга
		
		# 3. Если создан Identity , то к нему цепляем _setting из .tres 
		if comp_setting is IdentitySetting:
			entity.get_comp(C_Identity).setting = _setting

	return entity
