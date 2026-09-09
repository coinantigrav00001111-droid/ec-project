class_name BogieConfig extends Resource
####################
#### Паспорт настроек одной тележки/оси.
#### Добавляется в массив компонента C_Bogie через инспектор.
####################

@export_category("Base Setup")
# Смещение от кузова вдоль \ вниз. 
# Не исп.: y= 0.9, то вниз на радиус 0,7 + 0,1 реборда + 0,1 гап
@export var offset: = Vector3(4.0, 0.0, 0.0)        
@export var wheel_radius: float = 0.71    # Радиус колеса без реборды , которая = 0,1
# Ссылка на визуал именно этой тележки (если нужно)
@export var scene : PackedScene = preload("res://data/trains/default_bogie.tscn")

@export_category("Rotation Limits (YAW)")
@export var max_yaw_deg: float = 25.0    # Максимальный угол поворота тележки
@export var yaw_spring: float = 5.0      # Сила возвратной пружины (стремление выровняться по оси кузова)

@export_category("Suspension (Travel & Play)")
@export var vertical_travel_y: float = 0.05 # Вертикальный ход пружин (для имитации просадки на стыках)
@export var lateral_play_x: float = 0.02    # Тот самый люфт колесной пары в колее (для поперечной раскачки)
@export var suspension_stiffness: float = 10.0 # Жесткость амортизаторов
