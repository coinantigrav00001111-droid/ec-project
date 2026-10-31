class_name TrackConfig extends ObjectConfig

########################
## настройки конкретного типа трака 
########################

## Цепляется в C_Identity (object_config). Читать типизированно:
##   var cfg := identity.object_config as TrackConfig   (или SwitchConfig.from_entity(entity))
## get_config('имя', default) устаревает: опечатку в имени он не ловит (возвращает default)

@export var radius := 0.0
@export var deg := 0.0
@export var height := 0.85
# XX claude-terra
## Подъем вдоль трака, ю (только прямые). 0 = ровный. Для пандуса radius = длина ВДОЛЬ уклона
@export var rise := 0.0
# XX claude-terra
## Трак тоннельный сразу при постановке (C_Tunnel): может уходить под листы пенопласта. Обычно включается клавишей U
@export var allow_underground := false
# XX claude-switch
## Ширина коллизии основания (балласт, шпалы), ю. 0 = из TrackStyle (по умолчанию 3.2).
## Читают стрелка, кросс и упор (C_SwitchVisual). Нужна, когда соседние траки стоят близко: у стрелки и кросса
## от нее зависит, на какое расстояние разойдутся концы (см. auto_fit в SwitchConfig и CrossingConfig)
@export var collision_width := 0.0
#@export var align_ends := false # Выравнивание торцов коллизий

#TODO  Возможное развитие разнообразие траков. Не исп здесь пока. 
# для C_Path 
#пока это в глобал:  var track_ballast_segment 
#@export var ballast_size := Vector2(3.2, 0.6) # ширина, высота

# в С_Visual 
# @export var scene: PackedScene = preload("res://data/tracks/default_track.tscn")
# Pivot
#@export var offset: Vector3 = Vector3.ZERO
