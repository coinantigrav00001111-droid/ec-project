class_name BogieConfig extends Resource
####################
#### Паспорт настроек одной тележки/оси.
#### Добавляется в массив компонента C_Bogie через инспектор.
####################

@export_category("Base Setup")
## Смещение меша боги от 0 вверх и вдоль. 
@export var b_offset: = Vector3(0.0, 0.7, -2.43)        
# Ссылка на визуал именно этой тележки 
@export var scene : PackedScene = preload("res://data/trains/default_bogie.tscn")

@export_category("Wheel Pair Setup")
# x - пока резерв (может для ширины колеи), 
# y - высота оси (Радиус колеса без реборды , которая = 0,1), 
# z - смещение оси от центра тележки (если 0 - ось одна)
@export var wheel_pair_scene : PackedScene = preload("res://data/trains/wheel_pair_01.tscn")

## Установка колесной пары, 0.71 - радиус без реборды.
@export var wheel_pair_position: Vector3 = Vector3(0.0, 0.71, 1.5)  

# По массиву расставим колеса, по первой паре выставим высоту установки боги
#@export var wheel_pair_positions: Array = [Vector3(0.0, 0.71, -1.5),
											#Vector3(0.0, 0.71, 1.5)]


#@export_category("Rotation Limits (YAW)")
#@export var max_yaw_deg: float = 25.0    # Максимальный угол поворота тележки
#@export var yaw_spring: float = 5.0      # Сила возвратной пружины (стремление выровняться по оси кузова)
#
#@export_category("Suspension (Travel & Play)")
#@export var vertical_travel_y: float = 0.05 #Вертикальный ход пружин(для имитации просадки на стыках)
#@export var lateral_play_x: float = 0.02 #Люфт колесной пары в колее (для поперечной раскачки)
#@export var suspension_stiffness: float = 10.0 # Жесткость амортизаторов
