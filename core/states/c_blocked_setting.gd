class_name BlockedSettings extends ComponentSettings

################################
## Сеттинг для .tres 
################################
## 💡💡 Создает компонент 




func create_component(_entity: Entity) -> Component:
	var comp = C_Blocked.new()
	
	_entity.add_component(comp)

	return comp
