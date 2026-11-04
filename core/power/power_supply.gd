class_name PowerSupply extends RefCounted

#####################
## Питающая сеть: розетка или блок питания (ATTN_10 §10.5.6, D3)
#####################
## Один на макет по умолчанию (`PGM.mains`). Источники с `needs_supply` без включённой сети мертвы.
## Нагрузка считается в ваттах: напряжение вывода (100 % = `VOLTS_AT_100`) на ток. Превышение `capacity_w`
## только поднимает флаг `overloaded` (лампа на панели), вывод не отключает.

## Напряжение рельсов при команде 100 %, В
const VOLTS_AT_100 := 12.0

var on := true
var capacity_w := 60.0
## Нагрузка в момент последнего расчёта, Вт
var load_w := 0.0
var overloaded := false


func save_data() -> Dictionary:
	return {"on": on, "capacity_w": capacity_w}


func load_data(d: Dictionary) -> void:
	on = bool(d.get("on", true))
	capacity_w = float(d.get("capacity_w", capacity_w))
