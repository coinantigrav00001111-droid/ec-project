class_name HoveredSettings extends ComponentSettings

################################
## Сеттинг для .tres 
################################
## 💡💡 Создает компонент 


func create_component(_entity: Entity) -> Component:
	
	var comp = C_Hovered.new()
	_entity.add_component(comp)
	return comp
