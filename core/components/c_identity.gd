class_name C_Identity extends Component

#######################
## Паспорт объекта. Содержит только ОБЩИЕ свойства\описание ентити
#######################

# Ссылка на оригинальный ресурс. Никаких копий!
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
