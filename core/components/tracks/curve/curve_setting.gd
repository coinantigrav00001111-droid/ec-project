class_name CurveSettings extends ComponentSettings

################################
## Сеттинг для curve.tres 
################################
## 💡💡 Создает компонент с признаками тега (прямой, радиус, стрелка...)

@export var radius: float
@export var deg: float


func build_component(entity):
	var comp = C_TrackCurve.new()
	
	comp.radius = radius
	comp.deg = deg

	
	entity.add_component(comp)
