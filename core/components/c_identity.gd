class_name C_Identity extends Component

#######################
## Паспорт объекта. Содержит только ОБЩИЕ свойства\описание ентити
#######################

# конфиги для объектов - TrackConfig, WagonConfig итд 
var object_config : ObjectConfig

# Ссылка на оригинальный ресурс из кнопки!
var setting: EntitySetting

# Хелперы для быстрого доступа из InfoPanel
func get_name_e()->String:
	return setting.name if setting else "Unknown"


func get_description() -> String:
	return setting.description if setting else ""


func get_icon() -> Texture2D:
	var icon := preload( "res://ui/icons/cancel.svg")
	if setting and 'icon' in setting:
		return setting.icon if setting.icon != null else icon
	else:
		return icon


func get_category() -> StringName:
	var cat : StringName
	if setting and 'category' in setting:
		cat = setting.category 
	return cat


# Возвращает одно значение из object_config или default, если его нет
func get_config(_s: Variant = null, default: Variant = null) -> Variant:
	# Если аргумент не передан (или передан null / пустая строка), возвращаем весь ресурс
	if _s == null or (typeof(_s) == TYPE_STRING and _s == ""): 
		return object_config
	
	# Защита: оператор 'in' требует строку. Проверяем, что нам передали именно имя свойства
	if typeof(_s) == TYPE_STRING or typeof(_s) == TYPE_STRING_NAME:
		if object_config and _s in object_config:
			return object_config.get(_s)
			
	return default
