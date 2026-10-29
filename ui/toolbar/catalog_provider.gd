class_name CatalogProvider extends RefCounted

###########################
## CatalogProvider. Источник данных для панели «категория, тег, объект»
###########################
## Контракт. ToolbarController знает только его и не знает, откуда берутся данные:
## сейчас это объекты из .tres (EntityCatalogProvider), в U4 появится провайдер карточек Observe.
##
## Словари для кнопок: {"id": StringName, "name": String, "icon": Texture2D или null}.
## Элемент каталога (item) для кнопки объекта: Resource (EntitySetting). Что с ним делать, решает приемник режима.


## Категории (нижний ряд кнопок) в порядке показа
func get_categories() -> Array[Dictionary]:
	return []


## Теги категории (кнопки справа от сетки) в порядке показа
func get_tags(_category: StringName) -> Array[Dictionary]:
	return []


## Элементы категории и тега в порядке показа
func get_items(_category: StringName, _tag: StringName) -> Array:
	return []
