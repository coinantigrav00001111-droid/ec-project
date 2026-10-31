class_name ObjectConfig extends Resource

########################
## Базовый класс настроек объектов
########################

## Нужный дочерний класс цепляется в C_Identity (object_config). Читать типизированно:
##   var cfg := identity.object_config as TrackConfig   (или SwitchConfig.from_entity(entity))
## get_config('имя', default) устаревает: опечатку в имени он не ловит (возвращает default)
