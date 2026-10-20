class_name GraphicsPreset extends Resource

########################
## Look: стиль картинки (TDD §14.3). Три независимые оси графики: Look, Time (S4), Quality (S5).
########################
## Здесь только то, что относится к СТИЛЮ. Угол и цвет солнца задает Time, тени и AA задает Quality.
## Встроенные пресеты (builtin) строятся кодом, .tres в res://data/graphics/looks/ их переопределяют по id.
## F10 в debug сохраняет встроенные в .tres (существующие файлы не перезаписываются).

@export var id: StringName
@export var title: String

@export_category("Tonemap & Color")
@export var tonemap: Environment.ToneMapper = Environment.TONE_MAPPER_FILMIC
@export var tonemap_exposure := 1.0
@export var tonemap_white := 6.0
@export var brightness := 1.0
@export var contrast := 1.0
@export var saturation := 1.0

@export_category("Glow")
@export var glow_enabled := false
@export var glow_intensity := 0.4
@export var glow_bloom := 0.0

@export_category("Ambient")
## Фон за пределами комнаты и цвет окружающего света (источник ambient = Color)
@export var background_color := Color(0.8, 0.8, 0.82)
@export var ambient_color := Color(0.7, 0.7, 0.75)
@export var ambient_energy := 1.0

@export_category("Fog")
@export var fog_enabled := false
@export var fog_color := Color(0.8, 0.8, 0.85)
@export var fog_density := 0.0

@export_category("Ambient occlusion")
@export var ssao_enabled := false
@export var ssao_radius := 1.0
@export var ssao_intensity := 2.0
@export var ssao_power := 1.5
@export var ssao_light_affect := 0.0
## Godot 4.8: аппроксимация переотражений в AO (меньше грязных углов)
@export var ao_multibounce := false

@export_category("Sun")
@export var sun_energy_mul := 1.0
@export var sun_shadow_blur := 1.0
## Godot 4.8: screen space contact shadows (Environment + DirectionalLight3D)
@export var contact_shadows := false

@export_category("Reflections / Lamp")
@export var probe_intensity := 1.0
## Лампа над столом. 0 = выкл
@export var lamp_energy := 0.0

@export_category("Miniature (S8, пока не применяется)")
@export var tilt_shift := 0.0
@export var vignette := 0.0


static func builtin_ids() -> Array:
	return [&"toy", &"workshop", &"clean"]


static func builtin(_id: StringName) -> GraphicsPreset:
	match _id:
		&"toy":
			# LEGO-подобный: яркий, насыщенный, мягкие тени, пластик
			return _make(_id, "Toy", {
				"tonemap_exposure": 1.0, "tonemap_white": 6.0,
				"brightness": 1.02, "contrast": 1.08, "saturation": 1.28,
				"glow_enabled": true, "glow_intensity": 0.35, "glow_bloom": 0.0,
				"background_color": Color(0.78, 0.84, 0.92),
				"ambient_color": Color(0.66, 0.72, 0.84), "ambient_energy": 1.0,
				"ssao_enabled": true, "ssao_radius": 0.9, "ssao_intensity": 2.6,
				"ssao_power": 1.6, "ssao_light_affect": 0.15, "ao_multibounce": true,
				"sun_energy_mul": 1.0, "sun_shadow_blur": 1.6, "contact_shadows": true,
				"probe_intensity": 1.0, "lamp_energy": 0.0,
				"tilt_shift": 0.6, "vignette": 0.15,
			})
		&"workshop":
			# Вечер в мастерской: тёмное окружение, лампа над столом (до S4 лампа временная)
			return _make(_id, "Workshop", {
				"tonemap_exposure": 0.95, "tonemap_white": 6.0,
				"brightness": 0.92, "contrast": 1.15, "saturation": 1.1,
				"glow_enabled": true, "glow_intensity": 0.7, "glow_bloom": 0.05,
				"background_color": Color(0.10, 0.09, 0.12),
				"ambient_color": Color(0.30, 0.26, 0.36), "ambient_energy": 0.45,
				"ssao_enabled": true, "ssao_radius": 0.9, "ssao_intensity": 2.8,
				"ssao_power": 1.6, "ssao_light_affect": 0.1, "ao_multibounce": true,
				"sun_energy_mul": 0.25, "sun_shadow_blur": 1.8, "contact_shadows": true,
				"probe_intensity": 0.6, "lamp_energy": 6.0,
				"tilt_shift": 0.5, "vignette": 0.35,
			})
		&"clean":
			# Нейтральный и быстрый: без AO и контактных теней
			return _make(_id, "Clean", {
				"background_color": Color(0.85, 0.85, 0.87),
				"ambient_color": Color(0.80, 0.80, 0.82), "ambient_energy": 1.0,
				"probe_intensity": 0.3,
			})
	return null


static func _make(_id: StringName, _title: String, d: Dictionary) -> GraphicsPreset:
	var p := GraphicsPreset.new()
	p.id = _id
	p.title = _title
	for k in d:
		p.set(k, d[k])
	return p
