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


## Массив сеттингов компонентов объекта
@export var components :Array[ComponentSettings] = []
