extends Resource
class_name DCControllerSetting

########################
## Ресурс контроллера питания для 2D контроллеров
########################


@export var id :int = 0 # сортировка в панели кнопок
@export var name :String = 'DC Controller'
@export var description :String = 'Стандартный DC контроллер'
@export var category :StringName = &'dc_controller'
@export var tag :StringName = &'2d'
@export var scene :PackedScene
@export var icon :Texture2D
@export var rotation_with_direction :bool = true # Вращение ручки в обе стороны вместо переключателя полярности
@export var handle_max_angle :int = 270 # Максимальный угол поворота ручки
