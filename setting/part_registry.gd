class_name PartRegistry extends RefCounted

########################
## Реестр частей инстанса сцены (вагон, трак...). Чистый RefCounted, без нод.
## Строится один раз в C_Visual после instantiate(): PartRegistry.build(instance).
########################
## Как узел получает роль (по приоритету):
##  1. meta "role" на узле, либо glTF extras {"role": "..."} (Blender: Custom Property "role",
##     при экспорте включить Custom Properties). Имя узла при этом НЕ важно.
##  2. имя узла: регистр, разделители и хвосты дублей (.001, _2) игнорируются.
##     "Door_Left.001" == "doorleft" == роль &"door_left"
##  3. алиасы, переданные вызывающим (старые имена: "WheelPairMesh", "WagonCollisionShape3D")
## Не нашли - возвращаем null/[] и предупреждаем деревом узлов (describe). Никаких падений.

const META_ROLE := &"role"

var root: Node
var _nodes: Array[Node] = []
var _meta: Dictionary = {}      # Node -> явная роль (String)

static var _dup_re: RegEx


static func build(p_root: Node) -> PartRegistry:
	var r := PartRegistry.new()
	r.root = p_root
	if p_root:
		r._scan(p_root)
	return r


## Все узлы с этой ролью. Явная роль (meta) всегда сильнее имени:
## если есть хоть один узел с meta-ролью, имена не рассматриваются.
## type - класс движка ("MeshInstance3D", "CollisionShape3D"), under - искать только внутри этого узла
func find_all(role: StringName, aliases: Variant = [], type: StringName = &"", under: Node = null) -> Array[Node]:
	var keys: Array[String] = [normalize(String(role))]
	for a in aliases:
		keys.append(normalize(String(a)))

	var by_meta: Array[Node] = []
	var by_name: Array[Node] = []
	for n in _nodes:
		if not is_instance_valid(n) or not _accept(n, type, under):
			continue
		if _meta.has(n):
			if normalize(String(_meta[n])) == keys[0]:
				by_meta.append(n)
		elif _name_matches(String(n.name), keys):
			by_name.append(n)
	return by_meta if not by_meta.is_empty() else by_name


## Первый подходящий узел или null (с предупреждением и деревом сцены)
func find_one(role: StringName, aliases: Variant = [], type: StringName = &"", under: Node = null, owner_name := "") -> Node:
	var all := find_all(role, aliases, type, under)
	if all.is_empty():
		push_warning("[PartRegistry] %s: часть '%s' не найдена. Узлы сцены:\n%s" % [owner_name, role, describe()])
		return null
	if all.size() > 1:
		push_warning("[PartRegistry] %s: у роли '%s' %d узлов, беру первый (%s)" % [owner_name, role, all.size(), all[0].name])
	return all[0]


func has_role(role: StringName, aliases: Variant = []) -> bool:
	return not find_all(role, aliases).is_empty()


## Дерево узлов с классами и явными ролями. Для логов и вкладки Debug
func describe() -> String:
	var lines: Array[String] = []
	if root:
		_describe_rec(root, 0, lines)
	return "\n".join(lines)


# ==========================================
# Внутреннее
# ==========================================

func _scan(n: Node) -> void:
	for c in n.get_children():
		_nodes.append(c)
		var r := _read_meta_role(c)
		if r != "":
			_meta[c] = r
		_scan(c)


static func _read_meta_role(n: Node) -> String:
	if n.has_meta(META_ROLE):
		return str(n.get_meta(META_ROLE))
	if n.has_meta(&"extras"):
		var ex: Variant = n.get_meta(&"extras")
		if ex is Dictionary and ex.has("role"):
			return str(ex["role"])
	return ""


func _accept(n: Node, type: StringName, under: Node) -> bool:
	if type != &"" and not n.is_class(String(type)):
		return false
	if under != null and not under.is_ancestor_of(n):
		return false
	return true


static func _name_matches(raw: String, keys: Array[String]) -> bool:
	var n1 := normalize(raw)
	var n2 := normalize(_strip_dup(raw))
	for k in keys:
		if k != "" and (k == n1 or k == n2):
			return true
	return false


## Нижний регистр, только буквы и цифры: "Door_Left" -> "doorleft"
static func normalize(s: String) -> String:
	var out := ""
	for ch in s.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out


## Хвост дубля от Blender/Godot: ".001", "_2", "-3"
static func _strip_dup(s: String) -> String:
	if _dup_re == null:
		_dup_re = RegEx.create_from_string("[._\\-]?\\d+$")
	return _dup_re.sub(s, "")


func _describe_rec(n: Node, depth: int, lines: Array[String]) -> void:
	var tag := ""
	if _meta.has(n):
		tag = "  [role=%s]" % _meta[n]
	lines.append("%s%s (%s)%s" % ["  ".repeat(depth), n.name, n.get_class(), tag])
	for c in n.get_children():
		_describe_rec(c, depth + 1, lines)
