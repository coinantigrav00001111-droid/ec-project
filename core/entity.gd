class_name Entity extends Node3D

######################
## (Ядро системы)
######################

## Сигналы передают Script (тип компонента) для точной идентификации
signal component_added(type: Script)
signal component_removed(type: Script)



func _ready():
	# Оповещаем все компоненты, что сущность полностью собрана
	for child in get_children():
		if child is Component:
			child.on_entity_ready()



## ------ BUS --------

func send_event(event_name: String, data: Dictionary = {}) -> void:
	for child in get_children():
		# Если это компонент и у него есть нужная функция — вызываем её
		if child is Component and child.has_method(event_name):
			child.call(event_name, data)


## ------ КОМПОНЕНТЫ ---------

## Добавление компонента
func add_component(comp: Component):
	var type = comp.get_script()
	# Если компонент такого типа уже есть — заменяем
	if has_comp(type):
		remove_component(type)

	add_child(comp)
	comp.entity = self
	
	# Вызываем функцию компонента 
	comp.on_added()
	# ⚡ Внутреннее общение: кричим всем компонентам через шину
	send_event("_on_component_added", {"type": type})
	# ⚡Сигнал всем компонентам что создан
	component_added.emit(type)



func remove_component(type: Script): 
	var comp = get_comp(type) 
	if comp: 
		# ⚡ Предохранитель от крашей при queue_free()
		if is_queued_for_deletion():
			return
		#1. Отключаем внутри самого компонента
		comp.on_removed() 
		# 2. Мгновенно отрываем от дерева, чтобы has_comp(type) стал false прямо сейчас
		remove_child(comp)
		# 4. Освобождаем память
		comp.queue_free()
		# ⚡ Внешнее общение: дергаем классический сигнал для UI
		component_removed.emit(type) 
		# ⚡ Внутреннее общение: кричим всем компонентам через шину
		send_event("_on_component_removed", {"type": type})


## ----- Helpers--------------

## Поиск компонента (используем is_instance_of для поддержки интерфейсов/наследования)
func get_comp(type: Script) -> Component:
	for child in get_children():
		if is_instance_of(child, type):
			return child
	return null



func has_comp(type: Script) -> bool:
	return get_comp(type) != null
