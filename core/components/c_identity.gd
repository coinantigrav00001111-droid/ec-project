class_name C_Identity extends Component

#######################
## Паспорт объекта. Содержит только ОБЩИЕ свойства\описание ентити
#######################
"делаем ентити"

# Ссылка на оригинальный ресурс. Никаких копий!
var setting: EntitySetting
#var c_path

#func _ready() -> void:
	#c_path = entity.get_comp(C_Path)

	
# Хелперы для быстрого доступа из InfoPanel
func get_name_e()->String:
	return setting.name if setting else "Unknown"
	

func get_description() -> String:
	return setting.description if setting else ""


#func get_radius() -> float:
	#var rad := 0.0
	#if c_path:
		#if c_path.radius:
			#rad =  c_path.radius
	#return rad
#
#func get_degree() -> float:
	#var deg := 0.0
	#if c_path:
		#if c_path.deg:
			#deg =  c_path.deg
	#return deg
#
#
#func get_length() -> float:
	#var deg = get_degree()
	#var radius = get_radius()
	#return snapped(radius * deg_to_rad(deg), 0.1) if deg !=0.0 else snapped(radius,0.1)
#
#

func get_icon() -> Texture2D:
	var icon := preload( "res://ui/icons/cancel.svg")
	if setting and 'icon' in setting:
		return setting.icon if setting.icon != null else icon
	else:
		return icon
