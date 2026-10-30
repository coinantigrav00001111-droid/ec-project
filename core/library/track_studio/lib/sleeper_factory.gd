class_name TrackSleeperFactory extends RefCounted

########################
## Меши шпал (ATTN_20, шаг T3)
########################
## Без интерфейса. Контракт меша шпалы (ATTN_15 §2, ATTN_20 §20.3.3): origin в центре площади опоры,
## низ на y = 0, длинная сторона поперёк пути по X (там рельсы), шаг вдоль Z.
## Меши генератора одноповерхностные, UV в ю (1 единица UV = 1 ю): материал масштабирует тайл через uv1_scale.

const GENERATED_DEFAULTS := {
	"kind": "wood",        # wood | concrete
	"length": 3.0,         # по X, поперёк пути
	"height": 0.2,         # без подрельсовых площадок
	"width": 0.3,          # по Z, вдоль пути
	"chamfer": 0.02,       # фаска рёбер, ю
	"taper": 0.03,         # бетон: на сколько верх уже низа с каждой стороны, ю
	"pad_height": 0.02,    # бетон: высота подрельсовых площадок (0 = без них)
	"pad_length": 0.4,     # бетон: длина площадки по X
	"rail_x": 0.875,       # бетон: где стоят площадки (половина колеи)
}


# ==========================================
# Генератор
# ==========================================

static func generate(spec: Dictionary) -> ArrayMesh:
	var s: Dictionary = GENERATED_DEFAULTS.duplicate()
	s.merge(spec, true)
	var L := maxf(float(s["length"]), 0.05)
	var H := maxf(float(s["height"]), 0.02)
	var W := maxf(float(s["width"]), 0.02)
	var c := clampf(float(s["chamfer"]), 0.0, minf(H, W) * 0.45)
	var concrete: bool = s["kind"] == "concrete"
	var tp := clampf(float(s["taper"]), 0.0, W * 0.3) if concrete else 0.0

	# Сечение в плоскости (z, y), против часовой, низ слева направо
	var prof: Array[Vector2] = []
	var hw := W * 0.5
	var tw := hw - tp
	if concrete:
		prof = _dedupe([
			Vector2(-hw, 0.0), Vector2(hw, 0.0),
			Vector2(tw, H - c), Vector2(tw - c, H),
			Vector2(-tw + c, H), Vector2(-tw, H - c)])
	else:
		prof = _dedupe([
			Vector2(-hw + c, 0.0), Vector2(hw - c, 0.0), Vector2(hw, c), Vector2(hw, H - c),
			Vector2(hw - c, H), Vector2(-hw + c, H), Vector2(-hw, H - c), Vector2(-hw, c)])

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Боковая поверхность: прямоугольники вдоль X
	var perim := 0.0
	for i in prof.size():
		var a: Vector2 = prof[i]
		var b: Vector2 = prof[(i + 1) % prof.size()]
		var d := b - a
		var seg := d.length()
		var n := Vector3(0.0, -d.x, d.y).normalized()   # наружу: (dy, -dz) в осях (z, y)
		var p0 := Vector3(-L * 0.5, a.y, a.x)
		var p1 := Vector3(L * 0.5, a.y, a.x)
		var p2 := Vector3(L * 0.5, b.y, b.x)
		var p3 := Vector3(-L * 0.5, b.y, b.x)
		TrackMeshBuilder.quad(st, [p0, p1, p2, p3], [n, n, n, n],
			[Vector2(0.0, perim), Vector2(L, perim), Vector2(L, perim + seg), Vector2(0.0, perim + seg)])
		perim += seg

	# Торцы: веер из выпуклого многоугольника
	for end_sign in [-1.0, 1.0]:
		var x: float = end_sign * L * 0.5
		var n := Vector3(end_sign, 0.0, 0.0)
		var center := Vector2.ZERO
		for v in prof:
			center += v
		center /= prof.size()
		for i in prof.size():
			var a: Vector2 = prof[i]
			var b: Vector2 = prof[(i + 1) % prof.size()]
			_tri(st, Vector3(x, center.y, center.x), Vector3(x, a.y, a.x), Vector3(x, b.y, b.x), n,
				Vector2(center.x, center.y), a, b)

	# Бетон: подрельсовые площадки
	if concrete and float(s["pad_height"]) > 0.001:
		var ph := float(s["pad_height"])
		var pl := minf(float(s["pad_length"]), L * 0.4)
		var pw := (tw - c) * 2.0
		for sx in [-1.0, 1.0]:
			_box(st, Vector3(sx * float(s["rail_x"]) - pl * 0.5, H, -pw * 0.5), Vector3(pl, ph, pw))

	st.generate_tangents()
	return st.commit()


## Коробка с плоскими нормалями и UV в ю. pos = минимальный угол
static func _box(st: SurfaceTool, pos: Vector3, size: Vector3) -> void:
	var a := pos
	var b := pos + size
	# грани: [нормаль, 4 угла]
	var faces := [
		[Vector3.UP, Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)],
		[Vector3.DOWN, Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z)],
		[Vector3.RIGHT, Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(b.x, a.y, b.z)],
		[Vector3.LEFT, Vector3(a.x, a.y, a.z), Vector3(a.x, b.y, a.z), Vector3(a.x, b.y, b.z), Vector3(a.x, a.y, b.z)],
		[Vector3.BACK, Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)],
		[Vector3.FORWARD, Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(a.x, b.y, a.z)],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var pts: Array = [f[1], f[2], f[3], f[4]]
		var uvs: Array = []
		for p in pts:
			# планарная проекция по оси нормали
			if absf(n.y) > 0.5:
				uvs.append(Vector2(p.x, p.z))
			elif absf(n.x) > 0.5:
				uvs.append(Vector2(p.z, p.y))
			else:
				uvs.append(Vector2(p.x, p.y))
		TrackMeshBuilder.quad(st, pts, [n, n, n, n], uvs)


## Треугольник; порядок вершин выбирается по ожидаемой нормали (Godot: лицевая сторона по часовой)
static func _tri(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, n: Vector3, uv0: Vector2, uv1: Vector2, uv2: Vector2) -> void:
	var geo := (p1 - p0).cross(p2 - p0)
	var idx := [0, 1, 2]
	if geo.dot(n) > 0.0:
		idx = [0, 2, 1]
	var ps := [p0, p1, p2]
	var uvs := [uv0, uv1, uv2]
	for k in idx:
		st.set_normal(n)
		st.set_uv(uvs[k])
		st.add_vertex(ps[k])


static func _dedupe(pts: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in pts:
		if out.is_empty() or not out[out.size() - 1].is_equal_approx(p):
			out.append(p)
	if out.size() > 1 and out[0].is_equal_approx(out[out.size() - 1]):
		out.remove_at(out.size() - 1)
	return out


# ==========================================
# Импорт и нормализация
# ==========================================

## Меши из ресурса: Mesh -> один элемент; PackedScene (.glb, .gltf, .tscn) -> все MeshInstance3D.
## Элемент: {name, mesh, xform} (xform относительно корня сцены)
static func load_meshes(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var res := ResourceLoader.load(path)
	if res is Mesh:
		out.append({"name": path.get_file().get_basename(), "mesh": res, "xform": Transform3D.IDENTITY})
	elif res is PackedScene:
		var root := (res as PackedScene).instantiate()
		_collect(root, Transform3D.IDENTITY, out)
		root.free()
	return out


static func _collect(node: Node, parent_xf: Transform3D, out: Array[Dictionary]) -> void:
	var xf := parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	var mi := node as MeshInstance3D
	if mi and mi.mesh:
		out.append({"name": String(mi.name), "mesh": mi.mesh, "xform": xf})
	for c in node.get_children():
		_collect(c, xf, out)


## Приводит меши к контракту. items: [{mesh, xform}], opts: scale (множитель), rotate_y (градусы),
## auto_orient (длинную сторону на X), keep_materials, merge (слить поверхности в одну).
## Возвращает {mesh: ArrayMesh, report: {...}}
@warning_ignore("integer_division")
static func normalize(items: Array, opts: Dictionary = {}) -> Dictionary:
	var o := {"scale": 1.0, "rotate_y": 0.0, "auto_orient": true, "keep_materials": true, "merge": false}
	o.merge(opts, true)
	var notes := PackedStringArray()
	var report := {"notes": notes}

	var pre := Transform3D(Basis.from_euler(Vector3(0.0, deg_to_rad(float(o["rotate_y"])), 0.0)).scaled(Vector3.ONE * float(o["scale"])), Vector3.ZERO)
	var before := _bounds(items, Transform3D.IDENTITY)
	var box := _bounds(items, pre)
	report["before"] = before
	if o["auto_orient"] and box.size.x < box.size.z - 0.0001:
		pre = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO) * pre
		box = _bounds(items, pre)
		notes.append("длинная сторона была по Z: повёрнуто на 90° вокруг Y")
	var c := box.get_center()
	var offset := Vector3(-c.x, -box.position.y, -c.z)
	var final_xf := Transform3D(Basis.IDENTITY, offset) * pre
	if final_xf.basis.determinant() < 0.0:
		notes.append("зеркальное преобразование: лицевые стороны могут быть вывернуты")

	var mesh := ArrayMesh.new()
	var merged := {}   # ключ массива -> объединённые данные (при merge)
	var merge_ok: bool = o["merge"]
	var verts_total := 0
	for it in items:
		var src: Mesh = it["mesh"]
		var xf: Transform3D = final_xf * (it["xform"] as Transform3D)
		for s in src.get_surface_count():
			if src.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				notes.append("поверхность %d не из треугольников, пропущена" % s)
				continue
			var arrays := _transform_arrays(src.surface_get_arrays(s), xf)
			if merge_ok:
				_merge_into(merged, arrays, verts_total)
				verts_total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			else:
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				if o["keep_materials"]:
					mesh.surface_set_material(mesh.get_surface_count() - 1, src.surface_get_material(s))
	if merge_ok:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		for k in merged:
			arrays[k] = merged[k]
		if arrays[Mesh.ARRAY_VERTEX] != null:
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	report["after"] = mesh.get_aabb()
	report["surfaces"] = mesh.get_surface_count()
	report["triangles"] = mesh.get_faces().size() / 3
	return {"mesh": mesh, "report": report}


## AABB всех мешей после преобразования pre * xform
static func _bounds(items: Array, pre: Transform3D) -> AABB:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for it in items:
		var t: Transform3D = pre * (it["xform"] as Transform3D)
		var a: AABB = (it["mesh"] as Mesh).get_aabb()
		for i in 8:
			var p := t * a.get_endpoint(i)
			lo = lo.min(p)
			hi = hi.max(p)
	if lo.x == INF:
		return AABB()
	return AABB(lo, hi - lo)


static func _transform_arrays(arrays: Array, xf: Transform3D) -> Array:
	var out := arrays.duplicate()
	var nb := xf.basis.inverse().transposed()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nv := PackedVector3Array()
	nv.resize(verts.size())
	for i in verts.size():
		nv[i] = xf * verts[i]
	out[Mesh.ARRAY_VERTEX] = nv
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var nn := PackedVector3Array()
		nn.resize(ns.size())
		for i in ns.size():
			nn[i] = (nb * ns[i]).normalized()
		out[Mesh.ARRAY_NORMAL] = nn
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var ts: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var nt := ts.duplicate()
		for i in range(0, ts.size() - 3, 4):
			var t3 := (xf.basis * Vector3(ts[i], ts[i + 1], ts[i + 2])).normalized()
			nt[i] = t3.x
			nt[i + 1] = t3.y
			nt[i + 2] = t3.z
		out[Mesh.ARRAY_TANGENT] = nt
	return out


## Добавляет массивы поверхности в общий набор; индексы сдвигаются на offset вершин
static func _merge_into(merged: Dictionary, arrays: Array, offset: int) -> void:
	for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV]:
		if arrays[k] == null:
			continue
		if not merged.has(k):
			merged[k] = arrays[k].duplicate()
		else:
			merged[k].append_array(arrays[k])
	var idx: PackedInt32Array
	if arrays[Mesh.ARRAY_INDEX] != null:
		idx = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).duplicate()
	else:
		idx = PackedInt32Array()
		var n := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		idx.resize(n)
		for i in n:
			idx[i] = i
	for i in idx.size():
		idx[i] += offset
	if not merged.has(Mesh.ARRAY_INDEX):
		merged[Mesh.ARRAY_INDEX] = idx
	else:
		merged[Mesh.ARRAY_INDEX].append_array(idx)


## Сводка по мешу: {size, aabb, triangles, surfaces}
@warning_ignore("integer_division")
static func info(mesh: Mesh) -> Dictionary:
	if mesh == null:
		return {}
	return {"aabb": mesh.get_aabb(), "size": mesh.get_aabb().size, "triangles": mesh.get_faces().size() / 3, "surfaces": mesh.get_surface_count()}


## Записывает меш в .res и привязывает к файлу (стиль будет хранить ссылку). Возвращает Error
static func save_mesh(mesh: Mesh, path: String) -> int:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var err := ResourceSaver.save(mesh, path)
	if err == OK:
		mesh.take_over_path(path)
	return err
