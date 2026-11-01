extends Node

# D1 (ATTN_10 §10.9): новый файл
## Тест графа цепей RailNetGraph: объединение с чётностью. Чистая математика, сцена не нужна.
## Запуск: открыть tests/rail_net_test.tscn и нажать F6. Результат в Output: строки PASS / FAIL и итог.
## Проверяется: цепочка, чётное кольцо, нечётный цикл (противоречие), две компоненты, отсутствие ребра (изостык),
## возврат к прежнему назначению после снятия ребра, длинная цепочка без рекурсии, случайные графы против полного перебора.

var _fails := 0


func check(name: String, ok: bool, info := "") -> void:
	if ok:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name, "  ", info)


## Граф из списка рёбер [a, b, flip]
func build(edges: Array, extra_nodes: Array = []) -> RailNetGraph:
	var g := RailNetGraph.new()
	for n in extra_nodes:
		g.add_node(n)
	for e in edges:
		g.add_edge(e[0], e[1], e[2])
	return g


## Назначение (компонента, чётность) по узлам в виде, не зависящем от выбора корня: пары «одна цепь, развёрнуты»
func signature(g: RailNetGraph, nodes: Array) -> Array:
	var out: Array = []
	for i in nodes.size():
		for j in range(i + 1, nodes.size()):
			var same := g.same_net(nodes[i], nodes[j])
			out.append([same, g.flip_between(nodes[i], nodes[j]) if same else false])
	return out


## Эталон: обход в ширину с раскраской. Возвращает {"comp": узел -> номер компоненты, "color": узел -> bool, "bad": номера противоречивых компонент}
func brute(nodes: Array, edges: Array) -> Dictionary:
	var adj: Dictionary = {}
	for n in nodes:
		adj[n] = []
	for e in edges:
		adj[e[0]].append([e[1], e[2]])
		adj[e[1]].append([e[0], e[2]])
	var comp: Dictionary = {}
	var color: Dictionary = {}
	var bad: Dictionary = {}
	var k := 0
	for s in nodes:
		if comp.has(s):
			continue
		comp[s] = k
		color[s] = false
		var queue: Array = [s]
		while not queue.is_empty():
			var u = queue.pop_front()
			for nb in adj[u]:
				var v = nb[0]
				var want: bool = (color[u] != nb[1])
				if not comp.has(v):
					comp[v] = k
					color[v] = want
					queue.append(v)
				elif color[v] != want:
					bad[k] = true
		k += 1
	return {"comp": comp, "color": color, "bad": bad}


func _ready() -> void:
	# --- цепочка: чётности копятся вдоль цепочки ---
	var g := build([[0, 1, false], [1, 2, true], [2, 3, false]])
	check("цепочка: одна цепь", g.same_net(0, 3))
	check("цепочка: 0 и 1 не развёрнуты", not g.flip_between(0, 1))
	check("цепочка: 0 и 2 развёрнуты (стык «лицом к лицу»)", g.flip_between(0, 2))
	check("цепочка: 0 и 3 развёрнуты", g.flip_between(0, 3))
	check("цепочка: противоречий нет", g.conflicts.is_empty())

	# --- чётное кольцо (два flip) согласовано, простое кольцо без flip тоже ---
	g = build([[0, 1, false], [1, 2, true], [2, 3, true], [3, 0, false]])
	check("кольцо с двумя разворотами согласовано", g.conflicts.is_empty() and g.same_net(0, 2))
	g = build([[0, 1, false], [1, 2, false], [2, 3, false], [3, 0, false]])
	check("кольцо без разворотов согласовано", g.conflicts.is_empty())

	# --- нечётный цикл (реверсивная петля): одно противоречие ---
	g = build([[0, 1, false], [1, 2, false], [2, 0, true]])
	check("нечётный цикл: противоречие найдено", g.conflicts.size() == 1, str(g.conflicts))
	check("нечётный цикл: цепь всё равно одна", g.same_net(0, 2))
	if g.conflicts.size() == 1:
		var cf: Dictionary = g.conflicts[0]
		check("нечётный цикл: указаны два разных узла цикла", cf.a != cf.b and cf.a in [0, 1, 2] and cf.b in [0, 1, 2], str(cf))

	# --- две компоненты ---
	g = build([[0, 1, false], [2, 3, true]], [9])
	check("две компоненты: раздельны", not g.same_net(0, 2) and not g.same_net(1, 3))
	check("узел без рёбер сам по себе", not g.same_net(9, 0) and g.components().size() == 3)

	# --- изостык: ребра нет, цепь рвётся ---
	g = build([[0, 1, false], [1, 2, false], [2, 3, false]])
	check("без изостыка: хвост в цепи", g.same_net(0, 3))
	g = build([[0, 1, false], [2, 3, false]], [])   # ребро 1-2 не добавлено
	check("изостык: хвост отдельно", not g.same_net(0, 3))

	# --- возврат к прежнему назначению после снятия и возвращения ребра ---
	var nodes := [0, 1, 2, 3, 4]
	var edges := [[0, 1, false], [1, 2, true], [2, 3, false], [3, 4, true]]
	var before := signature(build(edges), nodes)
	var without: Array = edges.duplicate()
	without.remove_at(2)
	var cut := build(without)
	check("снято ребро 2-3: цепь разделилась", not cut.same_net(0, 4))
	var after := signature(build(edges), nodes)
	check("ребро возвращено: прежнее назначение", before == after)
	# порядок добавления рёбер не влияет на результат
	var shuffled: Array = edges.duplicate()
	shuffled.reverse()
	check("порядок рёбер не важен", signature(build(shuffled), nodes) == before)

	# --- длинная цепочка (нет рекурсии) ---
	var long_edges: Array = []
	for i in 20000:
		long_edges.append([i, i + 1, i % 3 == 0])
	var lg := build(long_edges)
	var flips := 0
	for i in 20000:
		if i % 3 == 0:
			flips += 1
	check("цепочка 20000: одна цепь", lg.same_net(0, 20000))
	check("цепочка 20000: чётность конца", lg.flip_between(0, 20000) == (flips % 2 == 1))

	# --- случайные графы против обхода в ширину ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var rand_ok := true
	var rand_info := ""
	for trial in 300:
		var n := rng.randi_range(2, 14)
		var m := rng.randi_range(0, 22)
		var ns: Array = range(n)
		var es: Array = []
		for k in m:
			var a := rng.randi_range(0, n - 1)
			var b := rng.randi_range(0, n - 1)
			if a == b:
				continue
			es.append([a, b, rng.randf() < 0.4])
		var gr := build(es, ns)
		var br := brute(ns, es)
		# компоненты совпадают
		for i in n:
			for j in n:
				if gr.same_net(i, j) != (br.comp[i] == br.comp[j]):
					rand_ok = false
					rand_info = "trial %d: компоненты %d,%d" % [trial, i, j]
		# противоречивость компоненты: по графу есть конфликт в компоненте <=> обход нашёл
		var bad_roots: Dictionary = {}
		for cf2 in gr.conflicts:
			bad_roots[gr.root_of(cf2.a)] = true
		for i in n:
			var graph_bad: bool = bad_roots.has(gr.root_of(i))
			var brute_bad: bool = br.bad.has(br.comp[i])
			if graph_bad != brute_bad:
				rand_ok = false
				rand_info = "trial %d: противоречие у узла %d" % [trial, i]
		# чётность между узлами согласованной компоненты совпадает с раскраской
		for i in n:
			for j in n:
				if br.comp[i] == br.comp[j] and not br.bad.has(br.comp[i]):
					if gr.flip_between(i, j) != (br.color[i] != br.color[j]):
						rand_ok = false
						rand_info = "trial %d: чётность %d,%d" % [trial, i, j]
	check("300 случайных графов совпали с обходом в ширину", rand_ok, rand_info)

	print("--------")
	print("rail_net_test: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit()
