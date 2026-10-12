class_name ISnappable extends ICapability

#####################
## Контракт магнит объекта
#####################
# Базовый интерфейс для всего, к чему можно пристыковаться
#  C_Socket extends ISnappable

# Возвращает массив всех доступных точек стыковки
func get_sockets() -> Array[Dictionary]:
	return []
