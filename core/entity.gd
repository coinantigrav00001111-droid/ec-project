class_name Entity extends Node3D

######################
## (Ядро системы)
######################

## Сигналы передают Script (тип компонента) для точной идентификации
signal component_added(type: Script)
signal component_removed(type: Script)


# для блокед
func _notify_components_changed():
	get_comp(C_Visual)._on_component_changed()
	pass
	
	
## Добавление компонента
func add_component(comp: Component):
	var type = comp.get_script()
	
	# Если компонент такого типа уже есть — заменяем
	if has_comp(type):
		remove_component(type)
		
	add_child(comp)
	comp.entity = self
	
	# Подписываем новый компонент на события других компонентов
	component_added.connect(comp._on_component_added)
	component_removed.connect(comp._on_component_removed)
	
	# Вызываем функцию компонента 
	comp.on_added()
	# ⚡Сигнал всем компонентам что создан
	component_added.emit(type)


## Удаление компонента
func remove_component(type: Script):
	var comp = get_comp(type)
	if comp:
		component_removed.emit(type)
		comp.on_removed()
		
		# Отключаем сигналы перед физическим удалением
		if component_added.is_connected(comp._on_component_added):
			component_added.disconnect(comp._on_component_added)
		if component_removed.is_connected(comp._on_component_removed):
			component_removed.disconnect(comp._on_component_removed)
			
		comp.queue_free()



## Поиск компонента (используем is_instance_of для поддержки интерфейсов/наследования)
func get_comp(type: Script) -> Component:
	for child in get_children():
		if is_instance_of(child, type):
			return child
	return null



func has_comp(type: Script) -> bool:
	return get_comp(type) != null



func _ready():
	# Оповещаем все компоненты, что сущность полностью собрана
	for child in get_children():
		if child is Component:
			child.on_entity_ready()
