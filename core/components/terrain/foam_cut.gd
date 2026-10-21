class_name FoamCut extends RefCounted

# XX claude-terra (новый файл)
#######################
## Данные. Вырез в листе пенопласта.
#######################
## Полигон в локальных координатах листа (Vector2: x = X, y = Z) и диапазон слоев [from_level, to_level),
## считая от низа листа. Через все слои = окно, нижний слой = тоннель, верхний = ниша.
## Одна механика для обрезки под балласт (T5), тоннелей (T6) и терморезака (§13.3).
## Хранится в C_TerrainLayer.cuts, сохраняется вместе с листом.

var polygon := PackedVector2Array()
var from_level := 0
var to_level := 1
## true: вырез построен автоматически (канава под балласт трака, T5). Такие вырезы пересчитываются
## при изменении траков, ручные (терморезак, отладка) не трогаются
var auto := false


## Вырез занимает этот слой (0 = нижний слой листа)
func covers(level: int) -> bool:
	return level >= from_level and level < to_level


func to_dict() -> Dictionary:
	return {"polygon": polygon, "from": from_level, "to": to_level, "auto": auto}


static func from_dict(d: Dictionary) -> FoamCut:
	var c := FoamCut.new()
	c.polygon = d.get("polygon", PackedVector2Array())
	c.from_level = int(d.get("from", 0))
	c.to_level = int(d.get("to", 1))
	c.auto = bool(d.get("auto", false))
	return c
