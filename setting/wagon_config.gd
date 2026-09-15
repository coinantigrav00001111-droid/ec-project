class_name WagonConfig extends ObjectConfig

########################
## настройки конкретного типа вагона
########################

## Цепляется в C_Identity и доступ через
## к значению: get_config('radius', 0.0) # 0.0 - подставляется если не найден 'radius'
## к всему конфигу: get_config()

# Kinematics
# Данные заполняются в редакторе, в массиве сеттингов
@export var mass: float = 0.2 # Кг
@export var max_grip: float = 5.0 # Максимальная удерживающая сила реборды
@export var roll_resistance: float = 0.05 # Трение качения

@export var scene = preload("res://data/trains/default_wagon.tscn")
@export var offset_mesh_y: float = 1.2 # Смещение меша от пола (меньше диаметра колеса на ~0.2)
@export var bogie_configs: Array[BogieConfig] = []
