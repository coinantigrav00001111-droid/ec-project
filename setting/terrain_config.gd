class_name TerrainConfig extends ObjectConfig

# XX claude-terra (новый файл)
########################
## Настройки листа пенопласта. Цепляется в C_Identity (IdentitySetting.object_config)
########################
## Читается типизированно: TerrainConfig.from_entity(entity)

## Размер прямоугольного листа в плане (X, Z), ю
@export var size := Vector2(20.0, 20.0)

## Толщина листа в слоях (GlobalSetting.layer_height)
@export var levels := 1


## Типизированное чтение паспорта. null, если у сущности нет паспорта или в нем конфиг другого семейства
static func from_entity(entity: Entity) -> TerrainConfig:
	var idc := entity.get_comp(C_Identity) as C_Identity
	if idc == null:
		return null
	return idc.object_config as TerrainConfig
