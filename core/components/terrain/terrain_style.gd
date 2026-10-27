class_name TerrainStyle extends Resource

# XX claude-terra (новый файл)
########################
## Стиль листа пенопласта: материалы стадий (13.1.3, T7). Косметика, на геометрию и физику не влияет.
########################
## Стадии: C_TerrainLayer.FoamStage { RAW, PLASTER, PAINT, GRASS }.
## У каждой стадии два материала: верх (горизонтальные грани) и бок (стенки, низ).
## Массивы top_materials / side_materials индексируются стадией; пустой слот (null или массив короче)
## берется из встроенных: розовый пенопласт, белая шпаклевка, краска (земля), трава сверху и земля по бокам.
## Свои материалы (текстуры) кладутся в слоты .tres стиля, код менять не нужно.
## Все встроенные материалы с триплоскостным UV: у меша листа UV нет.

@export var id: StringName = &"default"
@export var top_materials: Array[Material] = []
@export var side_materials: Array[Material] = []

static var _cache: Dictionary = {}   # "top0" -> Material


func get_top(stage: int) -> Material:
	if stage >= 0 and stage < top_materials.size() and top_materials[stage] != null:
		return top_materials[stage]
	return _builtin(true, stage)


func get_side(stage: int) -> Material:
	if stage >= 0 and stage < side_materials.size() and side_materials[stage] != null:
		return side_materials[stage]
	return _builtin(false, stage)


static func _builtin(top: bool, stage: int) -> Material:
	var key := "%s%d" % ["top" if top else "side", stage]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	match stage:
		0:   # RAW: розовый пенопласт
			m.albedo_color = Color(0.93, 0.62, 0.72)
			m.albedo_texture = _noise(0.9, 0.0, 0.35)
			m.uv1_scale = Vector3.ONE * 0.25
		1:   # PLASTER: шпаклевка
			m.albedo_color = Color(0.86, 0.85, 0.80)
			m.albedo_texture = _noise(0.5, 0.0, 0.45)
			m.uv1_scale = Vector3.ONE * 0.15
		2:   # PAINT: грунт-краска цвета земли
			m.albedo_color = Color(0.40, 0.31, 0.22)
			m.albedo_texture = _noise(0.4, 0.0, 0.5)
			m.uv1_scale = Vector3.ONE * 0.2
		_:   # GRASS: трава сверху, земля по бокам
			if top:
				m.albedo_color = Color(0.30, 0.52, 0.20)
				m.albedo_texture = _noise(1.4, 0.0, 0.7)
				m.uv1_scale = Vector3.ONE * 0.3
			else:
				m.albedo_color = Color(0.36, 0.27, 0.18)
				m.albedo_texture = _noise(0.5, 0.0, 0.5)
				m.uv1_scale = Vector3.ONE * 0.2
	_cache[key] = m
	return m


## Мелкая серая текстура-шум: умножается на albedo_color, дает неровность без файлов
static func _noise(freq: float, _lo: float, hi: float) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq * 0.08
	var t := NoiseTexture2D.new()
	t.width = 128
	t.height = 128
	t.seamless = true
	t.noise = n
	var g := Gradient.new()
	g.set_color(0, Color(1.0 - hi, 1.0 - hi, 1.0 - hi))
	g.set_color(1, Color(1.0, 1.0, 1.0))
	t.color_ramp = g
	return t
