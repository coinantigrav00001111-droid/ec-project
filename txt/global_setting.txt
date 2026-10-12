class_name GlobalSetting extends Resource

##########################
## Настройки объектов
###########################
## Подключаются в синглтоне Global


######### TRACK ##############
@export_group("Tracks")
@export var track_head_segment  = {
	'align_ends' : false, # Выравнивание торцов
	'deg_per_segment' : 10.0, # сколько градусов закрывает один сегмент
	'gap' : 0.0, # зазор между сегментами.
	"size" : Vector2(0.2, 0.25), # (1.65 + 0,1 +0,1) = 1.85 или 0.2, если 2шт
	'start_end_padding' : -0.2,	 #  минус - внутрь трака, плюс =0 
	'offset_x' : 0.875, # 0, или 0.875-смещение влево относительно центра 0.1 -по z, если 2шт
	'static_generation_ballast' : true, # Метод генерации статикбоди трака
	'static_generation_heads' : 2,
	}

@export var track_ballast_segment = {
	'align_ends' : false, # Выравнивание торцов
	'deg_per_segment' : 10.0,
	"gap" : 0.0,
	"size" : Vector2(3.2, 0.6),
	'start_end_padding' : -0.2,	 #  минус - внутрь трака, плюс =0 
	'offset_x' : 0.0, #смещение влево 
}

## Это не исп. а для справки
@export_group("Not Used")

@export var sleeper_size  = {
	'distance' : 0.4,
	'length' : 0.3,
	'width' : 3.0,
	'height' : 0.2,
	}


## Высота трака
func get_track_height() -> float:
	return track_head_segment.size.y + track_ballast_segment.size.y

	
