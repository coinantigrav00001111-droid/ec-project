extends VBoxContainer

########################
## Track Studio: вкладка «Шпала» (ATTN_20, шаг T3)
########################
## Генератор меша шпалы (дерево, бетон) и импорт меша из .glb/.gltf/.tscn с приведением к контракту
## (origin в центре площади опоры, низ на y = 0, длинная сторона по X). Логика в lib/sleeper_factory.gd.

const OUT_DIR := "res://data/tracks/meshes"
const KINDS := [["Дерево", "wood"], ["Бетон (с площадками)", "concrete"]]

var studio                      # track_studio.gd: get_style(), set_field(), say()

var _kind_opt: OptionButton
var _spin := {}                 # ключ спецификации -> SpinBox
var _gen_name: LineEdit
var _gen_mesh: ArrayMesh

var _src_edit: LineEdit
var _items_list: ItemList
var _items: Array[Dictionary] = []
var _scale: SpinBox
var _rot: SpinBox
var _auto: CheckBox
var _keep_mat: CheckBox
var _merge: CheckBox
var _imp_name: LineEdit
var _report: RichTextLabel
var _dialog: FileDialog
var _norm_mesh: ArrayMesh
var _syncing := false


func setup(studio_ref) -> void:
	studio = studio_ref
	_build()


func _build() -> void:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)

	# --- Генератор ---
	_title(v, "Генератор")
	var rk := _row(v, "Тип")
	_kind_opt = OptionButton.new()
	_kind_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in KINDS:
		_kind_opt.add_item(k[0])
	rk.add_child(_kind_opt)
	_spin_row(v, "length", "Длина (X, поперёк пути)", 0.5, 10.0, 0.01)
	_spin_row(v, "height", "Высота", 0.02, 2.0, 0.005)
	_spin_row(v, "width", "Ширина (Z, вдоль пути)", 0.02, 2.0, 0.005)
	_spin_row(v, "chamfer", "Фаска", 0.0, 0.2, 0.005)
	_spin_row(v, "taper", "Бетон: сужение верха", 0.0, 0.3, 0.005)
	_spin_row(v, "pad_height", "Бетон: высота площадок", 0.0, 0.2, 0.005)
	_spin_row(v, "pad_length", "Бетон: длина площадок", 0.05, 2.0, 0.01)
	var hint := Label.new()
	hint.text = "UV генератора в ю: для материала шпалы выберите проекцию «UV меша в ю». Площадки бетона ставятся на rail_x стиля и входят в высоту шпалы."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(1, 1, 1, 0.6)
	v.add_child(hint)
	var rg := HBoxContainer.new()
	v.add_child(rg)
	_button(rg, "Сгенерировать в стиль", _on_generate)
	_button(rg, "Убрать меш (BoxMesh)", func(): studio.set_field("sleeper_mesh", null))
	var rn := _row(v, "Имя файла")
	_gen_name = LineEdit.new()
	_gen_name.text = "sleeper_wood"
	_gen_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gen_name.tooltip_text = "res://data/tracks/meshes/<имя>.res"
	rn.add_child(_gen_name)
	_button(v, "Сохранить сгенерированный меш и назначить", _on_save_generated)

	v.add_child(HSeparator.new())

	# --- Импорт ---
	_title(v, "Импорт меша")
	var rs := _row(v, "Файл")
	_src_edit = LineEdit.new()
	_src_edit.editable = false
	_src_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rs.add_child(_src_edit)
	_button(rs, "Выбрать…", func(): _dialog.popup_centered(Vector2i(900, 600)))
	_items_list = ItemList.new()
	_items_list.select_mode = ItemList.SELECT_MULTI
	_items_list.custom_minimum_size = Vector2(0, 90)
	v.add_child(_items_list)

	var ro := _row(v, "Масштаб ×")
	_scale = _spin_plain(ro, 0.0001, 10000.0, 0.0001, 1.0)
	_scale.tooltip_text = "Умножает размеры меша. Из Blender в метрах: ориентир 1 ю около 1 м прототипа."
	var rr := _row(v, "Поворот Y, °")
	_rot = _spin_plain(rr, -360.0, 360.0, 90.0, 0.0)
	_auto = _check(v, "Длинную сторону на X автоматически", true)
	_keep_mat = _check(v, "Сохранить материалы меша", true)
	_merge = _check(v, "Слить поверхности в одну", false)
	var ri := _row(v, "Имя файла")
	_imp_name = LineEdit.new()
	_imp_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ri.add_child(_imp_name)
	var rb := HBoxContainer.new()
	v.add_child(rb)
	_button(rb, "Нормализовать в стиль", func(): _on_normalize(false))
	_button(rb, "Нормализовать и сохранить", func(): _on_normalize(true))
	_report = RichTextLabel.new()
	_report.bbcode_enabled = true
	_report.fit_content = true
	_report.scroll_active = false
	_report.custom_minimum_size = Vector2(0, 80)
	v.add_child(_report)

	_dialog = FileDialog.new()
	_dialog.access = FileDialog.ACCESS_RESOURCES
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.use_native_dialog = false
	_dialog.title = "Меш шпалы"
	_dialog.add_filter("*.glb,*.gltf,*.tscn,*.res,*.tres", "Меши и сцены")
	_dialog.current_dir = "res://data/import"
	_dialog.file_selected.connect(_on_source_picked)
	add_child(_dialog)

	_fill_defaults(null)


func _title(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	parent.add_child(l)


func _row(parent: Control, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(170, 0)
	h.add_child(l)
	return h


func _spin_plain(parent: Control, lo: float, hi: float, step: float, value: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(s)
	return s


func _spin_row(parent: Control, key: String, text: String, lo: float, hi: float, step: float) -> void:
	var r := _row(parent, text)
	_spin[key] = _spin_plain(r, lo, hi, step, float(TrackSleeperFactory.GENERATED_DEFAULTS[key]))


func _check(parent: Control, text: String, on: bool) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	parent.add_child(c)
	return c


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# ==========================================
# Состояние
# ==========================================

## Студия вызывает при открытии стиля: размеры генератора берутся из sleeper_size стиля
func refresh_from_style() -> void:
	var style: TrackStyle = studio.get_style() if studio else null
	_fill_defaults(style)


func _fill_defaults(style: TrackStyle) -> void:
	if _spin.is_empty():
		return
	if style:
		(_spin["length"] as SpinBox).value = style.sleeper_size.x
		(_spin["height"] as SpinBox).value = style.sleeper_size.y
		(_spin["width"] as SpinBox).value = style.sleeper_size.z
		_kind_opt.select(1 if not style.ballast_enabled else 0)


func _spec() -> Dictionary:
	var spec := {"kind": KINDS[_kind_opt.selected][1]}
	for k in _spin:
		spec[k] = (_spin[k] as SpinBox).value
	var style: TrackStyle = studio.get_style()
	if style:
		spec["rail_x"] = style.rail_x
	return spec


# ==========================================
# Генератор
# ==========================================

func _on_generate() -> void:
	if studio.get_style() == null:
		return
	_gen_mesh = TrackSleeperFactory.generate(_spec())
	studio.set_field("sleeper_mesh", _gen_mesh)
	var inf := TrackSleeperFactory.info(_gen_mesh)
	studio.say("Шпала сгенерирована: %d треугольников" % inf["triangles"])


func _on_save_generated() -> void:
	if _gen_mesh == null:
		studio.say("Сначала сгенерируйте меш", true)
		return
	_save(_gen_mesh, _gen_name.text.strip_edges())


func _save(mesh: ArrayMesh, nm: String) -> void:
	if not TrackStyleIO.is_valid_id(nm):
		studio.say("Имя файла: латиница в нижнем регистре, цифры, _", true)
		return
	var path := OUT_DIR.path_join(nm + ".res")
	var err := TrackSleeperFactory.save_mesh(mesh, path)
	if err != OK:
		studio.say("Не удалось записать %s (код %d)" % [path, err], true)
		return
	studio.set_field("sleeper_mesh", mesh)
	studio.say("Меш записан: %s" % path)


# ==========================================
# Импорт
# ==========================================

func _on_source_picked(path: String) -> void:
	_src_edit.text = path
	_items = TrackSleeperFactory.load_meshes(path)
	_items_list.clear()
	for it in _items:
		var inf := TrackSleeperFactory.info(it["mesh"])
		var s: Vector3 = inf["size"]
		_items_list.add_item("%s  (%.3f × %.3f × %.3f, %d тр.)" % [it["name"], s.x, s.y, s.z, inf["triangles"]])
	if _items.is_empty():
		_report.text = "[color=#ff7b7b]В файле нет мешей[/color]"
		return
	_items_list.select(0)
	_imp_name.text = _clean_name(path.get_file().get_basename())
	_report.text = "Найдено мешей: %d. Выберите нужные в списке (Ctrl или Shift для нескольких)." % _items.size()


func _clean_name(raw: String) -> String:
	var re := RegEx.new()
	re.compile("[^a-z0-9_]")
	var out := re.sub(raw.to_lower(), "_", true)
	if out.is_empty() or not (out[0] >= "a" and out[0] <= "z"):
		out = "sleeper_" + out
	return out


func _on_normalize(save: bool) -> void:
	if studio.get_style() == null:
		return
	var picked: Array = []
	for i in _items_list.get_selected_items():
		picked.append(_items[i])
	if picked.is_empty():
		studio.say("Выберите меш в списке импорта", true)
		return
	var res := TrackSleeperFactory.normalize(picked, {
		"scale": _scale.value, "rotate_y": _rot.value, "auto_orient": _auto.button_pressed,
		"keep_materials": _keep_mat.button_pressed, "merge": _merge.button_pressed})
	var mesh: ArrayMesh = res["mesh"]
	var rep: Dictionary = res["report"]
	if mesh.get_surface_count() == 0:
		_report.text = "[color=#ff7b7b]Нормализация не дала геометрии[/color]"
		return
	_norm_mesh = mesh
	_show_report(rep, mesh)
	if save:
		_save(mesh, _imp_name.text.strip_edges())
	else:
		studio.set_field("sleeper_mesh", mesh)


func _show_report(rep: Dictionary, mesh: ArrayMesh) -> void:
	var b: AABB = rep["before"]
	var a: AABB = rep["after"]
	var t := "[b]До:[/b] %.3f × %.3f × %.3f\n" % [b.size.x, b.size.y, b.size.z]
	t += "[b]После:[/b] %.3f × %.3f × %.3f, центр опоры (%.3f; %.3f), низ %.3f\n" % [
		a.size.x, a.size.y, a.size.z, a.get_center().x, a.get_center().z, a.position.y]
	t += "Поверхностей %d, треугольников %d\n" % [rep["surfaces"], rep["triangles"]]
	for n in rep["notes"]:
		t += "[color=#ffcf5c]%s[/color]\n" % n
	var has_mat := false
	for i in mesh.get_surface_count():
		if mesh.surface_get_material(i) != null:
			has_mat = true
	if has_mat:
		t += "Материалы меша сохранены. Чтобы они работали, очистите «Материал шпалы» стиля.\n"
	_report.text = t
