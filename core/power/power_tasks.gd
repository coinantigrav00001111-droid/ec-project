class_name PowerTasks extends RefCounted

#####################
## Игровые задачи электрики (ATTN_10 §10.9 D5, уровень P1)
#####################
## Каркаса задач в проекте пока нет, поэтому задача это условия, проверяемые по состоянию макета: каждое условие
## даёт строку «✓» или «✗» с подсказкой, что сделать. Показываются во вкладке «Коммутаторы». Чистое чтение PGM, ничего не меняет.
## T1 «Два пульта, два поезда»: два источника, селектор, два локо на разных цепях, нет конфликта выводов
## T2 «Петля с реверсором»: реверсор в цепи питания клипа, нет КЗ полярности

const TASKS := {
	&"two_cabs": "Два пульта, два поезда",
	&"loop": "Петля с реверсором",
}


## {"done": bool, "lines": Array[String]}
static func evaluate(id: StringName, tree: SceneTree) -> Dictionary:
	match id:
		&"two_cabs":
			return _two_cabs(tree)
		&"loop":
			return _loop(tree)
	return {"done": false, "lines": ["Неизвестная задача"]}


static func _devices(tree: SceneTree, script: Script) -> Array:
	var res: Array = []
	for n in tree.get_nodes_in_group(&"power_device"):
		if is_instance_valid(n) and n.get_script() == script:
			res.append(n)
	return res


static func _line(ok: bool, text: String) -> String:
	return ("✓ " if ok else "✗ ") + text


static func _conflicts() -> int:
	var n := 0
	for clip in PGM.active_clips:
		if is_instance_valid(clip) and clip.conflict == "label":
			n += 1
	return n


static func _two_cabs(tree: SceneTree) -> Dictionary:
	var lines: Array[String] = []
	var sources: int = PGM.sources.size()
	var ok_src := sources >= 2
	lines.append(_line(ok_src, "Два пульта на столе (сейчас %d)" % sources))
	var ok_sel := not _devices(tree, C_BlockSelector).is_empty()
	lines.append(_line(ok_sel, "Селектор блоков на общем участке" if ok_sel else "Поставьте селектор блоков: он выбирает, какой пульт ведёт общий участок"))
	var nets: Dictionary = {}
	for p in PGM.ports:
		if p != null and p.net != 0 and (p.owner == null or is_instance_valid(p.owner)):
			nets[p.net] = true
	var ok_trains := nets.size() >= 2
	lines.append(_line(ok_trains, "Два локо питаются от разных выводов (сейчас %d)" % nets.size()))
	var conf := _conflicts()
	lines.append(_line(conf == 0, "Нет конфликта выводов" if conf == 0 else "Два пульта на одну цепь: разделите блоки изостыком или поставьте селектор (конфликтов: %d)" % conf))
	return {"done": ok_src and ok_sel and ok_trains and conf == 0, "lines": lines}


static func _loop(tree: SceneTree) -> Dictionary:
	var lines: Array[String] = []
	var revs := _devices(tree, C_Reverser)
	var ok_rev := not revs.is_empty()
	lines.append(_line(ok_rev, "Реверсор на питании петли" if ok_rev else "Поставьте реверсор: без него поезд встанет у границы петли"))
	var via := false
	for clip in PGM.active_clips:
		if is_instance_valid(clip):
			for r in revs:
				if clip.drive_via.has(r):
					via = true
	lines.append(_line(via, "Клип петли питается через реверсор" if via else "Проведите провод от пульта через реверсор к клипу петли"))
	var shorts: int = PGM.shorted_nets.size()
	lines.append(_line(shorts == 0, "Нет КЗ полярности" if shorts == 0 else "КЗ полярности в %d цеп.: поставьте изостыки с обеих сторон петли" % shorts))
	return {"done": ok_rev and via and shorts == 0, "lines": lines}
