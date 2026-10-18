extends Node

##########################
##
## Global  (Global)  глобальные настройки
##
###########################
var object_dirs := [	"res://data/tracks/objects/", 
						"res://data/trains/objects/"]
						#"res://ui/dc_controllers/objects/"]

# Настройки объектов
var settings: Resource = preload("res://setting/global_setting.tres")

#DD Дебаги вкл
var debug_mode := true
var active_ui_category := 1


## Текущий режим из : &'build' &'operate' &'observe' &'library'
var current_mode :StringName = &'build' 

## F2: контроль лимитов flex (R, L, уклон, "под землёй"). Переключается клавишей L в BuildTool
var flex_limits := false


######### TRACK ##############
 
# Высота трака с балластом
#const TRACK_WITH_BALLAST_HEIGHT = 0.85

########## HELPERS ##################

	#Выдает маску для слоя\маски коллизии из массива строк
func active_layers(data:Array) -> int:
	var i := 0
	
	for d in data:
		match str(d): # XX claude-terra StringName/String
			'ground' : i = i | 1 << 0
			'tracks' : i = i | 1 << 2
			'sokets' : i = i | 1 << 3
			'trains' : i = i | 1 << 4
			'supports' : i = i | 1 << 5  # XX claude-terra опоры эстакады (резерв)
			'handles' : i = i | 1 << 6   # ручки flex (бит 5 занят опорами)
			'ghost'  : i = i | 1 << 10
			## Слои 16-21 заняты контурами			
	return i
