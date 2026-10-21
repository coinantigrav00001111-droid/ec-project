extends Node
# class_name не задаём: это синглтон TGM (autoload), как PGM
###########################
## 💡 TGM - Системный сервис (autoload). Рельеф: реестр листов пенопласта и события об изменениях.
############################
# XX claude-terra (новый файл)
##
## Лист пенопласта = Entity с C_TerrainLayer. Отдельного списка не ведем: лист при готовности
## входит в группу GROUP, а get_layers() отфильтровывает призраков и удаляемые листы.
## Аналитические запросы по полигонам (верх земли под точкой, "внутри листа") добавляются в T2
## (см. ATTN_13_1_3_TerrainPlan.md). Физические лучи остаются для тулов, опор и вагонов.

## Лист изменился (поставлен, сдвинут, удален, поменял форму). aabb - мировая область изменения.
## Слушают опоры эстакады и все, кому важна земля под ними
signal terrain_changed(aabb: AABB)

const GROUP := &'terrain_layer'


## Живые листы: без призраков и без тех, что уже удаляются
func get_layers() -> Array[Entity]:
	var res: Array[Entity] = []
	for n in get_tree().get_nodes_in_group(GROUP):
		var e := n as Entity
		if e == null or not e.is_inside_tree() or e.is_queued_for_deletion() or e.has_comp(C_Ghost):
			continue
		res.append(e)
	return res


## Вызывает C_TerrainLayer. Сообщает, что земля в этой области изменилась
func notify_changed(aabb: AABB) -> void:
	terrain_changed.emit(aabb)
