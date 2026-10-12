class_name TrackSupportSettings extends ComponentSettings

# XX claude-terra (новый файл)
## Собирает C_TrackSupport (эстакада под траком). Добавить в массив компонентов трака в редакторе.

## Фабрика запустит эту функцию создания
func create_component(entity: Entity) -> Component:
	var comp = C_TrackSupport.new()
	comp.name = 'C_TrackSupport'
	entity.add_component(comp) # Добавили комп к объекту
	return comp
