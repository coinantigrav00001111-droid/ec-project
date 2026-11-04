class_name PowerPort extends RefCounted

#####################
## Порт потребителя (ATTN_10 §10.5.6, §10.5.8, D3)
#####################
## Потребитель заявляет ток. Мотор локо: `I = idle + (stall − idle) · |F| / F_max` (затор даёт стопорный ток).
## Свет: `P / V`, только если `PGM.load_for_lights` (по умолчанию выключено, правило режима D7).
## Владелец (C_Engine) сам обновляет `net`, `voltage` и `load_current` на каждом шаге, решатель только суммирует.

enum Kind { MOTOR, LIGHT, ACCESSORY }

var kind: Kind = Kind.MOTOR
## Метка цепи, из которой потребитель получает питание (0: не на питании)
var net := 0
## Напряжение на порте, % команды со знаком
var voltage := 0.0
## Для мотора: ток, который владелец заявил на этом шаге, А
var load_current := 0.0
## Для света и аксессуаров: мощность при полном напряжении, Вт
var power_w := 0.0
## Владелец (компонент). Освобождённые владельцы решатель пропускает и убирает
var owner: Object = null


## Ток порта, А. Без цепи или без напряжения 0
func current(light_load_enabled: bool) -> float:
	if net == 0 or voltage == 0.0:
		return 0.0
	match kind:
		Kind.MOTOR:
			return load_current
		Kind.LIGHT:
			if not light_load_enabled:
				return 0.0
			return power_w / maxf(absf(voltage) * 0.01 * PowerSupply.VOLTS_AT_100, 0.5)
		Kind.ACCESSORY:
			return power_w / maxf(absf(voltage) * 0.01 * PowerSupply.VOLTS_AT_100, 0.5)
	return 0.0


## Ток мотора по доле силы. force_ratio = |F| / F_max, 0..1
static func motor_current(idle: float, stall: float, force_ratio: float) -> float:
	return idle + (stall - idle) * clampf(force_ratio, 0.0, 1.0)
