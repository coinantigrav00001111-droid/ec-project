extends Node
# class_name не задаём: это синглтон GFX (autoload)

###########################
##💡 GFX - сервис графики (autoload)
############################
## Три независимые оси: Look (стиль, S3), Time (время суток, S4), Quality (стоимость, S5).
## Хранит состояние и применяет его к нодам окружения. Ноды находит по группам:
##   gfx_env (WorldEnvironment), gfx_sun (DirectionalLight3D), gfx_lamp (SpotLight3D), gfx_probe (ReflectionProbe).
## Их создает EnvironmentRoot, либо вы сами добавляете свои ноды в эти группы.
##
## Карточки Observe (категория look) приходят сигналом ObserveController.observe_action.
## Числовые параметры меняются плавным твином, дискретные (вкл/выкл эффектов) переключаются на краях перехода.
##
## Godot 4.8: имена свойств multi-bounce AO и contact shadows ищутся по шаблону (_discover_features),
## найденные имена печатаются в консоль. Если не нашлись, эффект просто не применяется (warning).

signal look_changed(id: StringName)
signal time_of_day_changed(id: StringName)   # S4
signal quality_changed(id: StringName)       # S5

const LOOKS_DIR := "res://data/graphics/looks/"
const DEFAULT_LOOK := &"toy"
const DEFAULT_TRANSITION := 0.5

var state := {"look": DEFAULT_LOOK, "time": &"day", "quality": &"medium"}
## id -> GraphicsPreset
var looks := {}

var _world_env: WorldEnvironment
var _env: Environment
var _sun: DirectionalLight3D
var _lamp: SpotLight3D
var _probe: ReflectionProbe
var _sun_base_energy := 1.0

var _p_ao_multibounce: StringName = &""
var _p_contact_env: StringName = &""
var _p_contact_sun: StringName = &""

var _tween: Tween


func _ready() -> void:
	_load_looks()
	# EnvironmentRoot и ObserveController встают в группы в своих _ready
	await get_tree().process_frame
	if _resolve():
		_discover_features()
		apply_look(state.look, 0.0)
	_connect_observe()


func _unhandled_input(event: InputEvent) -> void:
	# F10 (debug): сохранить встроенные Look в .tres для правки
	if Global.debug_mode and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F10:
		save_builtin_looks()


# ==========================================
# ПУБЛИЧНЫЙ API
# ==========================================

## Применить Look. duration = 0: мгновенно
func apply_look(id: StringName, duration := DEFAULT_TRANSITION) -> void:
	var p: GraphicsPreset = looks.get(id)
	if p == null:
		push_warning("GFX: нет пресета Look '%s'" % id)
		return
	if _env == null and not _resolve():
		return
	state.look = id

	if _tween:
		_tween.kill()
		_tween = null
	if duration > 0.0:
		_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var later: Array[Callable] = []   # что выключаем в конце перехода

	# --- Environment ---
	var e := _env
	e.tonemap_mode = p.tonemap
	e.adjustment_enabled = true
	e.background_mode = Environment.BG_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_flag(e, &"glow_enabled", p.glow_enabled, later)
	_flag(e, &"fog_enabled", p.fog_enabled, later)
	_flag(e, &"ssao_enabled", p.ssao_enabled, later)
	_to(e, &"tonemap_exposure", p.tonemap_exposure, duration)
	_to(e, &"tonemap_white", p.tonemap_white, duration)
	_to(e, &"adjustment_brightness", p.brightness, duration)
	_to(e, &"adjustment_contrast", p.contrast, duration)
	_to(e, &"adjustment_saturation", p.saturation, duration)
	_to(e, &"glow_intensity", p.glow_intensity, duration)
	_to(e, &"glow_bloom", p.glow_bloom, duration)
	_to(e, &"background_color", p.background_color, duration)
	_to(e, &"ambient_light_color", p.ambient_color, duration)
	_to(e, &"ambient_light_energy", p.ambient_energy, duration)
	_to(e, &"fog_light_color", p.fog_color, duration)
	_to(e, &"fog_density", p.fog_density, duration)
	_to(e, &"ssao_radius", p.ssao_radius, duration)
	_to(e, &"ssao_intensity", p.ssao_intensity, duration)
	_to(e, &"ssao_power", p.ssao_power, duration)
	_to(e, &"ssao_light_affect", p.ssao_light_affect, duration)
	_set_feature(e, _p_ao_multibounce, p.ao_multibounce)
	_set_feature(e, _p_contact_env, p.contact_shadows)

	# --- Солнце (цвет и угол задает Time, S4) ---
	if _sun:
		_to(_sun, &"light_energy", _sun_base_energy * p.sun_energy_mul, duration)
		_to(_sun, &"shadow_blur", p.sun_shadow_blur, duration)
		_set_feature(_sun, _p_contact_sun, p.contact_shadows)

	# --- Отражения и лампа ---
	if _probe:
		_to(_probe, &"intensity", p.probe_intensity, duration)
	if _lamp:
		if p.lamp_energy > 0.0:
			_lamp.visible = true   # включаем сразу, энергия растет твином
		else:
			later.append(func(): _lamp.visible = false)
		_to(_lamp, &"light_energy", p.lamp_energy, duration)

	if _tween:
		_tween.finished.connect(func(): _run(later))
	else:
		_run(later)
	look_changed.emit(id)


func get_state() -> Dictionary:
	return state.duplicate()


## Для SavedGame / настроек (S5)
func set_state(d: Dictionary) -> void:
	if d.has("look"):
		apply_look(StringName(d.look), 0.0)


## Сохраняет встроенные Look в res://data/graphics/looks/*.tres, существующие файлы не трогает
func save_builtin_looks() -> void:
	DirAccess.make_dir_recursive_absolute(LOOKS_DIR)
	for id in GraphicsPreset.builtin_ids():
		var path: String = LOOKS_DIR + String(id) + ".tres"
		if FileAccess.file_exists(path):
			print("[GFX] уже есть, пропускаю: ", path)
			continue
		var err := ResourceSaver.save(GraphicsPreset.builtin(id), path)
		print("[GFX] сохранён ", path, " (код ", err, ")")


## Печатает свойства Environment и DirectionalLight3D, относящиеся к AO и contact shadows (Godot 4.8)
func dump_props() -> void:
	for pair in [["Environment", _env], ["DirectionalLight3D", _sun]]:
		var obj: Object = pair[1]
		if obj == null:
			continue
		print("[GFX] ", pair[0], ":")
		for pr in obj.get_property_list():
			var n: String = String(pr.name).to_lower()
			if n.contains("contact") or n.contains("bounce") or n.begins_with("ssao"):
				print("    ", pr.name, " : ", type_string(pr.type))


# ==========================================
# ВНУТРЕННЕЕ
# ==========================================

func _load_looks() -> void:
	looks.clear()
	for id in GraphicsPreset.builtin_ids():
		looks[id] = GraphicsPreset.builtin(id)
	if not DirAccess.dir_exists_absolute(LOOKS_DIR):
		return
	for f in DirAccess.get_files_at(LOOKS_DIR):
		var fname := f.trim_suffix(".remap")   # в экспорте ресурсы имеют суффикс .remap
		if not fname.ends_with(".tres"):
			continue
		var r = load(LOOKS_DIR + fname)
		if r is GraphicsPreset:
			looks[r.id] = r


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
	var oc = get_tree().get_first_node_in_group(&"observe_controller")
	if oc:
		oc.observe_action.connect(_on_observe_action)
	else:
		push_warning("GFX: ObserveController не найден, карточки Look не работают")


## ⚡Сигнал из ObserveController
func _on_observe_action(_cat: StringName, _id: StringName, _pressed: bool) -> void:
	if _cat == &'look' and _pressed and looks.has(_id):
		apply_look(_id)
	# TODO S4: time (morning/day/evening/night, lamp), S5: quality (low/medium/high)


## Ищет булево свойство по ключевым словам в имени (имена фич 4.8 не зафиксированы в плане)
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


func _discover_features() -> void:
	_p_ao_multibounce = _find_bool_prop(_env, ["multibounce", "multi_bounce"])
	_p_contact_env = _find_bool_prop(_env, ["contact"])
	_p_contact_sun = _find_bool_prop(_sun, ["contact"])
	if Global.debug_mode:
		print("[GFX] multi-bounce AO: ", _p_ao_multibounce if _p_ao_multibounce != &"" else "НЕ НАЙДЕНО",
				" | contact shadows env: ", _p_contact_env if _p_contact_env != &"" else "НЕ НАЙДЕНО",
				" | contact shadows sun: ", _p_contact_sun if _p_contact_sun != &"" else "НЕ НАЙДЕНО")
	if _p_ao_multibounce == &"" or _p_contact_env == &"" or (_sun and _p_contact_sun == &""):
		push_warning("GFX: часть свойств Godot 4.8 не найдена. Вызовите GFX.dump_props() и пришлите вывод")
		dump_props()


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
