class_name CameraTargetSettings extends ComponentSettings

# для каждого ентити прописываем в редакторе

# Сцен в C_PowerClip прописана
#@export var scene: PackedScene = preload("res://data/tracks/power_clip.tscn")

func create_component(entity: Entity) -> Component:
	var comp = C_CameraTarget.new()
	#comp.scene = scene
	comp.name = 'C_CameraTarget'
	entity.add_component(comp)
	return comp
