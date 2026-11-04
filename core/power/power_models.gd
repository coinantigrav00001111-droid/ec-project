class_name PowerModels extends RefCounted

#####################
## Реестр моделей источников питания (ATTN_10 §10.5.5, D2)
#####################
## Модель это набор данных, класс источника один (`PowerSource`, вариант V3). Позже модели переедут в ресурсы `.tres`.
## Поля модели:
##  name           подпись на панели
##  outputs        число выводов
##  suffix         подписи выводов ("A", "B"); пусто: у выводов только номер
##  shared_handle  true: одна ручка, выбор вывода, у каждого вывода своя память команды (нынешний «PWM»); false: ручка на вывод (D4)
##  v_max          предел команды, % (100 = полное напряжение)
##  i_max          предел тока вывода, А
##  protection     true: перегрузка отключает вывод (OVERLOAD, затем TRIPPED); false: пульт без защиты
##  needs_supply   true: без питающей сети пульт мёртв (PowerSupply.on)
##  regulation     способ регулирования (для описания и будущих эффектов start_boost, momentum, brake)
## В D2 в играх живёт только `multi`, остальные описаны и ждут своих панелей (D4).

const MULTI := &"multi"

const MODELS := {
	&"multi": {
		"name": "Multi PWM", "outputs": 10, "suffix": [], "shared_handle": true,
		"v_max": 100.0, "i_max": 1.0, "protection": true, "needs_supply": true, "regulation": &"pwm",
	},
	&"standard": {
		"name": "Standard PWM", "outputs": 1, "suffix": [], "shared_handle": true,
		"v_max": 100.0, "i_max": 1.5, "protection": true, "needs_supply": true, "regulation": &"pwm",
	},
	&"dual": {
		"name": "Dual-cab", "outputs": 2, "suffix": ["A", "B"], "shared_handle": false,
		"v_max": 100.0, "i_max": 1.0, "protection": true, "needs_supply": true, "regulation": &"pwm",
	},
	&"starter": {
		"name": "Starter set", "outputs": 1, "suffix": [], "shared_handle": true,
		"v_max": 100.0, "i_max": 0.8, "protection": false, "needs_supply": false, "regulation": &"resistive",
	},
}


static func has_model(id: StringName) -> bool:
	return MODELS.has(id)


## Данные модели. Неизвестный id даёт `multi`
static func get_model(id: StringName) -> Dictionary:
	return MODELS.get(id, MODELS[MULTI])


static func ids() -> Array:
	return MODELS.keys()
