extends Node
class_name SaveManager  #это в автолоад прописано
###########################
##💡 SaveManager - Системный сервис(autoload), контроль загрузки сохранения
############################
#TODO Занести в автолоад

# В экспортированной игре res:// только для чтения, сейвы пишем в user://
const SAVE_DIR = "user://saves/"
# Старое место сейвов (разовый перенос) и эталонная диорама (шаблон только для чтения, грузится по F9 в debug)
const LEGACY_SAVE_DIR = "res://saves/"
const REFERENCE_DIR = "res://data/debug/"

# Ссылка на узел дерева, где лежат все рельсы
@onready var world_entities_root = "/root/GameRoot/EntitiesRoot"
@onready var entity_factory: EntityFactory = $"/root/GameRoot/EntityFactory"
@onready var info_panel: InfoPanel = $"/root/GameRoot/UI/InfoPanel"


func _ready() -> void:
	#await  get_tree().process_frame
	# Откладывает вызов функции до тех пор, пока дерево полностью не построится
	#load_game.call_deferred('autosave')
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_migrate_legacy_saves()
	load_game('autosave')
	pass


## Разово копирует сейвы из res://saves/ в user://saves/ (только то, чего там еще нет)
func _migrate_legacy_saves() -> void:
	if not DirAccess.dir_exists_absolute(LEGACY_SAVE_DIR):
		return
	for f in DirAccess.get_files_at(LEGACY_SAVE_DIR):
		if not f.ends_with('.tres') or FileAccess.file_exists(SAVE_DIR + f):
			continue
		DirAccess.copy_absolute(LEGACY_SAVE_DIR + f, SAVE_DIR + f)

#func _exit_tree() -> void:
	##await  get_tree().process_frame
	#save_game('autosave')
	

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("key_ctrl_s"):
		save_game('autosave')
	# F9 (debug): загрузить эталонную диораму
	if Global.debug_mode and _event is InputEventKey and _event.pressed and not _event.echo and _event.keycode == KEY_F9:
		load_game('reference', REFERENCE_DIR)


	
## Завершение работы
func _notification(what):
	### Срабатывает при закрытии окна (крестик, Alt+F4)
	if what == NOTIFICATION_WM_CLOSE_REQUEST: 
		#print('1')
		save_game('autosave')
		await  get_tree().process_frame
		
		get_tree().quit() # Разрешаем выход после сохранения
		##
	## Непонятно зачем, но Срабатывает при штатном выходе через get_tree().quit()
	#if what == NOTIFICATION_PREDELETE:
		#print('2')
		#save_game()
		
		###pass
	#pass



#-------SAVE----------

func save_game(slot_name: String ='savegame') -> void:

	## 💡 Данные для сохранения НЕ СУЩНОСТЕЙ
	
	#🚩сюда будем собирать все данные для сохранения
	#SavedGame - ресурс содержит все данные ИГРЫ
	var _saved_game : SavedGame = SavedGame.new()
	
	# 1️⃣ сохраняем камеру через ее метод
	_saved_game.gimbal = $"/root/GameRoot/Gimbal".save_global_state()
	#var save_data = {
		##"game_version": "1.0",
		##"global_managers": {
			##"gimbal" : _gimbal.save_global_state(),
			###"PowerGrid": PGM.save_global_state()
		##},
		#"entities": []
	#}


	# 2️⃣ Собираем все сущности на столе
	var root_node = get_node_or_null(world_entities_root)
	if root_node:
		# проход по всем ентити 
		for _entity in root_node.get_children():
			if _entity is Entity:
				var e_data = _entity.save_entity() # Ентити Выдает свои данные 
				if not e_data.is_empty():
					_saved_game.entities.append(e_data) # записали

	await  get_tree().process_frame
	
	# Запись
	var _save_path = SAVE_DIR + slot_name + ".tres"	
	var _err := ResourceSaver.save(_saved_game, _save_path)
	if _err != OK:
		push_error("Не удалось сохранить игру: %s (код %d)" % [_save_path, _err])
		return
	print("Игра успешно сохранена в: ", _save_path)



# Очистка от ентити. Хотя это больше подходит для тулза стройки, но пока тут
func clear_scene() -> void:
	var root_node = get_node(world_entities_root)

	# 1. ПОЛНАЯ ОЧИСТКА МАКЕТА
	for child in root_node.get_children():
		var clip = child.get_comp(C_PowerClip)
		if clip in PGM.active_clips:
			PGM.active_clips.erase(clip)
		child.queue_free()
		
	#INFO ДЕРГАЕМ ПАНЕЛЬ!
	info_panel.set_target(null) # Очищаем панель на всякий случай


#-------LOAD----------
func load_game(slot_name: String  ='savegame', dir: String = SAVE_DIR) -> void:
	var save_path = dir + slot_name + ".tres"
	if not FileAccess.file_exists(save_path):
		return

	#🚩res все данные игры собраны здесь
	var _saved_game :SavedGame = load(save_path) as SavedGame #автокомплит
	if not _saved_game: return
	# 1️⃣ загружаем камеру вызывая ее метод
	$"/root/GameRoot/Gimbal".load_global_state(_saved_game.gimbal)
	var root_node = get_node(world_entities_root)
	
	# 1. ПОЛНАЯ ОЧИСТКА СТАРОГО МАКЕТА
	for child in root_node.get_children():
		child.queue_free()

	# Ждем, пока Godot гарантированно удалит старые объекты из памяти и физики
	await get_tree().physics_frame

	## 0️⃣ 3. СПАВН СУЩНОСТЕЙ С НАКАТЫВАНИЕМ ДАННЫХ
	for e_data in _saved_game.entities:
		var _setting = load(e_data["setting_path"]) as EntitySetting
		if not _setting: continue
		
		## 1️⃣ Базовая сборка сущности: создание инстанса, добавление C_Identity, C_TrackVisual итд
		var new_entity = entity_factory.create_from_setting(_setting)
		new_entity.name = _setting.name # имя ентити 
		# Восстанавливаем трансформацию ДО добавления в дерево
		new_entity.global_transform = e_data["transform"]
		# Добавляем в мир
		root_node.add_child(new_entity)
		
		## 2️⃣   Накатываем сохраненные данные на компоненты
		# Список сохраненных компонентов
		var comp_data_map = e_data["components"]
		
		## Ищем компонент внутри созданной сущности по типу скрипта
		for comp_type in comp_data_map.keys(): # Тут нас интересуют только ключи
			# 🅰️ Если сохр комп найден в ентити, то накатываем сейв данные в него
			var current_comp = new_entity.get_comp(comp_type)
			if current_comp and current_comp.has_method("load_data"):
				current_comp.load_data(comp_data_map[comp_type]) # а сюда пойдут все данные компонента из сейва
				
			# 🅱️ Если не найден, то создаем и тогда грузим
			else: 
				var new_comp = comp_type.new()
				if new_comp.has_method("load_data"):
					new_comp.load_data(comp_data_map[comp_type])
					new_entity.add_component(new_comp) 

	# 4. ВАЖНЕЙШИЙ ТАКТ СИНХРОНИЗАЦИИ ФИЗИКИ (см. Критические нюансы ниже)
	await get_tree().physics_frame
	
	#XX claude  5. Проходим все вагоны на снап (один раз: on_train_snapped асинхронный, повторный вызов только дублирует его)
	if root_node:
		# проход по всем ентити 
		for _entity in root_node.get_children():
			if _entity is Entity:
				var _comp = _entity.get_comp(C_Chassis)
				if _comp:
					_comp.restore_snap_after_load()

		#XX claude 5б. Сцепки восстанавливаем вторым проходом: нужны финальные позиции ВСЕХ вагонов
		for _entity in root_node.get_children():
			if _entity is Entity:
				var _cp = _entity.get_comp(C_Coupler) as C_Coupler
				if _cp:
					_cp.restore_links_after_load()
	
	
	#DEBUG повер слой принудительно обновляем
	#PGM.toggle_power_layer(true)
	PGM.request_recalculate()
	print("Макет успешно загружен!")


#
#func menu_click_handling(_idx : int) -> void:
	#match _idx:
		#0: # save
			#save_game()
		#1: # load
			#load_game('savegame')
			##print(OS.get_data_dir())
			#pass
		#2: # ++
			#pass
		#3: #ничего
			#clear_scene()
			#pass
			#
		#5: #DEFAULT jolt
			##GM. apply_jolt_profile(GM.AssistProfile.DEFAULT) 
			#pass
		#6: #STABLE jolt
			##GM. apply_jolt_profile(GM.AssistProfile.STABLE) 
			#pass
		#7: #EXTREME jolt
			##GM. apply_jolt_profile(GM.AssistProfile.EXTREME) 
			#pass
	#pass
	#
