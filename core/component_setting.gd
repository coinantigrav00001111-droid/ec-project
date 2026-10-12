class_name ComponentSettings extends Resource

############################
## 📦 (Чертеж компонента). Сеттинг для компонента
############################
## 💡💡 Сами сеттинги - файлы для каждого компонента в папке res://components/../
## например, trackdraggable_setting.gd 
## Именно класс ComponentSettings добавляется в список ентити в редакторе как Массив сеттингов компонентов объекта
## @export var components :Array[ComponentSettings] = [] - см. EntitySetting.gd

## Каждому сеттингу нужно переопределить метод create_component  по типу:
# var comp = C_TrackDraggable.new() 
# _entity.add_component(comp) # Добавили комп к объекту


func create_component(_entity: Entity) -> Component:
	push_error("Метод create_component не переопределен в " + resource_path)
	return null
