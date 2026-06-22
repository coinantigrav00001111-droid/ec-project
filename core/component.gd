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

## Вызывается СРАЗУ после add_child в Entity
func on_added():
	pass

## Вызывается перед удалением
func on_removed():
	pass

## Вызывается, когда Entity._ready() выполнена (все компоненты уже на месте)
func on_entity_ready():
	pass

# === СОБЫТИЯ ENTITY ===

##--- Внутренний ---
# Принимает событие из шины (Event Bus) в виде словаря
func _on_component_added(data: Dictionary):
	if data.has("type"):
		on_component_added(data.type)

func _on_component_removed(data: Dictionary):
	if data.has("type"):
		on_component_removed(data.type)

#--- Внутренний end---

##--- Внешний---
## Пока просто прокси— переопределяется в наследниках, чтобы реагировать на появление соседей

func on_component_added(_type: Script):
	pass

func on_component_removed(_type: Script):
	pass

#--- Внешний end---


## --- Хелперы ---

func get_comp(type: Script) -> Component:
	return entity.get_comp(type)

func has_comp(type: Script) -> bool:
	return entity.has_comp(type)
