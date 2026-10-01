class_name WagonConfig extends ObjectConfig

########################
## настройки конкретного типа вагона
########################

## Цепляется в C_Identity и доступ через
## к значению: get_config('radius', 0.0) # 0.0 - подставляется если не найден 'radius'
## к всему конфигу: get_config()

# Kinematics
# Данные заполняются в редакторе, в массиве сеттингов
@export_category("Kinematics (Физика)")
@export var mass: float = 0.2 # Кг
@export var max_grip: float = 200.0 #Макс. поперечная сила до схода (реборда)
@export var roll_resistance: float = 0.05 # Трение качения

# --- НОВЫЕ ПАРАМЕТРЫ ФИЗИКИ ---
@export var longitudinal_grip: float = 3.0 # Предел продольного сцепления для пробуксовки
@export var min_curve_radius: float = 32.0 # Минимальный радиус сплайна (м), который проходит вагон

@export_category("Engine Settings (Мотор)")
@export var has_engine: bool = false # Флаг, локомотив ли это # TODO лишний 
@export var max_tractive_force: float = 400.0 # Макс. стартовая тяга мотора в Ньютонах
@export var max_theoretical_speed: float = 40.0 # Макс. скорость мотора без нагрузки (KV)

@export_category("Visuals & Layout")
@export var scene = preload("res://data/trains/default_wagon.tscn")
@export var offset_mesh_y: float = 1.2 # Смещение меша от пола (меньше диаметра колеса на ~0.2)
@export var bogie_configs: Array[BogieConfig] = []
