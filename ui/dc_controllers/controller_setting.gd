@tool
class_name DCControllerSetting extends EntitySetting

########################
## Ресурс контроллера питания для 2D контроллеров
########################


@export var scene :PackedScene
@export var rotation_with_direction :bool = true # Вращение ручки в обе стороны вместо переключателя полярности
@export var handle_max_angle :int = 270 # Максимальный угол поворота ручки
## Модель источника питания (PowerModels): сколько выводов, лимит тока, нужна ли сеть
@export var model_id :StringName = &"multi"


func _init() -> void:
	name = 'DC Controller'
	description = 'Стандартный DC контроллер'
	category = &'dc_controller'
	tag = &'2d'
