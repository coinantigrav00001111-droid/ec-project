class_name C_DropMarker extends ICapability

#######################
## Способность. Пока на сущности висит C_Drag, рисует Decal-след под ней
## (проекция вниз на стол/трак). Хозяин ноды Decal - этот компонент.
#######################

const PPU := 12.0              # пикселей текстуры на юнит
const RAY_UP := 3.0            # луч стартует выше вагона
const DECAL_DEPTH := 1.1       # толщина объема проекции
const DECAL_TOP := 0.1         # верх объема над точкой попадания (выше - след ляжет на крышу вагона)

var width := 3.4
var length := 12.0

var _decal: Decal
var _tex: ImageTexture


func on_component_added(type: Script) -> void:
	if type == C_Drag:
		_start()


func on_component_removed(type: Script) -> void:
	if type == C_Drag:
		_stop()


func on_removed() -> void:
	_stop()


func _start() -> void:
	if _decal:
		return
	if not _tex:
		_tex = _make_texture(width, length)
	_decal = Decal.new()
	_decal.name = "DropMarker"
	_decal.top_level = true
	_decal.size = Vector3(width, DECAL_DEPTH, length)
	_decal.texture_albedo = _tex
	_decal.texture_emission = _tex          # виден и в тени
	_decal.upper_fade = 0.01
	_decal.lower_fade = 0.3
	_decal.visible = false
	entity.add_child(_decal)
	set_process(true)


func _stop() -> void:
	set_process(false)
	if _decal:
		_decal.queue_free()
		_decal = null


func _init() -> void:
	set_process(false)


func _process(_d: float) -> void:
	if not _decal or not entity.is_inside_tree():
		return

	var from := entity.global_position + Vector3.UP * RAY_UP
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 500.0,
			Global.active_layers(['ground', 'tracks']))
	q.collide_with_areas = true          # балласт - Area3D
	var hit := entity.get_world_3d().direct_space_state.intersect_ray(q)
	_decal.visible = not hit.is_empty()
	if hit.is_empty():
		return

	var fwd := -entity.global_basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		return
	var b := Basis.looking_at(fwd.normalized(), Vector3.UP)
	_decal.global_transform = Transform3D(b, hit.position + Vector3.UP * (DECAL_TOP - DECAL_DEPTH * 0.5))

	var drag := get_comp(C_TrainDraggable) as C_TrainDraggable
	var snapped_ok := drag != null and drag.is_snapped_to_track
	var st: int = Outline.S.GHOST if snapped_ok else Outline.S.HOVER
	_decal.modulate = Outline.STYLE[st].color


## Скругленная рамка + легкая заливка, толщина линии постоянна (SDF)
func _make_texture(w_u: float, l_u: float) -> ImageTexture:
	var w := maxi(8, int(w_u * PPU))
	var l := maxi(8, int(l_u * PPU))
	var img := Image.create(w, l, false, Image.FORMAT_RGBA8)
	var half := Vector2(w, l) * 0.5
	var r := 10.0       # радиус скругления, px
	var t := 3.0        # толщина рамки, px
	for y in l:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5) - half
			var q := p.abs() - (half - Vector2(r, r))
			var d := q.max(Vector2.ZERO).length() + minf(maxf(q.x, q.y), 0.0) - r   # <0 внутри
			var ring := 1.0 - clampf(absf(d + t * 0.5) - t * 0.5 + 0.5, 0.0, 1.0)
			var fill := clampf(-d, 0.0, 1.0) * 0.18
			img.set_pixel(x, y, Color(1, 1, 1, maxf(ring, fill)))
	return ImageTexture.create_from_image(img)
