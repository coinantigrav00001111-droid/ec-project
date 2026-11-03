class_name LibraryStage extends RefCounted

# XX claude-library (новый файл)
########################
## LibraryStage. База сцены Library: фон и свет вокруг модели (ATTN_22 §22.5.3, шаг L1)
########################
## Сцена заменяемая: clean (чистая студия, L1), bench (стол) и shelf (витрина) позже (L12).
## Сцена настраивает StudioWorld (свет, фон, пол) через шаблон Icon Studio; сами объекты она не трогает.

var id: StringName = &"stage"
var title := ""


## Настроить мир (StudioWorld) под сцену
func apply(_world: Node3D) -> void:
	pass


## Убрать то, что сцена добавила в мир (декор), при смене сцены
func teardown(_world: Node3D) -> void:
	pass
