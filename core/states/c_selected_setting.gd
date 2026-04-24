class_name SelectedSettings extends ComponentSettings

################################
## Сеттинг для .tres 
################################
## 💡💡 Создает компонент 

func create_component(_entity: Entity) -> Component:
	
	var comp = C_Selected.new()
	
	_entity.add_component(comp)
	return comp
