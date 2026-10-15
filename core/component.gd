class_name Component extends Node

######################
## (База поведения)
######################
## Дочерние C_Drag, C_Ghost.. - это State. Флаг активности для capability
## Их добавляет инструмент.

# Временно остается
var is_state = false

## Ссылка на владельца-сущность
var entity: Entity

# --- Жизненный цикл ---    

## 1️⃣ Вызывается в Entity СРАЗУ после создания каждого КОМПОНЕНТА‼️после add_child 
func on_added():

	pass

## Вызывается перед удалением
func on_removed():
	pass


## 2️⃣ Вызывается после создания ENTITY‼️в Entity._ready() (все компоненты уже на месте)
func on_entity_ready():
	pass

# === СОБЫТИЯ ENTITY ===

#--- Внутренний ---
# Принимает событие из шины (Event Bus) в виде словаря.
# Поскольку send_event посылает всем компонентам название метода и словарь с данными, принимаем словарь, извлекаем значение и запускаем метод обработки.
## 3️⃣ Реагирует на появление в Entity другого компонента по сигналу 
func _on_component_added(data: Dictionary):
	if data.has("type"):
		on_component_added(data.type)

func _on_component_removed(data: Dictionary):
	if data.has("type"):
		on_component_removed(data.type)

#--- Внутренний end---



#--- Внешний---

## Метод переопределяется в наследниках, чтобы реагировать на появление соседей. Через шину вызывается в Ентити при добавлении этих соседей.
# 3️⃣ Реагирует на появление в Entity другого компонента
func on_component_added(_type: Script):
	pass

func on_component_removed(_type: Script):
	pass

#--- Внешний end---



# --- HELPERS ---

func get_comp(type: Script) -> Component:
	return entity.get_comp(type)

func has_comp(type: Script) -> bool:
	return entity.has_comp(type)
