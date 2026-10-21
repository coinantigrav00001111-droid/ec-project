class_name TerrainConfig extends ObjectConfig

# XX claude-terra (новый файл)
########################
## Настройки листа пенопласта. Цепляется в C_Identity (IdentitySetting.object_config)
########################
## Читается так: identity.get_config('size', Vector2(20, 20))

## Размер прямоугольного листа в плане (X, Z), ю
@export var size := Vector2(20.0, 20.0)

## Толщина листа в слоях (GlobalSetting.layer_height)
@export var levels := 1
