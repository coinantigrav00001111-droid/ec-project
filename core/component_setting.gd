class_name ComponentSettings extends Resource

############################
## 📦 (Чертеж компонента). Сеттинг для компонента
############################
## 💡💡 Сами сеттинги - tres файлы для каждого компонента в папке res://components/../
## Каждому ресурсу-сеттингу нужно переопределить этот метод


func create_component(_entity: Entity) -> Component:
	push_error("Метод create_component не переопределен в " + resource_path)
	return null
