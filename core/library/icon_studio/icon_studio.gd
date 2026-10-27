extends Control

########################
## Icon Studio (ATTN_18). Прототип режима Library.
########################
## Запуск: открыть icon_studio.tscn и нажать F6 (Run Current Scene).
## Шаги I0 (каркас, окно, настройки, сброс) и I1 (список объектов, объект в мире, камера).
## Интерфейс собирается кодом, чтобы не плодить правки в .tscn.

const StudioSettings := preload("res://core/library/icon_studio/studio_settings.gd")
const StudioWorld := preload("res://core/library/icon_studio/studio_world.gd")

const DEFAULT_SETTLE := 2
const LAST_OBJECT_KEY := "last_object"

var settings: StudioSettings
var world: StudioWorld

var _all: Array[EntitySetting] = []
var _current: EntitySetting
var _building_tree := false

var _split_left: HSplitContainer
var _split_right: HSplitContainer
var _search: LineEdit
var _tree: Tree
var _source: OptionButton
var _settle: SpinBox
var _auto_fit: CheckBox
var _ortho: CheckBox
var _info: Label
var _viewport: SubViewport
var _reset_dialog: ConfirmationDialog


func _ready() -> void:
	settings = StudioSettings.new()
	settings.name = "StudioSettings"
	add_child(settings)
	settings.restore_window()
	get_window().title = "Icon Studio"

	_build_ui()
	_load_objects()
	_apply_saved_ui()
	_rebuild_tree()
	# Размеры контейнеров известны только после первого кадра раскладки
	await get_tree().process_frame
	_select_last_object()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and settings:
		settings.flush()


func _exit_tree() -> void:
	if settings:
		settings.flush()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F:
		world.fit()
		get_viewport().set_input_as_handled()


# ==========================================
# ИНТЕРФЕЙС
# ==========================================

func _build_ui() -> void:
	_split_left = HSplitContainer.new()
	_split_left.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_split_left)
	_split_left.dragged.connect(func(off: int): settings.set_value("ui", "split_left", off))

	# --- Левая панель: список объектов ---
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	_split_left.add_child(left)
	var lv := VBoxContainer.new()
	left.add_child(lv)

	var title := Label.new()
	title.text = "Объекты игры"
	lv.add_child(title)

	_search = LineEdit.new()
	_search.placeholder_text = "Поиск по имени и описанию"
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t: String): _rebuild_tree())
	lv.add_child(_search)

	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.item_selected.connect(_on_tree_selected)
	lv.add_child(_tree)

	var src_row := HBoxContainer.new()
	lv.add_child(src_row)
	var src_label := Label.new()
	src_label.text = "Источник"
	src_row.add_child(src_label)
	_source = OptionButton.new()
	_source.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source.add_item("Entity (как в игре)", StudioWorld.SOURCE_ENTITY)
	_source.add_item("Только сцена (запасной)", StudioWorld.SOURCE_SCENE)
	_source.item_selected.connect(func(i: int):
		settings.set_value("ui", "source", i)
		_reload_current())
	src_row.add_child(_source)

	var settle_row := HBoxContainer.new()
	lv.add_child(settle_row)
	var settle_label := Label.new()
	settle_label.text = "Кадров «settle»"
	settle_label.tooltip_text = "Сколько кадров объект живёт после создания, чтобы построились меши. Потом обработка отключается."
	settle_row.add_child(settle_label)
	_settle = SpinBox.new()
	_settle.min_value = 0
	_settle.max_value = 10
	_settle.value = DEFAULT_SETTLE
	_settle.value_changed.connect(func(v: float):
		settings.set_value("ui", "settle", int(v))
		_reload_current())
	settle_row.add_child(_settle)

	# --- Центр: вид мира ---
	_split_right = HSplitContainer.new()
	_split_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split_left.add_child(_split_right)
	_split_right.dragged.connect(func(off: int): settings.set_value("ui", "split_right", off))

	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svc.custom_minimum_size = Vector2(320, 240)
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	_split_right.add_child(svc)

	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.handle_input_locally = false
	svc.add_child(_viewport)

	world = StudioWorld.new()
	world.name = "StudioWorld"
	_viewport.add_child(world)
	svc.gui_input.connect(world.handle_gui_input)
	world.camera_changed.connect(_on_camera_changed)

	# --- Правая панель: информация и кнопки ---
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(260, 0)
	_split_right.add_child(right)
	var rv := VBoxContainer.new()
	right.add_child(rv)

	var rt := Label.new()
	rt.text = "Объект"
	rv.add_child(rt)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info.text = "Выберите объект в списке."
	rv.add_child(_info)

	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "ЛКМ: орбита. СКМ, ПКМ или Shift+ЛКМ: сдвиг. Колесо: зум. F: вписать объект."
	rv.add_child(hint)

	_ortho = CheckBox.new()
	_ortho.text = "Ортогональная проекция"
	_ortho.toggled.connect(func(on: bool): world.set_ortho(on))
	rv.add_child(_ortho)

	_auto_fit = CheckBox.new()
	_auto_fit.text = "Вписывать при смене объекта"
	_auto_fit.button_pressed = true
	_auto_fit.toggled.connect(func(on: bool): settings.set_value("ui", "auto_fit", on))
	rv.add_child(_auto_fit)

	var fit_btn := Button.new()
	fit_btn.text = "Вписать (F)"
	fit_btn.pressed.connect(func(): world.fit())
	rv.add_child(fit_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Сброс…"
	reset_btn.pressed.connect(func(): _reset_dialog.popup_centered())
	rv.add_child(reset_btn)

	# --- Диалог сброса ---
	_reset_dialog = ConfirmationDialog.new()
	_reset_dialog.title = "Сброс"
	_reset_dialog.dialog_text = "Что сбросить?\n«Всё»: окно, панели, камера и настройки списка вернутся к умолчанию."
	_reset_dialog.ok_button_text = "Сбросить всё"
	_reset_dialog.cancel_button_text = "Отмена"
	_reset_dialog.add_button("Только вид камеры", true, "camera")
	_reset_dialog.confirmed.connect(_reset_all)
	_reset_dialog.custom_action.connect(func(action: StringName):
		_reset_dialog.hide()
		if action == &"camera":
			_reset_camera())
	add_child(_reset_dialog)


## Подставляет сохранённые значения в элементы (сигналы при этом не должны писать лишнее)
func _apply_saved_ui() -> void:
	_split_left.split_offset = int(settings.get_value("ui", "split_left", 0))
	_split_right.split_offset = int(settings.get_value("ui", "split_right", 0))
	_source.select(clampi(int(settings.get_value("ui", "source", 0)), 0, _source.item_count - 1))
	_settle.set_value_no_signal(int(settings.get_value("ui", "settle", DEFAULT_SETTLE)))
	_auto_fit.set_pressed_no_signal(bool(settings.get_value("ui", "auto_fit", true)))
	var cam: Variant = settings.get_value("camera", "state", {})
	if cam is Dictionary:
		world.set_camera_state(cam)
	_ortho.set_pressed_no_signal(world.ortho)


# ==========================================
# СПИСОК ОБЪЕКТОВ
# ==========================================

func _load_objects() -> void:
	_all.clear()
	for dir in Global.object_dirs:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".tres"):
				continue
			var res := load(dir + file)
			if res is EntitySetting:
				_all.append(res)
	_all.sort_custom(func(a: EntitySetting, b: EntitySetting) -> bool:
		if a.category != b.category:
			return String(a.category) < String(b.category)
		if a.tag != b.tag:
			return String(a.tag) < String(b.tag)
		return a.id < b.id)


func _rebuild_tree() -> void:
	_building_tree = true
	_tree.clear()
	var root := _tree.create_item()
	var f := _search.text.strip_edges().to_lower()
	var cats := {}
	var tags := {}
	var current_item: TreeItem = null
	for s in _all:
		if f != "" and not (s.name.to_lower().contains(f) or s.description.to_lower().contains(f)):
			continue
		var cat_key := String(s.category)
		if not cats.has(cat_key):
			var ci := _tree.create_item(root)
			ci.set_text(0, cat_key)
			ci.set_selectable(0, false)
			cats[cat_key] = ci
		var tag_key := cat_key + "/" + String(s.tag)
		if not tags.has(tag_key):
			var ti := _tree.create_item(cats[cat_key])
			ti.set_text(0, String(s.tag))
			ti.set_selectable(0, false)
			tags[tag_key] = ti
		var it := _tree.create_item(tags[tag_key])
		it.set_text(0, "%s  %s" % [s.name, s.description])
		it.set_metadata(0, s)
		if s.icon:
			it.set_icon(0, s.icon)
			it.set_icon_max_width(0, 24)
		if s == _current:
			current_item = it
	if current_item:
		current_item.select(0)
	_building_tree = false


func _on_tree_selected() -> void:
	if _building_tree:
		return
	var it := _tree.get_selected()
	if it == null:
		return
	var s: Variant = it.get_metadata(0)
	if s is EntitySetting:
		_show_object(s)


func _select_last_object() -> void:
	var path := String(settings.get_value("state", LAST_OBJECT_KEY, ""))
	for s in _all:
		if s.resource_path == path:
			_current = s
			_rebuild_tree()   # выделяет _current в списке
			_show_object(s, true)
			return
	if not _all.is_empty():
		_info.text = "Выберите объект в списке."


# ==========================================
# ОБЪЕКТ И КАМЕРА
# ==========================================

func _reload_current() -> void:
	if _current:
		_show_object(_current, true)


func _show_object(s: EntitySetting, force := false) -> void:
	if not force and s == _current:
		return
	_current = s
	settings.set_value("state", LAST_OBJECT_KEY, s.resource_path)
	_info.text = "Загрузка: %s ..." % s.name
	var t0 := Time.get_ticks_msec()
	var info: Dictionary = await world.set_subject(s, _source.get_selected_id(), int(_settle.value))
	if info.stale or s != _current:
		return
	if info.ok and _auto_fit.button_pressed:
		world.fit()
	_show_info(s, info, Time.get_ticks_msec() - t0)


func _show_info(s: EntitySetting, info: Dictionary, ms: int) -> void:
	var lines: Array[String] = []
	lines.append("%s (id %d)" % [s.name, s.id])
	lines.append("%s / %s" % [s.category, s.tag])
	lines.append("Источник: %s, %d мс" % [info.via, ms])
	if info.ok:
		var a: AABB = info.aabb
		lines.append("Мешей: %d" % info.meshes)
		lines.append("Размер: %.2f × %.2f × %.2f" % [a.size.x, a.size.y, a.size.z])
	if info.warn != "":
		lines.append("Внимание: " + info.warn)
	if info.error != "":
		lines.append("Ошибка: " + info.error)
	_info.text = "\n".join(lines)


func _on_camera_changed() -> void:
	settings.set_value("camera", "state", world.get_camera_state())


func _reset_camera() -> void:
	world.set_camera_state({"yaw": 35.0, "pitch": -25.0, "fov": 30.0, "ortho": false})
	_ortho.set_pressed_no_signal(false)
	world.fit()
	_on_camera_changed()


func _reset_all() -> void:
	settings.reset_all()
	settings.reset_window()
	_split_left.split_offset = 0
	_split_right.split_offset = 0
	_source.select(0)
	_settle.set_value_no_signal(DEFAULT_SETTLE)
	_auto_fit.set_pressed_no_signal(true)
	_search.text = ""
	_reset_camera()
	_rebuild_tree()
	settings.flush()
	_reload_current()
