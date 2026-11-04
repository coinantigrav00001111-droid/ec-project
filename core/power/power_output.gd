class_name PowerOutput extends RefCounted

#####################
## Вывод источника питания (ATTN_10 §10.5.5, D2, D3)
#####################
## Команда пульта −100…+100 %, лимит тока, состояние защиты. Напряжение на рельсах (с учётом аварийного стопа,
## защиты и сети) считает `PowerSolver.voltage_of`. Метка `label` выдаётся глобально и по порядку (старый `contour_id`).

enum State { OK, OVERLOAD, TRIPPED, SHORT }

## Номер вывода, он же метка цепи у фидеров (C_PowerClip.net_id)
var label := 0
## Подпись вывода в модели ("A", "B") или пусто
var suffix := ""
## Команда пульта, % (знак это полярность)
var command := 0
var v_max := 100.0
## Лимит тока, А
var i_max := 1.0
## Защита отключила вывод (перегрузка, КЗ). Сброс: PGM.reset_output. Отделено от аварийного стопа источника (Q8)
var tripped := false
var state: State = State.OK
## "overload", "polarity", "frog", "" 
var trip_reason := ""
## Сколько секунд подряд ток выше лимита
var overload_t := 0.0
## Ток вывода, А (считает PowerSolver, 10 Гц)
var current := 0.0


func state_text() -> String:
	match state:
		State.OVERLOAD:
			return "перегрузка"
		State.TRIPPED:
			return "отключён защитой"
		State.SHORT:
			return "КЗ"
	return "норма"


func save_data() -> Dictionary:
	return {"label": label, "command": command, "tripped": tripped, "reason": trip_reason}


func load_data(d: Dictionary) -> void:
	command = clampi(int(d.get("command", 0)), -int(v_max), int(v_max))
	tripped = bool(d.get("tripped", false))
	trip_reason = String(d.get("reason", ""))
	overload_t = 0.0
	current = 0.0
	state = State.OK
	if tripped:
		state = State.SHORT if trip_reason in ["polarity", "frog", "conflict"] else State.TRIPPED
