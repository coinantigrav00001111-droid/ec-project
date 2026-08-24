class_name PowerClipSettings extends ComponentSettings

# для каждого ентити прописываем в редакторе

# Сцен в C_PowerClip прописана
#@export var scene: PackedScene = preload("res://data/tracks/power_clip.tscn")

func create_component(entity: Entity) -> Component:
	var comp = C_PowerClip.new()
	#comp.scene = scene
	comp.name = 'C_PowerClip'
	entity.add_component(comp)
	return comp
