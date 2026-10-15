class_name BogieConfig extends Resource
####################
#### Паспорт настроек одной тележки/оси.
#### Добавляется в массив компонента C_Bogie через инспектор.
####################

@export_category("Base Setup")
## Смещение меша боги от 0 вверх и вдоль. 
#@export var b_offset: = Vector3(0.0, 0.7, -2.43)        

## моя‼️Замена b_offset на b_offset_z. Y - это всегда радиус без реборды
@export var b_offset_z: = -2.43
# Ссылка на визуал именно этой тележки 
@export var scene : PackedScene = preload("res://data/trains/default_bogie.tscn")

@export_category("Wheel Pair Setup")
# x - пока резерв (может для ширины колеи), 
# y - высота оси (Радиус колеса без реборды , которая = 0,1), 
# z - смещение оси от центра тележки (если 0 - ось одна)
@export var wheel_pair_scene : PackedScene = preload("res://data/trains/wheel_pair_01.tscn")

## Установка колесной пары, 0.71 - радиус без реборды.
@export var wheel_pair_position: Vector3 = Vector3(0.0, 0.71, 1.5)  
