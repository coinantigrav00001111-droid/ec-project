class_name PowerSource extends RefCounted

#####################
## Источник питания: пульт (ATTN_10 §10.5.5, D2)
#####################
## Состояние пульта живёт здесь, а не в панели и не в `power_pwm`. Панель (2D) или сущность (3D, D4) только
## передаёт команды через `PGM.set_command` и читает состояние. Выводы выдаёт PGM (`register_source`).

var id := 0
var model: StringName = PowerModels.MULTI
var outputs: Array[PowerOutput] = []
var enabled := true
## Аварийный стоп рукой: все выводы источника без напряжения, команды сохраняются (Q8)
var estop := false
## Вывод, выбранный на панели: -1 все, 0 никакой, иначе метка (ContourSlider)
var selected := -1
## Кто сейчас управляет: панель или сущность. null: свободен (стол без панели, смена дизайна). Не пишется в сейв
var owner: Object = null


func data() -> Dictionary:
	return PowerModels.get_model(model)


func needs_supply() -> bool:
	return bool(data().get("needs_supply", true))


func has_protection() -> bool:
	return bool(data().get("protection", true))


func output_by_label(label: int) -> PowerOutput:
	for o in outputs:
		if o.label == label:
			return o
	return null


func labels() -> Array[int]:
	var res: Array[int] = []
	for o in outputs:
		res.append(o.label)
	return res


func is_free() -> bool:
	return owner == null or not is_instance_valid(owner)


func save_data() -> Dictionary:
	var outs: Array = []
	for o in outputs:
		outs.append(o.save_data())
	return {"id": id, "model": String(model), "enabled": enabled, "estop": estop, "selected": selected, "outputs": outs}
