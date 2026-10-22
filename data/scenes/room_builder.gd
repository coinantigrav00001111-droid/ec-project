class_name RoomBuilder extends Node3D

########################
## RoomRoot. Строит комнату из RoomConfig под собой. НЕ в EntitiesRoot и не сохраняется (TDD §14.1).
########################
## S2: greybox из коробок (пол, стены с проёмами, потолок, мебель-заглушки) + подмакетник.
## Подмакетник (Table): верх на слое ground, ножки на room. Он не скрывается кнопкой «Комната».
## Всё остальное (Room) на слое room (физика) и на visual layer Global.ROOM_VISUAL_LAYER.
## Комната слушает ObserveController.observe_action (категория room), про поезда не знает ничего.

## ⚡ Комнату показали или спрятали (CameraBounds выключает ограничение)
signal room_visible_changed(on: bool)

@export var config: RoomConfig
## Стены и потолок не отбрасывают тень: иначе низкое солнце затемнит стол. Окно и рама в S4
@export var walls_cast_shadow := false
## В режиме Observe стены отбрасывают тень: на столе виден рисунок окна. В остальных режимах свет ровный
@export var window_shadows_in_observe := true
## Временный свет для проверки масштаба. Включать, только если в главной сцене нет своего солнца
@export var temp_light := false

var visuals: Node3D    # пол, стены, потолок, мебель
var ceiling: Node3D
var table: Node3D

var _mats := {}
var _walls: Array[MeshInstance3D] = []

const COL_FLOOR := Color(0.42, 0.40, 0.38)
const COL_WALL := Color(0.80, 0.79, 0.76)
const COL_CEILING := Color(0.90, 0.90, 0.88)
const COL_TABLE := Color(0.62, 0.50, 0.38)
const COL_TABLE_LEG := Color(0.45, 0.36, 0.28)

## Мебель-заглушки. size: X, Y(высота), Z. xz: центр на полу. По §14.4
const PROPS := [
	{"name": "Bed", "size": Vector3(90, 45, 200), "xz": Vector2(-195, -90), "color": Color(0.55, 0.62, 0.78)},
	{"name": "Desk", "size": Vector3(60, 75, 120), "xz": Vector2(210, 40), "color": Color(0.72, 0.60, 0.45)},
	{"name": "Chair", "size": Vector3(40, 45, 40), "xz": Vector2(160, 40), "color": Color(0.50, 0.50, 0.55)},
	{"name": "Wardrobe", "size": Vector3(100, 200, 50), "xz": Vector2(-190, 165), "color": Color(0.66, 0.55, 0.42)},
	{"name": "Shelf", "size": Vector3(80, 180, 30), "xz": Vector2(200, -175), "color": Color(0.70, 0.58, 0.40)},
	{"name": "Rug", "size": Vector3(160, 1, 110), "xz": Vector2(0, 125), "color": Color(0.78, 0.45, 0.40), "collide": false},
]


func _ready() -> void:
	if config == null:
		config = RoomConfig.new()
	add_to_group(&"room_root")
	build()
	_connect_observe()


## Карточки категории Room (S1). Ищем по группе: ObserveController живёт в сцене UI, а %-имена видны только внутри своей сцены
func _connect_observe() -> void:
	await get_tree().process_frame   # контроллер встаёт в группу в своём _ready
	var oc = get_tree().get_first_node_in_group(&"observe_controller")
	if oc:
		oc.observe_action.connect(_on_observe_action)
		oc.observe_entered.connect(func(): set_walls_cast_shadow(window_shadows_in_observe))
		oc.observe_exited.connect(func(): set_walls_cast_shadow(walls_cast_shadow))
	else:
		push_warning("RoomBuilder: ObserveController не найден, кнопки категории Room не работают")


## Пересобрать комнату (после смены config)
func build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_mats.clear()
	_walls.clear()
	ceiling = null

	_build_table()

	if config.scene:
		visuals = config.scene.instantiate() as Node3D
		visuals.name = "Room"
		add_child(visuals)
	else:
		visuals = Node3D.new()
		visuals.name = "Room"
		add_child(visuals)
		_build_greybox()

	if temp_light:
		var l := DirectionalLight3D.new()
		l.name = "TempSun"
		l.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
		l.shadow_enabled = true
		l.directional_shadow_max_distance = 300.0
		add_child(l)


func get_bounds() -> AABB:
	return config.bounds


func set_room_visible(on: bool) -> void:
	if visuals:
		visuals.visible = on
	room_visible_changed.emit(on)


## Тень от стен (рисунок окна на столе). Потолок и небо в окне тень не отбрасывают никогда
func set_walls_cast_shadow(on: bool) -> void:
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for m in _walls:
		m.cast_shadow = mode


func set_ceiling_visible(on: bool) -> void:
	if ceiling:
		ceiling.visible = on


## ⚡Сигнал из ObserveController
func _on_observe_action(_cat: StringName, _id: StringName, _pressed: bool) -> void:
	if _cat != &'room':
		return
	match _id:
		&'room_visible':
			set_room_visible(_pressed)
		&'ceiling':
			set_ceiling_visible(_pressed)


# ==========================================
# Подмакетник
# ==========================================

func _build_table() -> void:
	var c := config
	table = Node3D.new()
	table.name = "Table"
	add_child(table)

	var th := c.table_top_thickness
	# Верх стола = ground (слой 1): по нему бьют лучи тулов, underground_depth и опоры
	_box(table, "TableTop", Vector3(c.table_top.x, th, c.table_top.y), Vector3(0.0, -th * 0.5, 0.0),
			COL_TABLE, Global.active_layers(['ground']), 1, true)

	var leg_h := -c.floor_y - th
	if leg_h <= 0.0:
		return
	var lx := c.table_top.x * 0.5 - c.table_leg * 0.5 - 3.0
	var lz := c.table_top.y * 0.5 - c.table_leg * 0.5 - 3.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(table, "Leg", Vector3(c.table_leg, leg_h, c.table_leg),
					Vector3(sx * lx, c.floor_y + leg_h * 0.5, sz * lz),
					COL_TABLE_LEG, Global.active_layers(['room']), 1, true)


# ==========================================
# Greybox
# ==========================================

func _build_greybox() -> void:
	var c := config
	var t := c.wall_thickness
	var fy := c.floor_y
	var room_layer := Global.active_layers(['room'])
	var vis := _vis_layer()

	_box(visuals, "Floor", Vector3(c.size.x + 2.0 * t, t, c.size.z + 2.0 * t), Vector3(0.0, fy - t * 0.5, 0.0),
			COL_FLOOR, room_layer, vis, true)

	_wall_z(-1.0, c.window)   # север: окно
	_wall_z(1.0, c.door)      # юг: дверь
	_wall_x(-1.0)
	_wall_x(1.0)
	_build_window_frame()
	_build_sky_card()

	# Потолок: отдельной нодой, по умолчанию скрыт, без коллизии
	ceiling = Node3D.new()
	ceiling.name = "Ceiling"
	visuals.add_child(ceiling)
	_box(ceiling, "CeilingSlab", Vector3(c.size.x + 2.0 * t, t, c.size.z + 2.0 * t),
			Vector3(0.0, fy + c.size.y + t * 0.5, 0.0), COL_CEILING, 0, vis, false)
	ceiling.visible = false

	for p in PROPS:
		var sz: Vector3 = p.size
		var xz: Vector2 = p.xz
		var collide: bool = p.get("collide", true)
		_box(visuals, p.name, sz, Vector3(xz.x, fy + sz.y * 0.5, xz.y), p.color,
				room_layer if collide else 0, vis, true)


## Стена вдоль X на z = sgn * (hz + t/2) с необязательным проёмом {x, w, sill, h}
func _wall_z(sgn: float, op: Dictionary) -> void:
	var c := config
	var hx := c.size.x * 0.5
	var cz := sgn * (c.size.z * 0.5 + c.wall_thickness * 0.5)
	var x0 := -hx - c.wall_thickness
	var x1 := hx + c.wall_thickness
	var y0 := c.floor_y
	var y1 := c.floor_y + c.size.y
	var nm := "WallS" if sgn > 0.0 else "WallN"
	if op.is_empty():
		_slab(nm, x0, x1, y0, y1, cz)
		return
	var l: float = op.x - op.w * 0.5
	var r: float = op.x + op.w * 0.5
	var s0: float = y0 + op.sill
	var s1: float = s0 + op.h
	if op.sill > 0.0:
		_slab(nm + "_Below", x0, x1, y0, s0, cz)
	if s1 < y1:
		_slab(nm + "_Above", x0, x1, s1, y1, cz)
	_slab(nm + "_Left", x0, l, s0, s1, cz)
	_slab(nm + "_Right", r, x1, s0, s1, cz)


## Стена вдоль Z (между северной и южной, углы принадлежат им)
func _wall_x(sgn: float) -> void:
	var c := config
	var cx := sgn * (c.size.x * 0.5 + c.wall_thickness * 0.5)
	_walls.append(_box(visuals, "WallE" if sgn > 0.0 else "WallW",
			Vector3(c.wall_thickness, c.size.y, c.size.z), Vector3(cx, c.floor_y + c.size.y * 0.5, 0.0),
			COL_WALL, Global.active_layers(['room']), _vis_layer(), walls_cast_shadow))


## Кусок стены между x0..x1 и y0..y1 на z = cz
func _slab(nm: String, x0: float, x1: float, y0: float, y1: float, cz: float) -> void:
	if x1 - x0 < 0.01 or y1 - y0 < 0.01:
		return
	_walls.append(_box(visuals, nm, Vector3(x1 - x0, y1 - y0, config.wall_thickness),
			Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, cz), COL_WALL,
			Global.active_layers(['room']), _vis_layer(), walls_cast_shadow))


# ==========================================
# Окно и небо
# ==========================================

## Рама с переплётом: отбрасывает тень на стол (в Observe)
func _build_window_frame() -> void:
	var c := config
	if c.window.is_empty():
		return
	var cz := -(c.size.z * 0.5 + c.wall_thickness * 0.5)
	var ox: float = c.window.x
	var ww: float = c.window.w
	var wh: float = c.window.h
	var s0: float = c.floor_y + c.window.sill
	var fb := 4.0
	var vis := _vis_layer()
	var col := Color(0.93, 0.93, 0.90)
	_box(visuals, "FrameTop", Vector3(ww, fb, 3.0), Vector3(ox, s0 + wh - fb * 0.5, cz), col, 0, vis, true)
	_box(visuals, "FrameBottom", Vector3(ww, fb, 3.0), Vector3(ox, s0 + fb * 0.5, cz), col, 0, vis, true)
	_box(visuals, "FrameLeft", Vector3(fb, wh, 3.0), Vector3(ox - ww * 0.5 + fb * 0.5, s0 + wh * 0.5, cz), col, 0, vis, true)
	_box(visuals, "FrameRight", Vector3(fb, wh, 3.0), Vector3(ox + ww * 0.5 - fb * 0.5, s0 + wh * 0.5, cz), col, 0, vis, true)
	_box(visuals, "MullionV", Vector3(3.0, wh, 2.0), Vector3(ox, s0 + wh * 0.5, cz), col, 0, vis, true)
	_box(visuals, "MullionH", Vector3(ww, 3.0, 2.0), Vector3(ox, s0 + wh * 0.55, cz), col, 0, vis, true)


## «Небо» за окном: плоскость с вертикальным градиентом, без освещения. Цвета меняет GFX (группа gfx_sky)
func _build_sky_card() -> void:
	var c := config
	if c.window.is_empty():
		return
	var g := Gradient.new()
	g.set_color(0, Color(0.45, 0.68, 0.95))
	g.set_color(1, Color(0.82, 0.92, 1.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 8
	tex.height = 128
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	var q := QuadMesh.new()
	q.size = Vector2(700.0, 350.0)
	var mi := MeshInstance3D.new()
	mi.name = "SkyCard"
	mi.mesh = q
	mi.material_override = m
	mi.layers = _vis_layer()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(c.window.x, c.floor_y + c.size.y * 0.35, -(c.size.z * 0.5) - 150.0)
	visuals.add_child(mi)
	mi.add_to_group(&"gfx_sky")


# ==========================================
# Хелперы
# ==========================================

func _vis_layer() -> int:
	return 1 << (Global.ROOM_VISUAL_LAYER - 1)


func _mat(color: Color) -> StandardMaterial3D:
	if not _mats.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.9
		_mats[color] = m
	return _mats[color]


## Коробка: меш + (если body_layers != 0) StaticBody3D на этих слоях. vis_layers: visual layers меша
func _box(parent: Node, nm: String, size: Vector3, center: Vector3, color: Color,
		body_layers: int, vis_layers: int, shadow: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color)
	mi.layers = vis_layers
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if body_layers == 0:
		mi.name = nm
		mi.position = center
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.name = nm
	body.position = center
	body.collision_layer = body_layers
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	mi.name = "Mesh"
	body.add_child(mi)
	parent.add_child(body)
	return mi
