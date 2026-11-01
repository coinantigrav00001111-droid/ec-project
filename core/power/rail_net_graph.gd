class_name RailNetGraph extends RefCounted

#####################
## Граф электрических узлов с чётностью (ATTN_10 §10.5.4, D1)
#####################
## Чистая математика, без узлов и сцены: проверяется `tests/rail_net_test.tscn`.
##
## Узел это точка сети (у траков пара «сущность, луч»). Ребро соединяет два узла и несёт чётность `flip`:
## true, если полярность за стыком развёрнута (конец к концу, начало к началу).
## Объединение с чётностью (union-find): у каждого узла хранится родитель и чётность относительно него.
## Цепь это компонент связности, `parity_of(узел)` это развёрнутость узла относительно корня компонента.
## Ребро внутри уже связанной компоненты, которое не сходится по чётности, это противоречие
## (реверсивная петля без изостыков: КЗ полярности), оно попадает в `conflicts`.
## Обход итеративный (цепочка из тысяч узлов не упирается в предел рекурсии).

var _parent: Dictionary = {}   # узел -> родитель
var _parity: Dictionary = {}   # узел -> чётность относительно родителя (bool)
var _size: Dictionary = {}     # корень -> размер компоненты
var _last_parity := false      # чётность последнего найденного узла относительно корня

## Рёбра, не сошедшиеся по чётности: {"a": узел, "b": узел}
var conflicts: Array[Dictionary] = []


func clear() -> void:
	_parent.clear()
	_parity.clear()
	_size.clear()
	conflicts.clear()
	_last_parity = false


func add_node(id: Variant) -> void:
	if _parent.has(id):
		return
	_parent[id] = id
	_parity[id] = false
	_size[id] = 1


func has_node(id: Variant) -> bool:
	return _parent.has(id)


func node_count() -> int:
	return _parent.size()


## Ребро a-b. flip: полярность узла b относительно узла a развёрнута
func add_edge(a: Variant, b: Variant, flip: bool = false) -> void:
	add_node(a)
	add_node(b)
	var ra: Variant = _find(a)
	var pa := _last_parity
	var rb: Variant = _find(b)
	var pb := _last_parity
	if ra == rb:
		# уже в одной цепи: развёрнутости a и b обязаны давать flip
		if (pa != pb) != flip:
			conflicts.append({"a": a, "b": b})
		return
	# вешаем меньшую компоненту под большую; чётность корня подбираем так, чтобы parity(a) xor parity(b) == flip
	var x := (pa != pb) != flip
	if _size[ra] >= _size[rb]:
		_parent[rb] = ra
		_parity[rb] = x
		_size[ra] += _size[rb]
	else:
		_parent[ra] = rb
		_parity[ra] = x
		_size[rb] += _size[ra]


## Корень компоненты узла (идентификатор цепи внутри графа)
func root_of(id: Variant) -> Variant:
	return _find(id)


## Развёрнутость узла относительно корня своей компоненты
func parity_of(id: Variant) -> bool:
	_find(id)
	return _last_parity


## Развёрнутость узла b относительно узла a. Только для узлов одной компоненты
func flip_between(a: Variant, b: Variant) -> bool:
	return parity_of(a) != parity_of(b)


func same_net(a: Variant, b: Variant) -> bool:
	return _find(a) == _find(b)


## Все узлы по компонентам: корень -> Array узлов
func components() -> Dictionary:
	var res: Dictionary = {}
	for id in _parent.keys():
		var r: Variant = _find(id)
		if not res.has(r):
			res[r] = []
		res[r].append(id)
	return res


## Поиск корня со сжатием пути. Чётность узла относительно корня остаётся в _last_parity
func _find(x: Variant) -> Variant:
	var path: Array = []
	var cur: Variant = x
	while _parent[cur] != cur:
		path.append(cur)
		cur = _parent[cur]
	var root: Variant = cur
	# сжатие от ближайшего к корню узла к дальнему, чётность накапливается по пути
	var acc := false
	for i in range(path.size() - 1, -1, -1):
		var n: Variant = path[i]
		acc = acc != bool(_parity[n])
		_parity[n] = acc
		_parent[n] = root
	_last_parity = bool(_parity[x]) if x != root else false
	return root
