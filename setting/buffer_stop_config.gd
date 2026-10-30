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
## Демпфирование буфера: больше - меньше отскок (0.25 дает отскок около 0.44)
@export var zeta := 0.25


## Типизированное чтение паспорта. null, если у сущности нет паспорта или в нем конфиг другого семейства
static func from_entity(entity: Entity) -> BufferStopConfig:
	var idc := entity.get_comp(C_Identity) as C_Identity
	if idc == null:
		return null
	return idc.object_config as BufferStopConfig
