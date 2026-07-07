class_name SavedGame extends Resource


########################
## Ресурс содержит данные для сохранения всех объектов
########################

## данные камеры
@export var gimbal_transform 	:Transform3D
@export var gimbal_elevation 	:Transform3D 
@export var gimbal_camera		:Transform3D 

@export var gimbal = {
	"transform": Transform3D.IDENTITY,
	"elevation": Transform3D.IDENTITY,
	"camera": Transform3D.IDENTITY,
}

### массив в GM контуры питания
#@export var clip_numbers		:Array[int] = []
#@export var power_pwm 			:Dictionary[int, int] = {}

### Данные контролера питания
#@export var controller_setting 	:ControllerSetting
#
#### трак 
#@export var	saved_data: Array[SavedData] = [] # это уже перенесено в SavedData
#### Это массив, который содержит все данные объектов, которые передали эти данные
