class_name LightBudget extends Node

########################
## Бюджет источников света сущностей (ATTN_16_mechanisms.md, §16.6). Владелец: GFX (GFX.light_budget).
########################
## C_Mechanisms регистрируется здесь, если у сущности есть источники света.
## Раз в INTERVAL секунд: берём все источники, которые хотят гореть (яркость > 0, не призрак),
## сортируем по расстоянию до камеры, ближайшие QualityPreset.entity_light_max остаются видимыми,
## остальные скрываются (Lamp.culled). Состояние источника при этом не меняется.
## Скрытие мгновенное, без плавного перехода: на границе лимита источник может "щёлкнуть".

const INTERVAL := 0.25
const DEFAULT_MAX := 8

## Сколько источников хотят гореть / реально горят (для заголовка окна в debug)
var wanted := 0
var active := 0

var _comps: Array = []
var _acc := 0.0


func register(comp: Node) -> void:
	if not _comps.has(comp):
		_comps.append(comp)


func unregister(comp: Node) -> void:
	_comps.erase(comp)


func get_max() -> int:
	var q: QualityPreset = GFX.get_quality()
	return q.entity_light_max if q else DEFAULT_MAX


func _process(delta: float) -> void:
	_acc += delta
	if _acc < INTERVAL:
		return
	_acc = 0.0
	rebalance()


func rebalance() -> void:
	var cam := get_viewport().get_camera_3d()
	var origin := cam.global_position if cam else Vector3.ZERO
	var cands: Array = []   # [расстояние^2, Lamp]
	for c in _comps:
		if not is_instance_valid(c):
			continue
		for l in c.get_lamps():
			if l.wants_on() and is_instance_valid(l.light) and l.light.is_inside_tree():
				cands.append([l.light.global_position.distance_squared_to(origin), l])
			elif l.culled:
				l.culled = false   # не горит и так: флаг сбрасываем, apply не нужен
	cands.sort_custom(func(a, b): return a[0] < b[0])

	var m := get_max()
	wanted = cands.size()
	active = 0
	for i in cands.size():
		var l: C_Mechanisms.Lamp = cands[i][1]
		var cull := i >= m
		if not cull:
			active += 1
		if l.culled != cull:
			l.culled = cull
			l.apply()
