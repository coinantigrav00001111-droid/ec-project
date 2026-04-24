class_name CurrentSettings extends ComponentSettings
#TODO  не исп.---- удалить

## Фабрика запускает функцию создания
func build_component(entity):
	var comp = C_Current.new()

	entity.add_component(comp) # Добавили комп к объекту
