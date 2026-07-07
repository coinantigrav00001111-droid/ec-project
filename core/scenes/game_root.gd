extends Node
class_name GameRoot

##########################
##
## GameRoot (GR) - бывший GameManager 
##
###########################
## 💡 В идеале - ТОЛЬКО связывает системы, больше не синглтон пока!
#Entity (объект) = контейнер компонентов
#Components = данные + логика (по месту)
#Controllers = orchestration (высокоуровневая логика)


####################################################
#СПРАВКА  ложится поверх материалов
#mesh.set_material_overlay(settings.current_material)
# ложится вместо материала
#mesh.set_surface_override_material(0,settings.current_material)

# Памятка 
#await get_tree().process_frame
#await get_tree().create_timer(0.3).timeout 
#call_deferred(result)
###################################################


#DD Дебаги вкл
@export var debug_mode := false


## Текущий режим из : &'build' &'operate' &'observe' &'library'
var current_mode :StringName = &'build' 



func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	var window_title = get_window().title
	DisplayServer.window_set_title(window_title + " | fps: " +				str(Engine.get_frames_per_second()))

	pass
