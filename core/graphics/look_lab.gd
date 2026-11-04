class_name LookLab extends Node

########################
## Look Lab (debug): прогон вариантов картинки одним заходом (ATTN_14 §14.13).
########################
## Ctrl+Shift+L (любая раскладка) или кнопка на вкладке Keys панели F3: для каждого варианта из VARIANTS применяет его поверх Look `clean` + Time `day`,
## переезжает по закладкам камеры 1-5 (Settings camera/bookmarks; нет закладок: снимает текущий вид),
## снимает кадр без UI на качестве High и пишет в user://look_lab/<время>/:
##   <вариант>_b<N>.png, metrics.csv, variants.txt (параметры прогона).
## metrics.csv: насыщенность, яркость, разброс яркости, доля насыщенных пикселей (те же формулы, что в анализе
## скриншотов Golf 2), плюс draw calls, объекты и примитивы кадра (Performance, §14.7.1).
## После прогона всё возвращается: Look, Time, Quality, Environment, камера, UI.
## Запускать в режиме Observe (виньетка и tilt-shift работают только там). Во время прогона мышь и клавиши не трогать.
## Вариант: {"id": "...", "look": {поле GraphicsPreset: значение}, "time": {поле TimeOfDayPreset: значение},
##           "env": {свойство Environment: значение}}. Все поля необязательны.

const OUT_DIR := "user://look_lab/"
const BASE_LOOK := &"clean"
const BASE_TIME := &"day"
const SETTLE_FIRST := 30   # кадров после смены варианта (тени, volumetric fog сходятся не сразу)
const SETTLE_VIEW := 12    # кадров после смены закладки

const _WARM := Color(1.0, 0.90, 0.74)
const _COOL := Color(0.62, 0.70, 0.86)
## v1 это опорная точка «объём»: меньше ровного ambient, сильнее тёплое солнце, холодная тень.
## Остальные варианты добавляют по одному приёму поверх v1, чтобы было видно вклад каждого.
const VARIANTS := [
	{"id": "v0_base"},
	{"id": "v1_warm_cool",
		"look": {"ambient_energy": 0.55, "ambient_color": _COOL, "sun_energy_mul": 1.5, "contrast": 1.08, "saturation": 1.2},
		"time": {"sun_color": _WARM}},
	{"id": "v2_aces",
		"look": {"ambient_energy": 0.55, "ambient_color": _COOL, "sun_energy_mul": 1.5, "contrast": 1.08, "saturation": 1.2,
			"tonemap": Environment.TONE_MAPPER_ACES},
		"time": {"sun_color": _WARM}},
	{"id": "v3_agx",
		"look": {"ambient_energy": 0.55, "ambient_color": _COOL, "sun_energy_mul": 1.5, "contrast": 1.08, "saturation": 1.2,
			"tonemap": Environment.TONE_MAPPER_AGX},
		"time": {"sun_color": _WARM}},
	{"id": "v4_glow",
		"look": {"ambient_energy": 0.55, "ambient_color": _COOL, "sun_energy_mul": 1.5, "contrast": 1.08, "saturation": 1.2,
			"glow_enabled": true, "glow_intensity": 0.6, "glow_bloom": 0.12},
		"time": {"sun_color": _WARM}},
	{"id": "v5_vignette",
		"look": {"ambient_energy": 0.55, "ambient_color": _COOL, "sun_energy_mul": 1.5, "contrast": 1.08, "saturation": 1.2,
			"vignette": 0.45},
		"time": {"sun_color": _WARM}},
	{"id": "v6_shafts_thin",
		"look": {"ambient_energy": 0.55, "ambient_color": _COOL, "sun_energy_mul": 1.5, "contrast": 1.08, "saturation": 1.2},
		"time": {"sun_color": _WARM},
		"env": {"volumetric_fog_enabled": true, "volumetric_fog_density": 0.001,
			"volumetric_fog_length": 600.0, "volumetric_fog_albedo": Color(1.0, 0.96, 0.88), "volumetric_fog_anisotropy": 0.6}},
	{"id": "v7_shafts_thick",
		"look": {"ambient_energy": 0.55, "ambient_color": _COOL, "sun_energy_mul": 1.5, "contrast": 1.08, "saturation": 1.2},
		"time": {"sun_color": _WARM},
		"env": {"volumetric_fog_enabled": true, "volumetric_fog_density": 0.003,
			"volumetric_fog_length": 600.0, "volumetric_fog_albedo": Color(1.0, 0.96, 0.88), "volumetric_fog_anisotropy": 0.6}},
	{"id": "v8_ref_ssao",
		"look": {"ambient_energy": 0.55, "ambient_color": _COOL, "sun_energy_mul": 1.5, "contrast": 1.08, "saturation": 1.2,
			"ssao_enabled": true, "ssao_radius": 0.9, "ssao_intensity": 2.6, "ssao_power": 1.6, "ssao_light_affect": 0.15},
		"time": {"sun_color": _WARM}},
	{"id": "v9_combo",
		"look": {"ambient_energy": 0.55, "ambient_color": _COOL, "sun_energy_mul": 1.5, "contrast": 1.08, "saturation": 1.2,
			"glow_enabled": true, "glow_intensity": 0.6, "glow_bloom": 0.12, "vignette": 0.45},
		"time": {"sun_color": _WARM},
		"env": {"volumetric_fog_enabled": true, "volumetric_fog_density": 0.001,
			"volumetric_fog_length": 600.0, "volumetric_fog_albedo": Color(1.0, 0.96, 0.88), "volumetric_fog_anisotropy": 0.6}},
]

## Действие InputMap. Клавиша по physical_keycode: работает на любой раскладке (на русской keycode у L другой)
const ACTION := &"debug_look_lab"

var _busy := false


func _ready() -> void:
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_L
		ev.ctrl_pressed = true
		ev.shift_pressed = true
		InputMap.action_add_event(ACTION, ev)
	print("[LookLab] готов: Ctrl+Shift+L (любая раскладка) или кнопка «Нажать» на вкладке Keys панели F3")


func _unhandled_input(event: InputEvent) -> void:
	if not Global.debug_mode:
		return
	if event.is_action_pressed(ACTION) and not event.is_echo():
		get_viewport().set_input_as_handled()
		print("[LookLab] запуск")
		run()


## Прогон. only: id вариантов (пусто = все)
func run(only: Array = []) -> void:
	if _busy:
		return
	var gimbal := get_node_or_null("/root/GameRoot/Gimbal") as Gimbal
	var env: Environment = GFX.get("_env")
	if gimbal == null or env == null or not GFX.looks.has(BASE_LOOK) or not GFX.times.has(BASE_TIME):
		push_warning("LookLab: нет Gimbal, Environment или пресетов %s / %s (режим --fast?)" % [BASE_LOOK, BASE_TIME])
		return
	_busy = true

	var ui := get_node_or_null("/root/GameRoot/UI")
	var views := _views(gimbal)
	var prev := {"look": GFX.state.look, "time": GFX.state.time, "quality": GFX.state.quality}
	var look0: GraphicsPreset = GFX.looks[BASE_LOOK]
	var time0: TimeOfDayPreset = GFX.times[BASE_TIME]
	var view0 := gimbal.get_view()
	var ui_was := true
	if ui and "visible" in ui:
		ui_was = ui.visible
		ui.visible = false
	Hints.suspend(true)
	if not bool(GFX.get("_observe_active")):
		print("[LookLab] ВНИМАНИЕ: не режим Observe, виньетка и tilt-shift в кадрах не появятся")

	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var dir := OUT_DIR + stamp + "/"
	DirAccess.make_dir_recursive_absolute(dir)
	var rows: Array[String] = ["variant,view,sat,val,val_std,sat50_pct,draw_calls,objects,primitives"]
	var env_saved := {}
	var done := 0

	GFX.apply_quality(&"high", 0.0, false)
	for v in VARIANTS:
		var id: String = v.id
		if not only.is_empty() and not only.has(id):
			continue
		_restore_env(env, env_saved)
		var look := look0.duplicate() as GraphicsPreset
		_set_props(look, v.get("look", {}), id)
		var tod := time0.duplicate() as TimeOfDayPreset
		_set_props(tod, v.get("time", {}), id)
		GFX.looks[BASE_LOOK] = look
		GFX.times[BASE_TIME] = tod
		GFX.apply_look(BASE_LOOK, 0.0)
		GFX.apply_time(BASE_TIME, 0.0)
		var extra: Dictionary = v.get("env", {})
		for k in extra:
			if not (k in env):
				push_warning("LookLab[%s]: у Environment нет свойства '%s'" % [id, k])
				continue
			if not env_saved.has(k):
				env_saved[k] = env.get(k)
			env.set(k, extra[k])
		await _frames(SETTLE_FIRST)

		for i in views.size():
			var vw: Dictionary = views[i].view
			gimbal.set_view(vw.pivot, vw.yaw, vw.pitch, vw.dist, true)
			await _frames(SETTLE_VIEW)
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var shot := "%s_%s" % [id, views[i].name]
			var err := img.save_png(dir + shot + ".png")
			if err != OK:
				push_error("LookLab: не сохранён %s (код %d)" % [shot, err])
			var s := _stats(img)
			rows.append("%s,%s,%.3f,%.3f,%.3f,%.1f,%d,%d,%d" % [id, views[i].name, s.sat, s.val, s.val_std, s.sat50,
					int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
					int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
					int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
		done += 1
		print("[LookLab] %s готов (%d/%d)" % [id, done, VARIANTS.size() if only.is_empty() else only.size()])

	# --- Возврат состояния ---
	_restore_env(env, env_saved)
	GFX.looks[BASE_LOOK] = look0
	GFX.times[BASE_TIME] = time0
	GFX.apply_look(prev.look, 0.0)
	GFX.apply_time(prev.time, 0.0)
	GFX.apply_quality(prev.quality, 0.0, false)
	gimbal.set_view(view0.pivot, view0.yaw, view0.pitch, view0.dist, true)
	if ui and "visible" in ui:
		ui.visible = ui_was
	Hints.suspend(false)

	_write(dir + "metrics.csv", "\n".join(rows) + "\n")
	_write(dir + "variants.txt", var_to_str(VARIANTS))
	print("[LookLab] готово, файлы: ", ProjectSettings.globalize_path(dir))
	_busy = false


# ==========================================
# Вспомогательное
# ==========================================

func _views(gimbal: Gimbal) -> Array:
	var res: Array = []
	var stored = Settings.get_value("camera", "bookmarks", [])
	if stored is Array:
		for i in stored.size():
			var bm = stored[i]
			if bm is Dictionary and bm.has("pivot") and bm.has("yaw") and bm.has("pitch") and bm.has("dist"):
				res.append({"name": "b%d" % (i + 1), "view": bm})
	if res.is_empty():
		res.append({"name": "cur", "view": gimbal.get_view()})
		print("[LookLab] закладок нет (клавиши 1-5 в Observe их сохраняют), снимаю текущий вид")
	return res


func _set_props(obj: Object, props: Dictionary, variant_id: String) -> void:
	for k in props:
		if not (k in obj):
			push_warning("LookLab[%s]: у %s нет поля '%s'" % [variant_id, obj.get_class(), k])
			continue
		obj.set(k, props[k])


func _restore_env(env: Environment, saved: Dictionary) -> void:
	for k in saved:
		env.set(k, saved[k])
	saved.clear()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Те же формулы, что в анализе скриншотов: S = (max-min)/max, V = max (по sRGB-значениям картинки)
func _stats(img: Image) -> Dictionary:
	var s := img.duplicate() as Image
	s.convert(Image.FORMAT_RGB8)
	s.resize(240, 135, Image.INTERPOLATE_BILINEAR)
	var w := s.get_width()
	var h := s.get_height()
	var sum_s := 0.0
	var sum_v := 0.0
	var sum_v2 := 0.0
	var hi := 0
	for y in h:
		for x in w:
			var c := s.get_pixel(x, y)
			var mx := maxf(c.r, maxf(c.g, c.b))
			var mn := minf(c.r, minf(c.g, c.b))
			var sat := 0.0 if mx <= 0.0 else (mx - mn) / mx
			sum_s += sat
			sum_v += mx
			sum_v2 += mx * mx
			if sat > 0.5:
				hi += 1
	var n := float(w * h)
	var mean_v := sum_v / n
	return {
		"sat": sum_s / n,
		"val": mean_v,
		"val_std": sqrt(maxf(sum_v2 / n - mean_v * mean_v, 0.0)),
		"sat50": 100.0 * hi / n,
	}


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("LookLab: не записан " + path)
		return
	f.store_string(text)
