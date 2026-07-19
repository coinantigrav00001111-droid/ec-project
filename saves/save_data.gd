class_name SavedData extends Resource

########################
## Ресурс с данными объекта(трака) для сохранения. 
########################

## Пока не трогаем
## Данные предоставляет сам объект при запросе Saverом данных. 

## пока тут данные для сохранения трака
@warning_ignore("unused_private_class_variable")
#@export var object_setting: ATrackSetting
@warning_ignore("unused_private_class_variable")
@export var _global_transform :Transform3D
@export var name: String
@export var ballast_material_idx: int
@export var is_clip: bool
@export var contour_id: int
@export var is_reversed: bool
@export var group: String

@export var state_chart: SerializedStateChart = null
