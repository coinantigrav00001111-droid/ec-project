class_name ObjectConfig extends Resource

########################
## Базовый класс настроек объектов
########################

## Нужный дочерний класс цепляется в C_Identity (object_config). Читать типизированно:
##   var cfg := identity.object_config as TrackConfig   (или SwitchConfig.from_entity(entity))
## Строкового доступа к полям нет: опечатка в имени поля ловится при разборе скрипта
