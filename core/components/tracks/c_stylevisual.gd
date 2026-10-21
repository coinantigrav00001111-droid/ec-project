class_name C_StyleVisual extends C_TrackVisual

# XX claude-terra (новый файл)
###################################
## Визуал жёсткого трака (прямая/дуга/пандус) из TrackStyle. Сцены из Blender нет: ноды
## строятся в коде один раз (форма не меняется после создания), тем же каркасом, что у
## C_FlexVisual (TrackMeshBuilder.build_skeleton) — Mesh, Sleepers, Ballast Area3D,
## HeadStaticBody3D, — поэтому C_Path / C_Blockable / C_Socket работают по тем же правилам.
###################################
## Создаётся через StyleVisualSetting, который добавляет C_Path ДО этого компонента:
## на on_entity_ready() curve/path_node у C_Path уже готовы (генерируются в его собственном
## on_entity_ready, которая по порядку детей идёт раньше). Высоту поверхности катания
## C_Path.head_height() получает отсюда же (style.head_height()), раньше, чем успевает
## закэшировать запасное значение (это безопасно: внутренняя проверка в C_Path сейчас
## не имеет побочных эффектов).
## В отличие от flex: форма строится один раз, без пула/пересборки и без _process.

## Задаёт StyleVisualSetting. null = TrackStyle по умолчанию (балласт, 0.85)
var style: TrackStyle

var mesh_node: MeshInstance3D
var sleepers: MultiMeshInstance3D
var ballast: Area3D
var head: StaticBody3D


## Базовый C_Visual.on_added инстанцирует сцену; здесь сцены нет, каркас строится кодом
func on_added() -> void:
	if style == null:
		style = TrackStyle.new()
	rail_surface_index = 1 if style.ballast_enabled else 0

	var sk := TrackMeshBuilder.build_skeleton(style, "StyleTrack")
	mesh_node = sk.mesh_node
	sleepers = sk.sleepers
	ballast = sk.ballast
	head = sk.head
	instance = sk.root

	entity.add_child(instance)
	parts = PartRegistry.build(instance)
	_collect_meshes()
	_on_instance_ready()   # C_TrackVisual: area_nodes, static_node


## C_Path (StyleVisualSetting создаёт его первым) уже сгенерировал кривую к этому моменту
func on_entity_ready() -> void:
	var path := get_comp(C_Path) as C_Path
	if not path or not path.curve:
		return
	path.set_head_height(style.head_height())

	var curve := path.curve
	var L := curve.get_baked_length()
	if L < 0.01:
		return

	mesh_node.mesh = TrackMeshBuilder.build_mesh(style, curve, L, false)
	TrackMeshBuilder.place_sleepers(sleepers.multimesh, style, curve, L)
	_build_collision(curve, L)


func _set_overlay(mat: Material) -> void:
	super(mat)
	if sleepers:
		sleepers.material_overlay = mat


## Форма не меняется после создания: заглушки убираем и строим боксы один раз
func _build_collision(curve: Curve3D, L: float) -> void:
	ballast.get_child(0).queue_free()   # заглушка из build_skeleton
	head.get_child(0).queue_free()

	var cuts := TrackMeshBuilder.collision_cuts(curve, L, false)
	for i in cuts.size() - 1:
		var bx := TrackMeshBuilder.segment_boxes(style, curve, L, cuts[i], cuts[i + 1])
		var cb := TrackMeshBuilder.new_shape(bx.ballast_size)
		cb.transform = bx.ballast_xf
		ballast.add_child(cb)

		var hb := TrackMeshBuilder.new_shape(bx.ballast_size)
		hb.transform = bx.ballast_xf
		head.add_child(hb)
		var hl := TrackMeshBuilder.new_shape(bx.rail_size)
		hl.transform = bx.rail_l_xf
		head.add_child(hl)
		var hr := TrackMeshBuilder.new_shape(bx.rail_size)
		hr.transform = bx.rail_r_xf
		head.add_child(hr)
