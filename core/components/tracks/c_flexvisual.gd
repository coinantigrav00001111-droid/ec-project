class_name C_FlexVisual extends C_TrackVisual

# XX claude-terra (новый файл)
###################################
## Визуал flex-трака. Сцены нет: все ноды строятся в коде и принадлежат этому компоненту
## (Mesh, Sleepers, Ballast Area3D, HeadStaticBody3D), структура как у обычного трака,
## поэтому C_Path / C_Blockable / C_Socket работают по тем же правилам.
###################################
## Геометрию и высоты задает TrackStyle (рельсы, шпалы, балласт). Здесь только построение:
##  - свип-меш по кривой C_Path: балласт (если есть) и рельсы. Индекс поверхности рельсов
##    лежит в rail_surface_index (1 с балластом, 0 без), power layer работает по нему;
##  - шпалы: MultiMesh, равномерный шаг по длине кривой;
##  - коллизии: сегменты ~flex_collision_step, пул CollisionShape3D, Area3D балласта не пересоздается
##    (C_Blockable подписан на него один раз). Пересборка не чаще flex_rebuild_period, финал - on_flex_final.
## Высоту поверхности катания отдает C_Path.head_height(), число берется из style.head_height().

const MESH_STEP := 1.0
const MESH_STEP_PREVIEW := 2.0   # пока тянем конец, меш грубее
const UV_V_SCALE := 0.1
const COL_END_INSET := 0.2
const COL_OVERLAP := 0.1

class Fr extends RefCounted:
	var p: Vector3
	var r: Vector3
	var u: Vector3
	var f: Vector3

static var _mat_ballast: StandardMaterial3D
static var _mat_rail: StandardMaterial3D
static var _mat_sleeper: StandardMaterial3D

## Задает FlexSetting. null = TrackStyle по умолчанию (как раньше: балласт, 0.85)
var style: TrackStyle

var mesh_node: MeshInstance3D
var sleepers: MultiMeshInstance3D
var ballast: Area3D
var head: StaticBody3D

var _ballast_shapes: Array[CollisionShape3D] = []
var _head_shapes: Array[CollisionShape3D] = []
var _built := false
var _dirty := false
var _last_ms := 0
var _period_ms := 50
var _preview := false


func _init() -> void:
	set_process(false)


## Базовый C_Visual.on_added инстанцирует сцену; у flex сцены нет
func on_added() -> void:
	
	if style == null:
		style = TrackStyle.new()
	rail_surface_index = 1 if style.ballast_enabled else 0
	
	_period_ms = int(Global.settings.flex_rebuild_period * 1000.0)
	instance = _build_instance()
	entity.add_child(instance)
	parts = PartRegistry.build(instance)   # новое
	_collect_meshes()
	_on_instance_ready()   # C_TrackVisual: area_nodes, static_node


## C_Path уже в Entity (а его on_entity_ready еще впереди): отдаем ему высоту поверхности катания
func on_entity_ready() -> void:
	var path := get_comp(C_Path) as C_Path
	if path:
		path.set_head_height(style.head_height())


func _set_overlay(mat: Material) -> void:
	super(mat)
	if sleepers:
		sleepers.material_overlay = mat


# ==========================================
# События
# ==========================================

func on_curve_changed(_d: Dictionary) -> void:
	if not _built:
		_rebuild()
		return
	_dirty = true
	set_process(true)


func on_stretch_started(_d: Dictionary) -> void:
	_preview = true


func on_flex_final(_d: Dictionary) -> void:
	_preview = false
	_rebuild()

## Правка изгиба: пока тянем, меш и коллизии грубее. Финал - on_flex_final
func on_flex_edit_started(_d: Dictionary) -> void:
	_preview = true
	
func _process(_delta: float) -> void:
	if not _dirty:
		set_process(false)
		return
	if Time.get_ticks_msec() - _last_ms >= _period_ms:
		_rebuild()


# ==========================================
# Ноды
# ==========================================

static func _ensure_materials() -> void:
	if _mat_ballast:
		return
	_mat_ballast = StandardMaterial3D.new()
	_mat_ballast.albedo_color = Color(0.42, 0.40, 0.37)
	_mat_ballast.roughness = 1.0
	_mat_rail = StandardMaterial3D.new()
	_mat_rail.albedo_color = Color(0.65, 0.66, 0.70)
	_mat_rail.metallic = 0.5
	_mat_rail.roughness = 0.4
	_mat_sleeper = StandardMaterial3D.new()
	_mat_sleeper.albedo_color = Color(0.30, 0.20, 0.13)
	_mat_sleeper.roughness = 0.9


func _new_shape(size: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = size
	cs.shape = bx
	return cs


func _build_instance() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "FlexTrack"

	mesh_node = MeshInstance3D.new()
	mesh_node.name = "Mesh"
	root.add_child(mesh_node)

	sleepers = MultiMeshInstance3D.new()
	sleepers.name = "Sleepers"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	if style.sleeper_mesh:
		mm.mesh = style.sleeper_mesh
		if style.sleeper_material:
			sleepers.material_override = style.sleeper_material
	else:
		var bm := BoxMesh.new()
		bm.size = style.sleeper_size
		mm.mesh = bm
		sleepers.material_override = style.sleeper_material if style.sleeper_material else _mat_sleeper
	sleepers.multimesh = mm
	root.add_child(sleepers)

	# Слои как у G239: треки = слой 3, видят треки и призраков
	ballast = Area3D.new()
	ballast.name = "Ballast"
	ballast.collision_layer = 1 << 2
	ballast.collision_mask = (1 << 2) | (1 << 10)
	root.add_child(ballast)
	# Заглушка: C_Path генерирует свои коллизии, только если у Ballast/Head нет детей
	var b0 := _new_shape(Vector3(0.01, 0.01, 0.01))
	ballast.add_child(b0)
	_ballast_shapes.append(b0)

	head = StaticBody3D.new()
	head.name = "HeadStaticBody3D"
	head.collision_layer = 1 << 2
	head.collision_mask = (1 << 2) | (1 << 10)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.0
	head.physics_material_override = pm
	root.add_child(head)
	var h0 := _new_shape(Vector3(0.01, 0.01, 0.01))
	head.add_child(h0)
	_head_shapes.append(h0)
	return root


# ==========================================
# Пересборка
# ==========================================

func _rebuild() -> void:
	var path := get_comp(C_Path) as C_Path
	if not path or not path.curve:
		return
	var curve := path.curve
	var L := curve.get_baked_length()
	if L < 0.5:
		return
	_built = true
	_dirty = false
	_last_ms = Time.get_ticks_msec()
	_rebuild_mesh(curve, L)
	_rebuild_sleepers(curve, L)
	_rebuild_collision(curve, L)


## Локальный репер кривой в точке s: right, up, forward (вперед = -Z на прямой)
static func _frame(curve: Curve3D, s: float, L: float) -> Fr:
	var fr := Fr.new()
	fr.p = curve.sample_baked(clampf(s, 0.0, L))
	var a := curve.sample_baked(clampf(s - 0.25, 0.0, L))
	var b := curve.sample_baked(clampf(s + 0.25, 0.0, L))
	var fwd := b - a
	if fwd.length_squared() < 1e-6:
		fwd = Vector3(0, 0, -1)
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	if right.length_squared() < 1e-6:
		right = Vector3.RIGHT
	right = right.normalized()
	fr.f = fwd
	fr.r = right
	fr.u = right.cross(fwd).normalized()
	return fr


func _rebuild_mesh(curve: Curve3D, L: float) -> void:
	var n := maxi(2, ceili(L / (MESH_STEP_PREVIEW if _preview else MESH_STEP)) + 1)
	var fr: Array = []
	for i in n:
		fr.append(_frame(curve, L * i / float(n - 1), L))

	var am := ArrayMesh.new()

	# Балласт (необязательный): поверхность 0
	if style.ballast_enabled and style.ballast_profile.size() >= 2:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(style.ballast_material if style.ballast_material else _mat_ballast)
		var chain: Array = []
		var hw := 0.01
		for p in style.ballast_profile:
			chain.append(p)
			hw = maxf(hw, absf(p.x))
		_sweep(st, fr, chain, L, hw)
		st.commit(am)

	# Рельсы: поверхность rail_surface_index (1 с балластом, 0 без)
	var rst := SurfaceTool.new()
	rst.begin(Mesh.PRIMITIVE_TRIANGLES)
	rst.set_material(style.rail_material if style.rail_material else _mat_rail)
	var base := style.base_height()
	for sx in [-1.0, 1.0]:
		var c: float = sx * style.rail_x
		var chain: Array = []
		for p in style.rail_profile:
			chain.append(Vector2(c + p.x, base + p.y))
		_sweep(rst, fr, chain, L, style.rail_x + style.rail_width())
	rst.commit(am)

	mesh_node.mesh = am


## Протягивает ломаную профиля (слева направо поверх) вдоль реперов. hw - полуширина для UV поперек
func _sweep(st: SurfaceTool, fr: Array, chain: Array, L: float, hw: float) -> void:
	var n := fr.size()
	for j in chain.size() - 1:
		var a: Vector2 = chain[j]
		var b: Vector2 = chain[j + 1]
		var d := b - a
		if d.length_squared() < 1e-8:
			continue
		var nrm := Vector2(-d.y, d.x).normalized()   # наружу
		var ua := (a.x + hw) / (2.0 * hw)
		var ub := (b.x + hw) / (2.0 * hw)
		for i in n - 1:
			var f0: Fr = fr[i]
			var f1: Fr = fr[i + 1]
			var v0 := -L * i / float(n - 1) * UV_V_SCALE
			var v1 := -L * (i + 1) / float(n - 1) * UV_V_SCALE
			var n0 := (f0.r * nrm.x + f0.u * nrm.y).normalized()
			var n1 := (f1.r * nrm.x + f1.u * nrm.y).normalized()
			var p := [
				f0.p + f0.r * a.x + f0.u * a.y,
				f0.p + f0.r * b.x + f0.u * b.y,
				f1.p + f1.r * b.x + f1.u * b.y,
				f1.p + f1.r * a.x + f1.u * a.y]
			var nm := [n0, n0, n1, n1]
			# U вдоль трака, V поперек (шейдер тока едет по U)
			var uv := [Vector2(v0, ua), Vector2(v0, ub), Vector2(v1, ub), Vector2(v1, ua)]
			_quad(st, p, nm, uv)


## Godot: лицевая сторона - по часовой. Порядок вершин выбираем по ожидаемой нормали
func _quad(st: SurfaceTool, p: Array, nm: Array, uv: Array) -> void:
	var geo: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
	var avg: Vector3 = nm[0] + nm[1] + nm[2] + nm[3]
	var idx: Array = [0, 1, 2, 0, 2, 3]
	if geo.dot(avg) > 0.0:
		idx = [0, 2, 1, 0, 3, 2]
	for k in idx:
		st.set_normal(nm[k])
		st.set_uv(uv[k])
		st.add_vertex(p[k])


## Шпалы: целое число с равномерным шагом (шаг чуть подстраивается под длину), каждая в центре своей доли.
## Две доли по half-step на стыке двух траков дают тот же шаг, что и внутри трака.
func _rebuild_sleepers(curve: Curve3D, L: float) -> void:
	var mm := sleepers.multimesh
	var n := maxi(1, roundi(L / style.sleeper_step()))
	var step := L / float(n)
	if mm.instance_count != n:
		mm.instance_count = n
	var y0 := style.sleeper_bottom()
	if style.sleeper_mesh == null:
		y0 += style.sleeper_size.y * 0.5   # BoxMesh центрирован по высоте
	for k in n:
		var f := _frame(curve, (k + 0.5) * step, L)
		var b := Basis(f.r, f.u, f.r.cross(f.u))
		mm.set_instance_transform(k, Transform3D(b, f.p + f.u * y0))


# --- коллизии: пул сегментов, Area3D не трогаем ---

func _rebuild_collision(curve: Curve3D, L: float) -> void:
# торцы короче трака, чтобы стык соседей не давал overlap балласта
	var span := maxf(L - 2.0 * COL_END_INSET, 0.2)
	var cuts := _collision_cuts(curve, L, span)
	var nseg := cuts.size() - 1
	_resize_pool(nseg)
	var base_h := style.base_height()       # основание: балласт + шпалы
	var rail_h := style.rail_height()
	var rail_w := style.rail_width()
	for i in nseg:
		var s0 := cuts[i]
		var s1 := cuts[i + 1]
		var f := _frame(curve, (s0 + s1) * 0.5, L)
		var chord := curve.sample_baked(s0).distance_to(curve.sample_baked(s1)) + COL_OVERLAP
		var b := Basis(f.r, f.u, f.r.cross(f.u))
		var ballast_xf := Transform3D(b, f.p + f.u * (base_h * 0.5))
		var ballast_size := Vector3(style.collision_width, base_h, chord)
		_set_box(_ballast_shapes[i], ballast_size, ballast_xf)
		_set_box(_head_shapes[3 * i], ballast_size, ballast_xf)
		var rail_size := Vector3(rail_w, rail_h, chord)
		var rail_c := f.p + f.u * (base_h + rail_h * 0.5)
		_set_box(_head_shapes[3 * i + 1], rail_size, Transform3D(b, rail_c - f.r * style.rail_x))
		_set_box(_head_shapes[3 * i + 2], rail_size, Transform3D(b, rail_c + f.r * style.rail_x))


#############
## Границы сегментов коллизии: по накопленному углу касательной и по макс. длине
func _collision_cuts(curve: Curve3D, L: float, span: float) -> PackedFloat32Array:
	var gs = Global.settings
	var k := 2.0 if _preview else 1.0
	var deg_max := deg_to_rad(gs.track_ballast_segment.deg_per_segment) * k
	var len_max: float = gs.flex_collision_step * k
	var s_end := COL_END_INSET + span
	var cuts := PackedFloat32Array([COL_END_INSET])
	var seg_start := COL_END_INSET
	var acc := 0.0
	var prev: Vector3 = _frame(curve, seg_start, L).f
	var s := seg_start
	while s < s_end - 0.001:
		s = minf(s + 1.0, s_end)
		var cur: Vector3 = _frame(curve, s, L).f
		acc += prev.angle_to(cur)
		prev = cur
		if acc >= deg_max or s - seg_start >= len_max:
			cuts.append(s)
			seg_start = s
			acc = 0.0
	var last := cuts[cuts.size() - 1]
	if last < s_end - 0.001:
		if cuts.size() > 1 and s_end - last < 2.0:
			cuts[cuts.size() - 1] = s_end   # короткий хвост приклеиваем к предыдущему
		else:
			cuts.append(s_end)
	return cuts

func _resize_pool(nseg: int) -> void:
	while _ballast_shapes.size() < nseg:
		var cs := _new_shape(Vector3.ONE)
		ballast.add_child(cs)
		_ballast_shapes.append(cs)
	while _ballast_shapes.size() > nseg:
		var old: CollisionShape3D = _ballast_shapes.pop_back()
		old.queue_free()
	while _head_shapes.size() < nseg * 3:
		var cs := _new_shape(Vector3.ONE)
		head.add_child(cs)
		_head_shapes.append(cs)
	while _head_shapes.size() > nseg * 3:
		var old2: CollisionShape3D = _head_shapes.pop_back()
		old2.queue_free()


func _set_box(cs: CollisionShape3D, size: Vector3, xf: Transform3D) -> void:
	var bx := cs.shape as BoxShape3D
	if not bx.size.is_equal_approx(size):
		bx.size = size
	cs.transform = xf
