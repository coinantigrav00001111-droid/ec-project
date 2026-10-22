class_name BufferStopConfig extends TrackConfig

# XX claude-switch (новый файл)
########################
## Настройки упора (Buffer Stop): прямой трак с буферным брусом на одном конце.
## radius = длина трака (как у прямого), deg = 0.
########################

## true: упор на конце кривой (z = -L), открытый стык в начале. false: наоборот
@export var stop_at_end := true
## Скорость сближения, выше которой вагон сходит, ю/с. 0 = только по impact_dv_limit вагона
@export var max_speed := 0.0
