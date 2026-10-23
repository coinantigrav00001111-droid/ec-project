extends Node

##########################
##
## Global  (Global)  глобальные настройки
##
###########################
var object_dirs := [	"res://data/tracks/objects/", 
						"res://data/trains/objects/", 
						"res://data/buildings/objects/",
						"res://data/terrain/objects/"]
						#"res://ui/dc_controllers/objects/"]

# Настройки объектов
var settings: Resource = preload("res://setting/global_setting.tres")

#DD Дебаги вкл
var debug_mode := true

<<<<<<< HEAD
## Режим быстрой загрузки для отладки: без комнаты и карточек Observe, графика по умолчанию (Low, без SDFGI),
## землёй служит скрытый WoodFloor. Включается аргументом запуска `--fast` (Run with args: -- --fast)
## или настройкой проекта ec/fast_debug = true
var fast_debug := OS.get_cmdline_user_args().has("--fast") or bool(ProjectSettings.get_setting("ec/fast_debug", false))
=======
## Физика вагона во время драга. false (по умолчанию): rb замораживается и едет за ентити как ребёнок,
## без «догоняния» и броска. true: прежнее поведение, rb догоняет ентити скоростями (можно бросить вагон)
var drag_physics := false
>>>>>>> hints system, drag_physics option + spawn plane fallback, outline ESSENTIAL mode (ghost/blocked on Low)

## Отладочные маркеры в кадре: куб над Entity, конусы и шарики сокетов. Отдельно от debug_mode,
## тот включён по умолчанию и держит другие отладочные вещи
var debug_markers := false

## Visual layer комнаты (номер 1..20 для set_layer_mask_value / cull_mask). 15-20 заняты контурами Outline
const ROOM_VISUAL_LAYER := 12

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
			'room'   : i = i | 1 << 7    # пол, стены, мебель комнаты (Observe)
			'ghost'  : i = i | 1 << 10
			## Контуры Outline это visual layers 15-20 (cull_mask), к физике не относятся
	return i
