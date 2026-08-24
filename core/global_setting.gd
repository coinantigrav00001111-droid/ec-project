class_name GlobalSetting extends Resource

##########################
## Настройки объектов
###########################
## Подключаются в синглтоне Global


######### TRACK ##############
@export_group("Tracks")

@export var track_head_segment  = {
	'count' : 10, # количество
	'gap' : 0.0, # зазор между сегментами.
	"size" : Vector2(0.3, 0.25),
	'padding' : -0.1,	 #  минус - внутрь трака, плюс =0 
	'offset' : 0.865, #0.875-смещение влево относительно центра 0.1 -по z
	
	}

@export var track_ballast_segment = {
	"count" :  4,
	"gap" : 0.0,
	"size" : Vector2(3.2, 0.6),
	'padding' : -0.1,	 #  минус - внутрь трака, плюс =0 
	'offset' : 0.0, #смещение влево 
}


## Это не исп. а для справки
@export var sleeper_size  = {
	'distance' : 0.4,
	'length' : 0.3,
	'width' : 3.0,
	'height' : 0.2,
	}


## Высота трака
func get_track_height() -> float:
	return track_head_segment.size.y + track_ballast_segment.size.y

	
