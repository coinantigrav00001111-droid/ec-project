class_name SaveController extends Node

const SAVE_DIR = "res://saves/"

# Ссылка на узел дерева, где лежат все рельсы
@onready var world_entities_root = "/root/GameRoot/World/EntitiesRoot"


func _ready() -> void:
	load_game('autosave', false)
	pass


## Завершение работы
func _notification(what):
	# Срабатывает при закрытии окна (крестик, Alt+F4)
	if what == NOTIFICATION_WM_CLOSE_REQUEST: 
		save_game('autosave')
		get_tree().quit() # Разрешаем выход после сохранения
		
	# Непонятно зачем, но Срабатывает при штатном выходе через get_tree().quit()
	elif what == NOTIFICATION_PREDELETE:
		save_game()
		pass



#-------SAVE----------

func save_game(slot_name: String ='savegame') -> void:

	## 💡 Данные для сохранения НЕ СУЩНОСТЕЙ
	# В txt не подойдет
	var save_data = {
		#"game_version": "1.0",
		#"global_managers": {
			#"gimbal" : _gimbal.save_global_state(),
			##"PowerGrid": PowerGridManager.save_global_state()
		#},
		"entities": []
	}
	
	#🚩сюда будем собирать все данные для сохранения
	#SavedGame - ресурс содержит все данные игры
	var _saved_game : SavedGame = SavedGame.new()
	
	# 1️⃣ сохраняем камеру через ее метод
	_saved_game.gimbal =  $"../Gimbal".save_global_state()

	# 💡 Собираем все сущности на столе
	#TODO пока не собрано
	
	var root_node = get_node_or_null(world_entities_root)
	if root_node:
		for child in root_node.get_children():
			if child is Entity:
				var e_data = child.save_entity()
				if not e_data.is_empty():
					save_data["entities"].append(e_data)
					
	#await  get_tree().process_frame
	var _save_path = SAVE_DIR + slot_name + ".tres"
	ResourceSaver.save(_saved_game, _save_path )
	print("Игра успешно сохранена в: ", _save_path)



#-------LOAD----------
# пока не решен вопрос предметами не ентити, то with_clear_scene=false - не чистит сцену
func load_game(slot_name: String  ='savegame', with_clear_scene = true) -> void:
	var save_path = SAVE_DIR + slot_name + ".tres"

	#🚩res все данные игры собраны здесь
	var _saved_game :SavedGame = load(save_path) as SavedGame #автокомплит
	
	# 1️⃣ загружаем камеру вызывая ее метод
	$"../Gimbal".load_global_state(_saved_game.gimbal)
	
	
	#var save_data 
	var root_node = get_node(world_entities_root)
	
	# 1. ПОЛНАЯ ОЧИСТКА СТАРОГО МАКЕТА
	if with_clear_scene:
		for child in root_node.get_children():
			child.queue_free()
	
		# Ждем, пока Godot гарантированно удалит старые объекты из памяти и физики
		await get_tree().process_frame

	#TODO Менеджеры и ентити пока не сделаны.
	# 2. ВОССТАНОВЛЕНИЕ МЕНЕДЖЕРОВ
	#if save_data.has("global_managers"):
		#var managers = save_data["global_managers"]
		#if managers.has("gimbal"): 
			#_gimbal.load_global_state(managers["gimbal"])
		#if managers.has("PowerGrid"): 
			#PowerGridManager.load_global_state(managers["PowerGrid"])

	## 3. СПАВН СУЩНОСТЕЙ С НАКАТЫВАНИЕМ ДАННЫХ
	#for e_data in save_data["entities"]:
		#var setting_res = load(e_data["setting_path"]) as EntitySetting
		#if not setting_res: continue
#
		## Фабричный метод создания пустой сущности по ее настройкам (наверняка у вас такой есть)
		#var new_entity = _fabricate_entity_from_setting(setting_res)
		#
		## Восстанавливаем трансформацию ДО добавления в дерево
		#new_entity.global_transform = str_to_var(e_data["transform"])
		#
		## Добавляем в мир
		#root_node.add_child(new_entity)
		#
		## Накатываем сохраненные данные на компоненты
		#var comp_data_map = e_data["components"]
		#for comp_name in comp_data_map.keys():
			## Ищем компонент внутри созданной сущности по имени его скрипта
			#for child in new_entity.get_children():
				#if child is Component:
					#var current_comp_name = child.get_script().resource_path.get_file().get_basename()
					#if current_comp_name == comp_name and child.has_method("load_data"):
						#child.load_data(comp_data_map[comp_name])
						#break
#
	# 4. ВАЖНЕЙШИЙ ТАКТ СИНХРОНИЗАЦИИ ФИЗИКИ (см. Критические нюансы ниже)
	await get_tree().physics_frame
	print("Макет успешно загружен!")



func _fabricate_entity_from_setting(_setting: EntitySetting) -> Entity:
	# Базовая сборка сущности: создание инстанса Entity, добавление C_Identity, C_Visual и т.д.
	var entity = Entity.new()
	# ... ваша стандартная логика инициализации объекта по ресурсу настроек ...
	return entity
