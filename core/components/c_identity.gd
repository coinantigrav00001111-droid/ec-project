class_name C_Identity extends Component

#######################
## Паспорт
#######################

# Ссылка на оригинальный ресурс. Никаких копий!
var setting: EntitySetting


# Хелперы для быстрого доступа из InfoPanel
func get_name_e()->String:
	return setting.name if setting else "Unknown"
	

func get_description() -> String:
	return setting.description if setting else ""


func get_radius() -> float:
	return setting.radius if setting and 'radius' in setting else 0.0


func get_degree() -> float:
	return setting.deg if setting and 'deg' in setting else 0.0


func get_length() -> float:
	var _d = setting.deg if setting and 'deg' in setting else 0.0
	if setting and 'length' in setting:
		return setting.length
	else:
		return snapped(setting.radius * deg_to_rad(_d), 0.1) if _d !=0.0 else snapped(setting.radius,0.1)



func get_icon() -> Texture2D:
	var icon := preload( "res://ui/icons/cancel.svg")
	if setting and 'icon' in setting:
		return setting.icon if setting.icon != null else icon
	else:
		return icon
