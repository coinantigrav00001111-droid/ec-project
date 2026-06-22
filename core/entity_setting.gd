class_name EntitySetting extends Resource

###########################
## 📦 EntitySetting База. Сеттинг объекта\сущности.
###########################

#@export_category("Main & UI")
@export var id :int = 0 # сортировка в панели кнопок
@export var name :String = ''
@export var description :String = 'Прямой трак 1,5см'
@export var radius :float = 10.0
@export var deg :float = 30.0

@export var category :StringName = &'track'
@export var tag :StringName = &'straight'


@export var icon :Texture2D

#@export var pivot_offset : Vector3


## Массив сеттингов компонентов объекта
@export var components :Array[ComponentSettings] = []


#@export var scene :PackedScene = preload("res://world/objects/tracks/G239.tscn")
#@export var RADIUS :float = 23.9
#@export var DEG :float = 0.0
#@export var curvature: float = 0.0 # 0 = straight, >0 = радиус

#@export_category("Visual")
#
#@export var element :PackedScene = preload("res://world/objects/tracks/G239.tscn")
#@export var ballast_material :int = 1
#
#@export_category("Logic")
#@export var sockets: Array#[TrackSocketResource] #Corrector_0
#@export var pivot:Vector3
#
#@export_category("Physics")
#@export var head :Vector3 = Vector3(0.5, 0.25, 1.5)
#
#@export_category("Power")
#@export var clip :bool = false
