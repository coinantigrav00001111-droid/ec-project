extends Node
# class_name не задаём: это синглтон GFX (autoload)

###########################
##💡 GFX - сервис графики (autoload)
############################
## Три независимые оси: Look (стиль, S3), Time (время суток, S4), Quality (стоимость, S5).
## Итоговая картинка = Look (база) * Time (модификатор). Quality режет дорогое сверху (S5).
## Хранит состояние и применяет его к нодам окружения. Ноды находит по группам:
##   gfx_env (WorldEnvironment), gfx_sun (DirectionalLight3D), gfx_lamp (SpotLight3D),
##   gfx_probe (ReflectionProbe), gfx_sky (небо в окне, создает RoomBuilder).
## Их создает EnvironmentRoot, либо вы сами добавляете свои ноды в эти группы.
##
## Карточки Observe (категории look и light) приходят сигналом ObserveController.observe_action.
## Числовые параметры меняются плавным твином, дискретные (вкл/выкл эффектов) переключаются на краях перехода.

signal look_changed(id: StringName)
## ⚡Здания и фары подписываются на него, чтобы включаться ночью
signal time_of_day_changed(id: StringName)
## ⚡Контуры, tilt-shift и комната (LOD) подстраиваются под tier
signal quality_changed(id: StringName)
signal lamp_changed(on: bool)

const LOOKS_DIR := "res://data/graphics/looks/"
const TIMES_DIR := "res://data/graphics/time/"
const QUALITY_DIR := "res://data/graphics/quality/"
## Настройки игрока (не сейв): tier качества и последние Look и Time
const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_LOOK := &"toy"
const DEFAULT_TIME := &"day"
const DEFAULT_TRANSITION := 0.5

var state := {"look": DEFAULT_LOOK, "time": DEFAULT_TIME, "quality": &"medium"}
## id -> GraphicsPreset
var looks := {}
## id -> TimeOfDayPreset
var times := {}
## id -> QualityPreset
var qualities := {}

var _world_env: WorldEnvironment
var _env: Environment
var _sun: DirectionalLight3D
var _lamp: SpotLight3D
var _probe: ReflectionProbe
var _sky: MeshInstance3D
var _oc: Node   # ObserveController
var _sun_base_energy := 1.0

## Ручной переключатель лампы: -1 авто (Look / Time), 0 выкл, 1 вкл. Сбрасывается при смене Look или Time
var _lamp_override := -1
var _lamp_is_on := false

var _p_ao_multibounce: StringName = &""
var _p_contact_env: StringName = &""
var _p_contact_sun: StringName = &""

var _tween: Tween


func _ready() -> void:
	_load_presets()
	_load_settings()
	# EnvironmentRoot, RoomBuilder и ObserveController встают в группы в своих _ready
	await get_tree().process_frame
	if _resolve():
		_discover_features()
		_apply_quality_settings()
		_apply_all(0.0)
	_connect_observe()


func _unhandled_input(event: InputEvent) -> void:
	# F10 (debug): сохранить встроенные Look и Time в .tres для правки
	if Global.debug_mode and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F10:
		save_builtin_presets()


# ==========================================
# ПУБЛИЧНЫЙ API
# ==========================================

## Применить Look. duration = 0: мгновенно
func apply_look(id: StringName, duration := DEFAULT_TRANSITION) -> void:
	if not looks.has(id):
		push_warning("GFX: нет пресета Look '%s'" % id)
		return
	state.look = id
	_lamp_override = -1
	_apply_all(duration)
	_save_settings()
	look_changed.emit(id)


## Применить время суток
func apply_time(id: StringName, duration := DEFAULT_TRANSITION) -> void:
	if not times.has(id):
		push_warning("GFX: нет пресета Time '%s'" % id)
		return
	state.time = id
	_lamp_override = -1
	_apply_all(duration)
	_save_settings()
	time_of_day_changed.emit(id)


## Применить уровень качества (low / medium / high)
func apply_quality(id: StringName, duration := 0.3) -> void:
	if not qualities.has(id):
		push_warning("GFX: нет пресета Quality '%s'" % id)
		return
	state.quality = id
	_apply_quality_settings()
	_apply_all(duration)
	_save_settings()
	quality_changed.emit(id)


func get_quality() -> QualityPreset:
	return qualities.get(state.quality)


## Ручное включение лампы над столом
func set_lamp(on: bool, duration := 0.3) -> void:
	_lamp_override = 1 if on else 0
	_apply_all(duration)


func is_lamp_on() -> bool:
	return _lamp_is_on


func get_state() -> Dictionary:
	return state.duplicate()


## Для SavedGame / настроек (S5)
func set_state(d: Dictionary) -> void:
	if d.has("look") and looks.has(StringName(d.look)):
		state.look = StringName(d.look)
	if d.has("time") and times.has(StringName(d.time)):
		state.time = StringName(d.time)
	if d.has("quality") and qualities.has(StringName(d.quality)):
		state.quality = StringName(d.quality)
		_apply_quality_settings()
	_lamp_override = -1
	_apply_all(0.0)


## Сохраняет встроенные Look и Time в .tres, существующие файлы не трогает
func save_builtin_presets() -> void:
	_save_builtin(LOOKS_DIR, GraphicsPreset.builtin_ids(), func(id): return GraphicsPreset.builtin(id))
	_save_builtin(TIMES_DIR, TimeOfDayPreset.builtin_ids(), func(id): return TimeOfDayPreset.builtin(id))
	_save_builtin(QUALITY_DIR, QualityPreset.builtin_ids(), func(id): return QualityPreset.builtin(id))


## Диагностика Godot 4.8: печатает всё, что относится к multi-bounce AO и contact shadows.
func dump_props() -> void:
	var kw := ["contact", "bounce", "multi"]
	print("[GFX] --- свойства классов ---")
	for cls in ["Environment", "WorldEnvironment", "Light3D", "DirectionalLight3D", "CameraAttributes",
			"CameraAttributesPractical", "CameraAttributesPhysical", "Camera3D", "Viewport", "SubViewport"]:
		for pr in ClassDB.class_get_property_list(cls, true):
			if _has_kw(String(pr.name), kw):
				print("    ", cls, ".", pr.name, " : ", type_string(pr.type))
	print("[GFX] --- настройки проекта ---")
	for pr in ProjectSettings.get_property_list():
		var n := String(pr.name)
		if n.to_lower().contains("ssao") or _has_kw(n, kw):
			print("    ", n, " = ", ProjectSettings.get_setting(n))
	print("[GFX] --- методы RenderingServer ---")
	for m in ClassDB.class_get_method_list("RenderingServer", true):
		var n := String(m.name)
		if n.to_lower().contains("ssao") or _has_kw(n, kw):
			var args: Array = []
			for a in m.args:
				args.append(String(a.name))
			print("    ", n, "(", ", ".join(args), ")")


# ==========================================
# ПРИМЕНЕНИЕ
# ==========================================

## Собирает итог из state (Look + Time) и применяет его
func _apply_all(duration: float) -> void:
	var look: GraphicsPreset = looks.get(state.look)
	var tod: TimeOfDayPreset = times.get(state.time)
	var q: QualityPreset = qualities.get(state.quality)
	if look == null or tod == null or q == null:
		return
	if _env == null and not _resolve():
		return
	_sky = get_tree().get_first_node_in_group(&"gfx_sky") as MeshInstance3D   # комнату могли пересобрать

	if _tween:
		_tween.kill()
		_tween = null
	if duration > 0.0:
		_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var later: Array[Callable] = []   # что выключаем в конце перехода

	# --- Environment: Look * Time ---
	var e := _env
	e.tonemap_mode = look.tonemap
	e.adjustment_enabled = true
	e.background_mode = Environment.BG_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_flag(e, &"glow_enabled", look.glow_enabled, later)
	_flag(e, &"fog_enabled", look.fog_enabled, later)
	_flag(e, &"ssao_enabled", look.ssao_enabled and q.ssao, later)
	_flag(e, &"ssil_enabled", look.ssil and q.ssil, later)
	_to(e, &"tonemap_exposure", look.tonemap_exposure, duration)
	_to(e, &"tonemap_white", look.tonemap_white, duration)
	_to(e, &"adjustment_brightness", look.brightness, duration)
	_to(e, &"adjustment_contrast", look.contrast, duration)
	_to(e, &"adjustment_saturation", look.saturation, duration)
	_to(e, &"glow_intensity", look.glow_intensity, duration)
	_to(e, &"glow_bloom", look.glow_bloom, duration)
	_to(e, &"background_color", look.background_color * tod.background_tint, duration)
	_to(e, &"ambient_light_color", look.ambient_color * tod.ambient_tint, duration)
	_to(e, &"ambient_light_energy", look.ambient_energy * tod.ambient_energy_mul, duration)
	_to(e, &"fog_light_color", look.fog_color, duration)
	_to(e, &"fog_density", look.fog_density, duration)
	_to(e, &"ssao_radius", look.ssao_radius, duration)
	_to(e, &"ssao_intensity", look.ssao_intensity, duration)
	_to(e, &"ssao_power", look.ssao_power, duration)
	_to(e, &"ssao_light_affect", look.ssao_light_affect, duration)
	_set_feature(e, _p_ao_multibounce, look.ao_multibounce)
	_set_feature(e, _p_contact_env, look.contact_shadows and q.contact_shadows)

	# --- Солнце: Look дает множитель и мягкость, Time дает цвет, угол и энергию ---
	if _sun:
		_to(_sun, &"light_color", tod.sun_color, duration)
		_to(_sun, &"light_energy", _sun_base_energy * look.sun_energy_mul * tod.sun_energy, duration)
		_to(_sun, &"shadow_blur", look.sun_shadow_blur, duration)
		_set_feature(_sun, _p_contact_sun, look.contact_shadows and q.contact_shadows)
		_turn_sun(tod, duration)

	# --- Небо в окне ---
	_tint_sky(tod, duration)

	# --- Отражения ---
	if _probe:
		_to(_probe, &"intensity", look.probe_intensity, duration)

	# --- Лампа: авто (Look или Time) или ручной переключатель ---
	var lamp_on := look.lamp_forced_on or tod.lamp_on
	if _lamp_override >= 0:
		lamp_on = _lamp_override == 1
	var lamp_changed_now := lamp_on != _lamp_is_on
	_lamp_is_on = lamp_on
	if _lamp:
		if lamp_on:
			_lamp.visible = true   # включаем сразу, энергия растет твином
		else:
			later.append(func(): _lamp.visible = false)
		_to(_lamp, &"light_energy", look.lamp_energy if lamp_on else 0.0, duration)

	if _tween:
		_tween.finished.connect(func(): _run(later))
	else:
		_run(later)

	_sync_cards()
	if lamp_changed_now:
		lamp_changed.emit(lamp_on)


## Поворот солнца: азимут 0 = за окном северной стены (-Z), плюс к востоку (+X)
func _turn_sun(tod: TimeOfDayPreset, duration: float) -> void:
	var az := deg_to_rad(tod.sun_azimuth)
	var el := deg_to_rad(tod.sun_elevation)
	var to_sun := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
	var target := Basis.looking_at(-to_sun, Vector3.UP)   # -Z света смотрит по направлению луча
	if _tween and duration > 0.0:
		var q0 := _sun.global_basis.get_rotation_quaternion()
		var q1 := target.get_rotation_quaternion()
		_tween.tween_method(func(t: float): _sun.global_basis = Basis(q0.slerp(q1, t)), 0.0, 1.0, duration)
	else:
		_sun.global_basis = target


func _tint_sky(tod: TimeOfDayPreset, duration: float) -> void:
	var g := _sky_gradient()
	if g == null:
		return
	if _tween and duration > 0.0:
		var c0 := g.get_color(0)
		var c1 := g.get_color(1)
		_tween.tween_method(func(t: float):
			g.set_color(0, c0.lerp(tod.sky_top, t))
			g.set_color(1, c1.lerp(tod.sky_bottom, t)), 0.0, 1.0, duration)
	else:
		g.set_color(0, tod.sky_top)
		g.set_color(1, tod.sky_bottom)


func _sky_gradient() -> Gradient:
	if _sky == null:
		return null
	var m := _sky.material_override as StandardMaterial3D
	if m == null:
		return null
	var t := m.albedo_texture as GradientTexture2D
	if t == null:
		return null
	return t.gradient


## Карточки Observe показывают актуальное состояние, даже если оно сменилось из кода
func _sync_cards() -> void:
	if not is_instance_valid(_oc):
		return
	_oc.set_group_state(&"look", state.look)
	_oc.set_group_state(&"time", state.time)
	_oc.set_group_state(&"quality", state.quality)
	_oc.set_toggle_state(&"lamp", _lamp_is_on)


# ==========================================
# QUALITY: серверные настройки и файл настроек
# ==========================================

## То, что не относится к Environment: тени, AA, SSAO-quality, контуры. Применяется при смене tier
func _apply_quality_settings() -> void:
	var q: QualityPreset = qualities.get(state.quality)
	if q == null:
		return
	var vp := get_viewport()
	vp.msaa_3d = q.msaa as Viewport.MSAA
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q.fxaa else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.positional_shadow_atlas_size = q.positional_shadow_atlas
	RenderingServer.directional_shadow_atlas_set_size(q.dir_shadow_atlas, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(q.soft_shadow_quality as RenderingServer.ShadowQuality)
	RenderingServer.positional_soft_shadow_filter_set_quality(q.soft_shadow_quality as RenderingServer.ShadowQuality)
	RenderingServer.environment_set_ssao_quality(q.ssao_quality as RenderingServer.EnvironmentSSAOQuality,
			q.ssao_half_size, 0.5, 2, 50.0, 300.0)
	if _sun:
		match q.dir_shadow_splits:
			4:
				_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			2:
				_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			_:
				_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		_sun.directional_shadow_max_distance = q.dir_shadow_max_distance
	Outline.mode = Outline.Mode.ALL if q.outlines_all else Outline.Mode.HOVER_ONLY


## Грубый стартовый tier по имени видеокарты. Игрок меняет его в Observe, выбор запоминается
func _autodetect_quality() -> StringName:
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	var tier := &"medium"
	if gpu.contains("intel") or gpu.contains("uhd") or gpu.contains("iris") or gpu.contains("radeon graphics"):
		tier = &"low"
	elif gpu.contains("rtx") or gpu.contains("rx 6") or gpu.contains("rx 7") or gpu.contains("rx 9"):
		tier = &"high"
	if Global.debug_mode:
		print("[GFX] видеокарта: ", gpu, " -> tier ", tier)
	return tier


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # нет файла: get_value вернет значения по умолчанию
	var q := StringName(cfg.get_value("graphics", "quality", ""))
	state.quality = q if qualities.has(q) else _autodetect_quality()
	var l := StringName(cfg.get_value("graphics", "look", ""))
	if looks.has(l):
		state.look = l
	var t := StringName(cfg.get_value("graphics", "time", ""))
	if times.has(t):
		state.time = t


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # не затираем чужие секции
	cfg.set_value("graphics", "quality", String(state.quality))
	cfg.set_value("graphics", "look", String(state.look))
	cfg.set_value("graphics", "time", String(state.time))
	cfg.save(SETTINGS_PATH)


# ==========================================
# ВНУТРЕННЕЕ
# ==========================================

func _load_presets() -> void:
	looks.clear()
	for id in GraphicsPreset.builtin_ids():
		looks[id] = GraphicsPreset.builtin(id)
	times.clear()
	for id in TimeOfDayPreset.builtin_ids():
		times[id] = TimeOfDayPreset.builtin(id)
	qualities.clear()
	for id in QualityPreset.builtin_ids():
		qualities[id] = QualityPreset.builtin(id)
	_load_dir(LOOKS_DIR, looks, GraphicsPreset)
	_load_dir(TIMES_DIR, times, TimeOfDayPreset)
	_load_dir(QUALITY_DIR, qualities, QualityPreset)


## .tres из папки переопределяют встроенные по id
func _load_dir(dir: String, into: Dictionary, type: Script) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		var fname := f.trim_suffix(".remap")   # в экспорте ресурсы имеют суффикс .remap
		if not fname.ends_with(".tres"):
			continue
		var r = load(dir + fname)
		if r != null and is_instance_of(r, type):
			into[r.id] = r


func _save_builtin(dir: String, ids: Array, make: Callable) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for id in ids:
		var path: String = dir + String(id) + ".tres"
		if FileAccess.file_exists(path):
			print("[GFX] уже есть, пропускаю: ", path)
			continue
		var err := ResourceSaver.save(make.call(id), path)
		print("[GFX] сохранён ", path, " (код ", err, ")")


func _resolve() -> bool:
	_world_env = get_tree().get_first_node_in_group(&"gfx_env") as WorldEnvironment
	_env = _world_env.environment if _world_env else null
	_sun = get_tree().get_first_node_in_group(&"gfx_sun") as DirectionalLight3D
	_lamp = get_tree().get_first_node_in_group(&"gfx_lamp") as SpotLight3D
	_probe = get_tree().get_first_node_in_group(&"gfx_probe") as ReflectionProbe
	if _sun:
		_sun_base_energy = _sun.light_energy
	if _env == null:
		push_warning("GFX: нет WorldEnvironment в группе gfx_env (добавьте EnvironmentRoot в сцену или свою ноду в группу)")
		return false
	return true


func _connect_observe() -> void:
	_oc = get_tree().get_first_node_in_group(&"observe_controller")
	if _oc:
		_oc.observe_action.connect(_on_observe_action)
		_sync_cards()
	else:
		push_warning("GFX: ObserveController не найден, карточки Look и Light не работают")


## ⚡Сигнал из ObserveController
func _on_observe_action(_cat: StringName, _id: StringName, _pressed: bool) -> void:
	match _cat:
		&'look':
			if _pressed and looks.has(_id):
				apply_look(_id)
			elif _pressed and qualities.has(_id):
				apply_quality(_id)
		&'light':
			if _id == &'lamp':
				set_lamp(_pressed)
			elif _pressed and times.has(_id):
				apply_time(_id)


## Ищет булево свойство по ключевым словам в имени
func _find_bool_prop(obj: Object, keys: Array) -> StringName:
	if obj == null:
		return &""
	for pr in obj.get_property_list():
		if pr.type != TYPE_BOOL:
			continue
		var n: String = String(pr.name).to_lower()
		for k in keys:
			if n.contains(k):
				return StringName(pr.name)
	return &""


func _has_kw(n: String, kw: Array) -> bool:
	var l := n.to_lower()
	for k in kw:
		if l.contains(k):
			return true
	return false


func _discover_features() -> void:
	# Multi-bounce AO в 4.8 beta 1 встроен в SSAO без переключателя (в Environment свойства нет).
	# Поиск оставлен молча на случай, если в stable появится свойство
	_p_ao_multibounce = _find_bool_prop(_env, ["multibounce", "multi_bounce"])
	_p_contact_env = _find_bool_prop(_env, ["contact"])
	_p_contact_sun = _find_bool_prop(_sun, ["contact_shadows_allow", "contact"])
	if Global.debug_mode:
		print("[GFX] contact shadows (sun): ", str(_p_contact_sun) if _p_contact_sun != &"" else "НЕ НАЙДЕНО",
				" | multi-bounce AO переключатель: ", str(_p_ao_multibounce) if _p_ao_multibounce != &"" else "нет (встроен в SSAO)")
	if _sun and _p_contact_sun == &"":
		push_warning("GFX: свойство contact shadows на DirectionalLight3D не найдено (GFX.dump_props() покажет кандидатов)")


func _set_feature(obj: Object, prop: StringName, on: bool) -> void:
	if obj != null and prop != &"":
		obj.set(prop, on)


## Включаем эффект сразу, выключаем в конце перехода
func _flag(obj: Object, prop: StringName, on: bool, later: Array[Callable]) -> void:
	if on:
		obj.set(prop, true)
	elif obj.get(prop):
		later.append(func(): obj.set(prop, false))


func _to(obj: Object, prop: StringName, value: Variant, duration: float) -> void:
	if obj == null:
		return
	if _tween and duration > 0.0:
		_tween.tween_property(obj, NodePath(String(prop)), value, duration)
	else:
		obj.set(prop, value)


func _run(calls: Array[Callable]) -> void:
	for c in calls:
		c.call()
