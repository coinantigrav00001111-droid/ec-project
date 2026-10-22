class_name TrackConfig extends ObjectConfig

########################
## настройки конкретного типа трака 
########################

## Цепляется в C_Identity и доступ через
## к значению: get_config('radius', 0.0) # 0.0 - подставляется если не найден 'radius'
## к всему конфигу: get_config()

@export var radius := 0.0
@export var deg := 0.0
@export var height := 0.85
# XX claude-terra
## Подъем вдоль трака, ю (только прямые). 0 = ровный. Для пандуса radius = длина ВДОЛЬ уклона
@export var rise := 0.0
# XX claude-terra
## Трак тоннельный сразу при постановке (C_Tunnel): может уходить под листы пенопласта. Обычно включается клавишей U
@export var allow_underground := false
#@export var align_ends := false # Выравнивание торцов коллизий

#TODO  Возможное развитие разнообразие траков. Не исп здесь пока. 
# для C_Path 
#пока это в глобал:  var track_ballast_segment 
#@export var ballast_size := Vector2(3.2, 0.6) # ширина, высота

# в С_Visual 
# @export var scene: PackedScene = preload("res://data/tracks/default_track.tscn")
# @export var settings: VisualStateSettings = preload("res://core/visual/visual_state.tres")
# Pivot
#@export var offset: Vector3 = Vector3.ZERO
