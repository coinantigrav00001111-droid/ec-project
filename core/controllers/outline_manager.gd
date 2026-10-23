extends Node
## Экранные контуры по состояниям. Автолоад Outline, без class_name.

## Порядок = порядок отрисовки снизу вверх (последний рисуется поверх)
enum S { RESERVE, HOVER, SELECTED, MULTI, GHOST, BLOCKED }

const FIRST_LAYER := 15   # визуальные слои 15..20, по одному на состояние
const SHADER := preload("res://core/visual/materials/shader_outline_screen.gdshader")

## Цвет и толщина (px) каждого состояния. Меняй здесь
const STYLE := {
	S.RESERVE:  {"color": Color("ffb020"), "width": 2.5},
	S.HOVER:    {"color": Color("e8f1ff"), "width": 2.5},
	S.SELECTED: {"color": Color("2f8cff"), "width": 2.5},
	S.MULTI:    {"color": Color("b07cff"), "width": 2.5},
	S.GHOST:    {"color": Color("5ee68a"), "width": 2.5},
	S.BLOCKED:  {"color": Color("ff3b30"), "width": 2.5},
}

## Режимы по уровню качества (Quality): все состояния или только важные для игры (hover, selected, ghost, blocked).
## ESSENTIAL не трогает ghost и blocked: без них не видно, можно ли ставить объект
enum Mode { ALL, ESSENTIAL }

## Общий выключатель. Observe выключает контуры целиком: каждый активный канал это полноэкранный SubViewport
var enabled := true:
	set(v):
		enabled = v
		_refresh_all()

## Задает GFX из QualityPreset.outlines_all
var mode := Mode.ALL:
	set(v):
		mode = v
		_refresh_all()

class Channel extends RefCounted:
	var state := 0
	var sub: SubViewport
	var cam: Camera3D
	var rect: ColorRect
	var mat: ShaderMaterial
	var owners := {}   # instance_id -> true

var _ch: Array[Channel] = []


func _ready() -> void:
	process_priority = 100
	var cl := CanvasLayer.new()
	cl.layer = -1   # поверх 3D, под UI
	add_child(cl)

	for s in S.values():
		var c := Channel.new()
		c.state = s
		c.sub = SubViewport.new()
		c.sub.size = Vector2i(2, 2)   # реальный размер ставим при активации
		c.sub.transparent_bg = true
		c.sub.msaa_3d = Viewport.MSAA_DISABLED
		c.sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(c.sub)

		c.cam = Camera3D.new()
		c.cam.cull_mask = 1 << (layer_of(s) - 1)
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR   # небо не должно закрасить альфу
		c.cam.environment = env
		c.sub.add_child(c.cam)

		c.mat = ShaderMaterial.new()
		c.mat.shader = SHADER
		c.mat.set_shader_parameter("mask_tex", c.sub.get_texture())
		c.mat.set_shader_parameter("outline_color", STYLE[s].color)
		c.mat.set_shader_parameter("width_px", STYLE[s].width)

		c.rect = ColorRect.new()
		c.rect.material = c.mat
		c.rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.rect.visible = false
		cl.add_child(c.rect)   # порядок детей = порядок enum
		_ch.append(c)


func layer_of(state: int) -> int:
	return FIRST_LAYER + state


## state = -1: контура нет. Вызывает C_Visual
func set_owner_state(owner_obj: Object, state: int) -> void:
	var id := owner_obj.get_instance_id()
	for c in _ch:
		c.owners.erase(id)
	if state >= 0:
		_ch[state].owners[id] = true
	for c in _ch:
		_refresh(c)


func _allowed(c: Channel) -> bool:
	if not enabled:
		return false
	return mode == Mode.ALL or c.state in [S.HOVER, S.SELECTED, S.GHOST, S.BLOCKED]


func _refresh_all() -> void:
	for c in _ch:
		_refresh(c)


func _refresh(c: Channel) -> void:
	var active := not c.owners.is_empty() and _allowed(c)
	c.rect.visible = active
	c.sub.render_target_update_mode = \
		SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if not active:
		c.sub.size = Vector2i(2, 2)   # не держим полноэкранную текстуру без дела


func _process(_d: float) -> void:
	var main := get_viewport().get_camera_3d()
	if not main:
		return
	var size := Vector2i(get_viewport().get_visible_rect().size)
	for c in _ch:
		if c.owners.is_empty() or not _allowed(c):
			continue
		for id in c.owners.keys():
			if not is_instance_id_valid(id):
				c.owners.erase(id)
		if c.owners.is_empty():
			_refresh(c)
			continue
		if c.sub.size != size:
			c.sub.size = size
		var cam := c.cam
		cam.global_transform = main.global_transform
		cam.projection = main.projection
		cam.fov = main.fov
		cam.size = main.size
		cam.near = main.near
		cam.far = main.far
		cam.keep_aspect = main.keep_aspect
		cam.h_offset = main.h_offset
		cam.v_offset = main.v_offset
