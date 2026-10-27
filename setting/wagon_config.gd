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
## Масса в кг соответствует реальной х10. 2.0 - это 0.2 кг реальной модели
@export var mass: float = 2.0 
## Макс. поперечная сила до схода (реборда)
@export var max_grip: float = 200.0 
## Трение качения
@export var roll_resistance: float = 0.05 
## Предел продольного сцепления для пробуксовки
@export var longitudinal_grip: float = 3.0 
## Минимальный радиус сплайна (м), который проходит вагон без дерейла
@export var min_curve_radius: float = 15.0 

## μ бокового юза колёс и скольжения лежащим корпусом (на столе)
@export var slide_friction: float = 0.1
## μ юза локо с заблокированными колёсами (нет тяги). Одинаково на рельсах и на столе.
## Больше - короче юз. При пинке 10 м/с: 3.0 -> ~1.7 м, 1.0 -> ~5 м, 0.3 -> ~17 м.
@export var locked_wheel_friction: float = 3.0

@export_category("Rotation Limits (YAW)")
## Максимальный угол поворота тележки
@export var max_yaw_deg: float = 25.0    
## Сила возвратной пружины (стремление выровняться по оси кузова)
@export var yaw_spring: float = 5.0      

@export_category("Suspension (Travel & Play)")
## Подвеска кузова (частоты, упоры, стыки, hunting). Пусто - значения по умолчанию из SuspensionConfig.
@export var suspension: SuspensionConfig


@export_category("Engine Settings (Мотор)")
@export var has_engine: bool = false # Флаг, локомотив ли это # TODO лишний?
@export var max_tractive_force: float = 400.0 # Макс. стартовая тяга мотора в Ньютонах
@export var max_theoretical_speed: float = 40.0 # Макс. скорость мотора без нагрузки (KV)

@export_category("Visuals & Layout")
@export var scene = preload("res://data/trains/default_wagon.tscn")
@export var offset_mesh_y: float = 1.2 # Смещение меша от пола (меньше диаметра колеса на ~0.2)
@export var bogie_configs: Array[BogieConfig] = []


@export_category("Coupler (Сцепка)")
##[b] На сплайне:[/b] от центра вагона до торца (сцепки) , м 
@export var coupler_offset: float = 6.0         
@export var coupler_front: StringName = &"nem"  # "" - механизма нет (буфер остаётся)
@export var coupler_rear: StringName = &"nem"
@export var coupler_slack: float = 0.15			# свободный ход сцепки, м
@export var coupler_travel: float = 0.10           # ход буфера до упора, м
@export var coupler_strength: float = 600.0                # сила разрыва сцепки, Н
@export var couple_speed_max: float = 50.0    # макс. скорость, при которой сцепляемся, м/с
@export var impact_dv_limit: float = 50.0# Δv от удара, после которого вагон сходит, м/с
@export_category("Mechanisms")
@export var mechanisms: Array[MechanismConfig] = []
@export var lights: Array[LightConfig] = []
