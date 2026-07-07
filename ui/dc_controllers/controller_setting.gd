extends Resource
class_name DCControllerSetting

########################
## Ресурс контроллера питания
########################

## Все контроллеры в папке objects

@export var id :int = 0 # сортировка в панели кнопок
@export var name :String = 'DC Controller'
@export var description :String = 'Стандартный DC контроллер'
@export var tab :int = 0
@export var scene :PackedScene
@export var icon :Texture2D
@export var rotation_with_direction :bool = true
@export var handle_max_angle :int = 270


# Правильно для сейва видимо
# @export var power_pwm : Dictionary[int, int] = {} 
