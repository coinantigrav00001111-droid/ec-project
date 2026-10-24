class_name TrackShadows

# XX claude-perf (новый файл)
## Тени траков. Один выключатель на все траки: GFX.is_track_shadows() (выбор игрока, иначе QualityPreset.track_shadows, по умолчанию false).
## Выключает или включает cast_shadow у всей геометрии под Entity трака: меши сцен Blender, процедурный меш,
## MultiMesh шпал и опор, клипы. Вызывается при создании трака (C_Path), после пересборки формы (C_TrackSupport)
## и при смене настройки (GFX.track_shadows_changed).


static func enabled() -> bool:
	if not is_instance_valid(GFX):
		return false
	return GFX.is_track_shadows()


## on: явно включить или выключить, по умолчанию как в настройках качества
static func apply(root: Node, on: bool = enabled()) -> void:
	if not is_instance_valid(root):
		return
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is GeometryInstance3D:
			(nd as GeometryInstance3D).cast_shadow = mode
		stack.append_array(nd.get_children())
