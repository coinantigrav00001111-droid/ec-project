extends VBoxContainer

########################
## Track Studio: вкладка «Материалы» (ATTN_20, шаг T2)
########################
## Набор текстур из res://data/textures/track/<набор>/ -> StandardMaterial3D -> поле стиля.
## Тайл рельса и балласта записывается в поля стиля (rail_uv_tile, ballast_uv_tile), тайл шпалы остаётся в материале.
## Логика сборки в lib/material_builder.gd, здесь только интерфейс.

const SETS_DIR := "res://data/textures/track"
const OUT_DIR := "res://data/tracks/materials"
const PREVIEW_DELAY := 0.2

# [название, роль, поле материала, поле тайла ("" = тайл в материале)]
const ROLES := [
	["Рельс", "rail", "rail_material", "rail_uv_tile"],
	["Балласт", "ballast", "ballast_material", "ballast_uv_tile"],
	["Шпала", "sleeper", "sleeper_material", ""],
]
const HINTS := {
	"rail": ["metal"],
	"ballast": ["gravel"],
	"sleeper": ["planks", "wood", "concrete", "sleeper"],
}
const PROJECTIONS := ["По UV меша (как есть)", "UV меша в ю (меши генератора)", "Triplanar (BoxMesh)"]

var studio                     # track_studio.gd: get_style(), set_field(), say() (без типа: методы скрипта)

var _role_opt: OptionButton
var _set_opt: OptionButton
var _info: RichTextLabel
var _convert_btn: Button
var _proj_opt: OptionButton
var _tint: ColorPickerButton
var _spin := {}                # ключ параметра -> SpinBox
var _check := {}               # ключ параметра -> CheckBox
var _tile_x: SpinBox
var _tile_y: SpinBox
var _name_edit: LineEdit
var _live: CheckBox
var _timer: Timer

var _params := {}
var _found := {}
var _syncing := false


func setup(studio_ref) -> void:
	studio = studio_ref
	_build()
	_reload_sets()
	_on_role_changed(0)


func _build() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = PREVIEW_DELAY
	_timer.timeout.connect(func(): _apply(false))
	add_child(_timer)

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)

	var r1 := _row(v, "Материал для")
	_role_opt = OptionButton.new()
	_role_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for r in ROLES:
		_role_opt.add_item(r[0])
	_role_opt.item_selected.connect(_on_role_changed)
	r1.add_child(_role_opt)

	var r2 := _row(v, "Набор текстур")
	_set_opt = OptionButton.new()
	_set_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_opt.item_selected.connect(func(_i: int): _on_set_changed())
	r2.add_child(_set_opt)
	var rb := Button.new()
	rb.text = "Обновить"
	rb.pressed.connect(func():
		_reload_sets()
		_on_set_changed())
	r2.add_child(rb)

	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.scroll_active = false
	_info.custom_minimum_size = Vector2(0, 110)
	v.add_child(_info)

	var r3 := HBoxContainer.new()
	v.add_child(r3)
	var fix := Button.new()
	fix.text = "Подготовить импорт"
	fix.tooltip_text = "Включает мипмапы и Normal Map: Enable в .import файлах набора. Godot переимпортирует при возврате фокуса в редактор."
	fix.pressed.connect(_on_fix_import)
	r3.add_child(fix)
	_convert_btn = Button.new()
	_convert_btn.text = "Нормаль DX → GL"
	_convert_btn.tooltip_text = "Инвертирует зелёный канал и пишет <имя>_GL.png рядом. Нужно, только если в наборе нет NormalGL."
	_convert_btn.pressed.connect(_on_convert)
	r3.add_child(_convert_btn)

	v.add_child(HSeparator.new())

	_proj_opt = OptionButton.new()
	for i in PROJECTIONS.size():
		_proj_opt.add_item(PROJECTIONS[i], i)
	_proj_opt.item_selected.connect(func(i: int):
		_params["triplanar"] = (i == 2)
		_params["mesh_uv_units"] = (i == 1)
		_changed())
	var rp := _row(v, "Проекция (шпала)")
	_proj_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rp.add_child(_proj_opt)

	var rt := _row(v, "Тайл, ю (x, y)")
	_tile_x = _make_spin(rt, 0.05, 50.0, 0.05, func(x: float):
		_params["tile"] = Vector2(x, _params["tile"].y)
		_changed())
	_tile_y = _make_spin(rt, 0.05, 50.0, 0.05, func(y: float):
		_params["tile"] = Vector2(_params["tile"].x, y)
		_changed())
	rt.tooltip_text = "Размер одного повтора текстуры. Рельс и балласт: x вдоль пути, y поперёк профиля. Шпала: размер тайла по осям. Ориентир: 1 ю около 1 м прототипа."

	var rc := _row(v, "Тонировка")
	_tint = ColorPickerButton.new()
	_tint.custom_minimum_size = Vector2(80, 0)
	_tint.edit_alpha = false
	_tint.color_changed.connect(func(c: Color):
		_params["tint"] = c
		_changed())
	rc.add_child(_tint)

	_param_spin(v, "roughness", "Шероховатость ×", 0.0, 2.0, 0.01)
	_param_spin(v, "metallic", "Металличность", -1.0, 1.0, 0.01, "-1 = авто: 1 если есть карта металличности, иначе 0")
	_param_spin(v, "normal_scale", "Сила нормали", 0.0, 4.0, 0.05)
	_param_check(v, "use_ao", "Карта AO")
	_param_spin(v, "ao_light_affect", "AO на свет", 0.0, 1.0, 0.05)
	_param_check(v, "use_height", "Карта высоты (parallax, дорого)")
	_param_spin(v, "height_scale", "Высота, масштаб", 0.0, 0.5, 0.005)

	v.add_child(HSeparator.new())

	_live = CheckBox.new()
	_live.text = "Сразу показывать в превью"
	_live.button_pressed = true
	v.add_child(_live)

	var rn := _row(v, "Имя файла")
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.tooltip_text = "res://data/tracks/materials/<имя>.tres"
	rn.add_child(_name_edit)

	var rb2 := HBoxContainer.new()
	v.add_child(rb2)
	var b1 := Button.new()
	b1.text = "Применить к стилю"
	b1.tooltip_text = "Материал во встроенном виде, без файла (для пробы)."
	b1.pressed.connect(func(): _apply(false))
	rb2.add_child(b1)
	var b2 := Button.new()
	b2.text = "Сохранить файл и назначить"
	b2.pressed.connect(func(): _apply(true))
	rb2.add_child(b2)


func _row(parent: Control, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(130, 0)
	h.add_child(l)
	return h


func _make_spin(parent: Control, lo: float, hi: float, step: float, cb: Callable) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v: float):
		if not _syncing:
			cb.call(v))
	parent.add_child(s)
	return s


func _param_spin(parent: Control, key: String, text: String, lo: float, hi: float, step: float, tip := "") -> void:
	var r := _row(parent, text)
	r.tooltip_text = tip
	_spin[key] = _make_spin(r, lo, hi, step, func(v: float):
		_params[key] = v
		_changed())


func _param_check(parent: Control, key: String, text: String) -> void:
	var c := CheckBox.new()
	c.text = text
	c.toggled.connect(func(on: bool):
		if _syncing:
			return
		_params[key] = on
		_changed())
	parent.add_child(c)
	_check[key] = c


# ==========================================
# Состояние
# ==========================================

func _role() -> Array:
	return ROLES[_role_opt.selected]


func _reload_sets() -> void:
	var keep := _set_opt.get_item_text(_set_opt.selected) if _set_opt.item_count > 0 and _set_opt.selected >= 0 else ""
	_set_opt.clear()
	for n in TrackMaterialBuilder.list_sets(SETS_DIR):
		_set_opt.add_item(n)
	if _set_opt.item_count == 0:
		_info.text = "[color=#ff7b7b]В %s нет папок с наборами текстур[/color]" % SETS_DIR
		return
	var idx := 0
	for i in _set_opt.item_count:
		if _set_opt.get_item_text(i) == keep:
			idx = i
	_set_opt.select(idx)


## Вызывается студией при открытии стиля: подхватывает параметры материала, собранного в студии
func refresh_from_style() -> void:
	if studio == null or _role_opt == null:
		return
	_on_role_changed(_role_opt.selected)


func _on_role_changed(_i: int) -> void:
	var role: String = _role()[1]
	var mat: Material = null
	var style: TrackStyle = studio.get_style() if studio else null
	if style:
		mat = style.get(_role()[2])
	if mat and mat.has_meta("track_params") and mat.get_meta("track_role", "") == role:
		_params = TrackMaterialBuilder.preset(role)
		_params.merge(mat.get_meta("track_params"), true)
		_select_set(String(mat.get_meta("track_source", "")).get_file())
	else:
		_params = TrackMaterialBuilder.preset(role)
		_pick_hint_set(role)
		if style and _role()[3] != "":
			var t: Vector2 = style.get(_role()[3])
			if t.x > 0.0 and t.y > 0.0:
				_params["tile"] = t
	_proj_opt.disabled = role != "sleeper"
	_on_set_changed(false)


func _select_set(set_name: String) -> void:
	for i in _set_opt.item_count:
		if _set_opt.get_item_text(i) == set_name:
			_set_opt.select(i)
			return


func _pick_hint_set(role: String) -> void:
	for hint in HINTS.get(role, []):
		for i in _set_opt.item_count:
			if _set_opt.get_item_text(i).to_lower().begins_with(hint):
				_set_opt.select(i)
				return


func _set_dir() -> String:
	if _set_opt.item_count == 0 or _set_opt.selected < 0:
		return ""
	return SETS_DIR.path_join(_set_opt.get_item_text(_set_opt.selected))


## Перечитывает набор. reset_name: обновить имя файла
func _on_set_changed(reset_name := true) -> void:
	var dir := _set_dir()
	_found = TrackMaterialBuilder.scan(dir) if dir != "" else {}
	_report()
	if reset_name and dir != "":
		_name_edit.text = _default_name(dir)
	elif dir != "" and _name_edit.text.is_empty():
		_name_edit.text = _default_name(dir)
	_sync_ui()


func _default_name(dir: String) -> String:
	var raw := "%s_%s" % [_role()[1], dir.get_file().get_slice("_", 0).to_lower()]
	var re := RegEx.new()
	re.compile("[^a-z0-9_]")
	return re.sub(raw, "_", true)


func _report() -> void:
	var t := ""
	if _found.is_empty():
		t = "[color=#ff7b7b]Карты не найдены[/color]"
		_convert_btn.visible = false
	else:
		t = "[b]Найдено:[/b] "
		var parts: PackedStringArray = []
		for key in ["albedo", "normal", "roughness", "metallic", "ao", "height", "orm"]:
			if _found.has(key):
				parts.append("%s (%s)" % [TrackMaterialBuilder.ROLE_TITLES[key], _suffix(_found[key])])
		t += ", ".join(parts) + "\n"
		_convert_btn.visible = _found.get("normal_is_dx", false)
		if _found.get("normal_is_dx", false):
			t += "[color=#ffcf5c]Только нормаль DirectX: рельеф будет вывернут. Нужна конвертация в GL.[/color]\n"
		if not _found.has("albedo"):
			t += "[color=#ff7b7b]Нет карты цвета[/color]\n"
		for w in TrackMaterialBuilder.import_warnings(_found):
			t += "[color=#ffcf5c]%s[/color]\n" % w.replace("[", "[lb]")
	_info.text = t


## Последний токен имени файла без расширения: Gravel023_1K-JPG_Color.jpg -> Color
func _suffix(path: String) -> String:
	var base := path.get_file().get_basename()
	return base.get_slice("_", base.count("_"))


func _sync_ui() -> void:
	_syncing = true
	for k in _spin:
		(_spin[k] as SpinBox).set_value_no_signal(float(_params[k]))
	for k in _check:
		(_check[k] as CheckBox).set_pressed_no_signal(bool(_params[k]))
	var t: Vector2 = _params["tile"]
	_tile_x.set_value_no_signal(t.x)
	_tile_y.set_value_no_signal(t.y)
	_tint.color = _params["tint"]
	_proj_opt.select(2 if _params["triplanar"] else (1 if _params["mesh_uv_units"] else 0))
	_syncing = false


# ==========================================
# Действия
# ==========================================

func _changed() -> void:
	if _syncing:
		return
	if _live.button_pressed:
		_timer.start()


func _on_fix_import() -> void:
	var changed := TrackMaterialBuilder.fix_import(_found)
	if changed.is_empty():
		studio.say("Импорт набора уже настроен")
	else:
		studio.say("Изменены .import: %s. Вернитесь в редактор, дождитесь импорта и нажмите «Обновить»." % ", ".join(changed))
	_report()


func _on_convert() -> void:
	if not _found.get("normal_is_dx", false):
		return
	var out := TrackMaterialBuilder.convert_dx_to_gl(_found["normal"])
	if out.is_empty():
		studio.say("Не удалось конвертировать нормаль", true)
		return
	studio.say("Записано %s. Вернитесь в редактор, дождитесь импорта и нажмите «Обновить»." % out.get_file())


## Собирает материал и кладёт в поле стиля. save = записать файл и привязать к нему
func _apply(save: bool) -> void:
	if studio == null or studio.get_style() == null:
		return
	if not _found.has("albedo") and not _found.has("orm"):
		studio.say("В наборе нет карты цвета", true)
		return
	var tex := TrackMaterialBuilder.load_textures(_found)
	if tex.is_empty():
		studio.say("Текстуры не загрузились: возможно, ещё идёт импорт", true)
		return
	var role: String = _role()[1]
	var mat := TrackMaterialBuilder.build(tex, _params)
	TrackMaterialBuilder.stamp(mat, role, _set_dir(), _params)
	if save:
		var nm := _name_edit.text.strip_edges()
		if not TrackStyleIO.is_valid_id(nm):
			studio.say("Имя файла: латиница в нижнем регистре, цифры, _", true)
			return
		if not DirAccess.dir_exists_absolute(OUT_DIR):
			DirAccess.make_dir_recursive_absolute(OUT_DIR)
		var path := OUT_DIR.path_join(nm + ".tres")
		var err := ResourceSaver.save(mat, path)
		if err != OK:
			studio.say("Не удалось записать %s (код %d)" % [path, err], true)
			return
		mat.take_over_path(path)
		studio.say("Материал записан: %s" % path)
	studio.set_field(_role()[2], mat)
	if _role()[3] != "":
		studio.set_field(_role()[3], _params["tile"])
