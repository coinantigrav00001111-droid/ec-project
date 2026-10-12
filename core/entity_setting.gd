class_name EntitySetting extends Resource

###########################
## 📦 EntitySetting База. Сеттинг объекта\сущности.
###########################
## Все объекты - это ентити, которые создаются из этого ресурса. 
## Файлы .tres для каждого объекта лежат в папках res://data/.../objects/ 
## UI накидывает кнопки по категориям для каждого объекта папок /objects/

#@export_category("Main & UI")
@export var id :int = 0 # сортировка в панели кнопок
@export var name :String = ''
@export var description :String = 'Прямой трак 1,5см'

@export var category :StringName = &'track'
@export var tag :StringName = &'straight'

@export var icon :Texture2D

@export var hide : bool = false # скрыть кнопку в UI 

enum BuildBehavior { GHOST_PLACE, SPAWN_AND_DRAG }

## Как BuildTool ставит объект: гост + клик, или сразу спавн в драг
@export var build_behavior: BuildBehavior = BuildBehavior.GHOST_PLACE

## Массив сеттингов компонентов объекта
@export var components :Array[ComponentSettings] = []

# XX claude-terra
## Слои, по которым рейкаст тулов ищет точку под курсором ('ground','tracks','trains'...).
## Пусто = значение по умолчанию из категории (см. get_pick_layers)
@export var pick_layers: Array[StringName] = []

# XX claude-terra
func get_pick_layers() -> Array:
	if not pick_layers.is_empty():
		return pick_layers
	if category == &'track':
		return [&'ground']   # трак ставится на уровень над землей, а не на другие траки
	return [&'ground', &'tracks', &'trains']
