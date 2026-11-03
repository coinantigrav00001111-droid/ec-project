class_name LibraryScreen extends Control

# XX claude-library (новый файл)
########################
## LibraryScreen. Экран Library (Model Studio), ATTN_22 §22.5, шаг L1
########################
## Одно окно, один 3D-мир (StudioWorld, как в Icon Studio) и сменные рабочие области справа. Интерфейс собирается кодом.
## Два способа запуска:
##   - оверлей поверх игры (ModeController): дерево на паузе, 3D главного вьюпорта выключено на время;
##   - отдельно (F6 на library_screen.tscn): окно как у студий, без паузы, кнопки «Назад» нет.
## Объект показывает StudioWorld через EntityFactory (как в игре), в своём World3D.
## При закрытии объект убирается через kill_me (снимает регистрацию в PGM), пауза и 3D возвращаются.

signal closed

const StudioWorld := preload("res://core/library/icon_studio/studio_world.gd")
const StudioSettings := preload("res://core/library/icon_studio/studio_settings.gd")
const StageClean := preload("res://core/library/stage/stage_clean.gd")
const Overview := preload("res://core/library/workspace/overview.gd")

const SETTINGS_PATH := "user://library.cfg"
## Кадров «settle» после создания объекта (как DEFAULT_SETTLE в Icon Studio)
const SETTLE_FRAMES := 2
## Выключать 3D главного вьюпорта, пока открыт экран (в игре под экраном рисовать нечего)
const DISABLE_GAME_3D := true
## Что показывает коллекция (порядок категорий). Terrain это инструменты, а не модели
const COLLECTION_CATEGORIES: Array[StringName] = [&"train", &"building", &"track", &"decor"]
## Области экрана: id, название, включена ли (остальные включаются шагами L3 и дальше)
const WORKSPACE_TABS := [
	[&"overview", "Осмотр", true],
	[&"paint", "Покраска", false],
	[&"parts", "Детали", false],
	[&"fit", "Свет", false],
	[&"test", "Стенд", false],
	[&"building", "Здания", false],
	[&"kit", "Сборка", false],
	[&"restore", "Реставрация", false],
]
const HINT_TEXT := "ЛКМ: вращать   ·   Shift+ЛКМ, СКМ, ПКМ: сдвиг   ·   колесо: зум   ·   F: вписать   ·   Esc: назад"

var rules: LibraryRules
var profile: LibraryProfile
var settings: StudioSettings
var world: StudioWorld
var stage: LibraryStage
var workspace: LibraryWorkspace

var _embedded := false
var _prev_paused := false
var _prev_disable_3d: Variant = false
var _vp: Viewport
var _viewport: SubViewport
var _view_area: PanelContainer
var _tree: Tree
var _right_box: VBoxContainer
var _rules_label: Label
var _items := {}          # key -> TreeItem
var _current: EntitySetting
var _closing := false


func _ready() -> void:
	_embedded = get_tree().current_scene != self
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP

	settings = StudioSettings.new()
	settings.name = "StudioSettings"
	settings.path = SETTINGS_PATH
	add_child(settings)
	if not _embedded:
		settings.restore_window()
		get_window().title = "Library · Model Studio"

	profile = VariantIO.load_profile()
	rules = LibraryRules.from_dict(profile.rules) if not profile.rules.is_empty() else LibraryRules.make(LibraryRules.Source.SANDBOX, LibraryRules.Preset.STANDARD)

	_build_ui()
	_build_world()
	_populate()
	_set_workspace(Overview.new())
	_enter_overlay_state()

	# Размеры контейнеров известны только после первого кадра раскладки
	await get_tree().process_frame
	_select_last()


func _exit_tree() -> void:
	if settings:
		settings.flush()
	_leave_overlay_state()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and settings:
		settings.flush()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_F:
		world.fit()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_ESCAPE and _embedded:
		close()
		get_viewport().set_input_as_handled()


## Закрыть экран (в оверлее). Область может отказать, если у неё несохранённая работа
func close() -> void:
	if not _embedded or _closing:
		return
	if workspace != null and not workspace.can_leave():
		return
	_closing = true
	if workspace != null:
		workspace.exit()
	# kill_me снимает регистрацию объекта в PGM; просто освободить дерево недостаточно
	world.clear_subject()
	closed.emit()
	queue_free()


# ==========================================
# ОВЕРЛЕЙ: ПАУЗА И 3D ИГРЫ
# ==========================================

func _enter_overlay_state() -> void:
	if not _embedded:
		return
	_prev_paused = get_tree().paused
	get_tree().paused = true
	_vp = get_viewport()
	if DISABLE_GAME_3D and _vp != null:
		_prev_disable_3d = _vp.get("disable_3d")
		_vp.set("disable_3d", true)


func _leave_overlay_state() -> void:
	if not _embedded:
		return
	if DISABLE_GAME_3D and _vp != null and is_instance_valid(_vp):
		_vp.set("disable_3d", _prev_disable_3d)
	var tree := get_tree()
	if tree != null:
		tree.paused = _prev_paused


# ==========================================
# ИНТЕРФЕЙС
# ==========================================

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.1)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)
	root.add_child(_build_header())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	root.add_child(body)
	body.add_child(_build_left())
	body.add_child(_build_center())
	body.add_child(_build_right())

	var hint := Label.new()
	hint.text = HINT_TEXT
	hint.modulate = Color(1, 1, 1, 0.6)
	root.add_child(hint)


func _build_header() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)

	if _embedded:
		var back := Button.new()
		back.text = "← Назад"
		back.pressed.connect(close)
		h.add_child(back)

	var title := Label.new()
	title.text = "LIBRARY · Model Studio"
	h.add_child(title)

	var group := ButtonGroup.new()
	for t in WORKSPACE_TABS:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.button_group = group
		b.disabled = not t[2]
		b.button_pressed = t[0] == &"overview"
		if b.disabled:
			b.tooltip_text = "Включится в следующих шагах (ATTN_22 §22.9)"
		h.add_child(b)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)

	_rules_label = Label.new()
	_rules_label.text = "Правила: " + rules.label()
	h.add_child(_rules_label)
	if Global.debug_mode:
		var cycle := Button.new()
		cycle.text = "Правила ⟳"
		cycle.tooltip_text = "Отладка: переключить источник (песочница, кампания) и пресет сложности"
		cycle.pressed.connect(_on_cycle_rules)
		h.add_child(cycle)
	return h


func _build_left() -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(260, 0)
	var v := VBoxContainer.new()
	p.add_child(v)
	var l := Label.new()
	l.text = "Каталог"
	v.add_child(l)
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_item_selected)
	v.add_child(_tree)
	return p


func _build_center() -> Control:
	_view_area = PanelContainer.new()
	_view_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view_area.custom_minimum_size = Vector2(320, 240)
	_view_area.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.11)
	_view_area.add_theme_stylebox_override("panel", bg)
	return _view_area


func _build_right() -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(320, 0)
	_right_box = VBoxContainer.new()
	p.add_child(_right_box)
	return p


# ==========================================
# 3D-МИР
# ==========================================

func _build_world() -> void:
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view_area.add_child(svc)

	# Отдельный World3D: объекты Library не видны игре и не видят её (в том числе физика)
	var studio_world3d := World3D.new()
	_viewport = SubViewport.new()
	_viewport.world_3d = studio_world3d
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.handle_input_locally = false
	svc.add_child(_viewport)

	world = StudioWorld.new()
	world.name = "StudioWorld"
	_viewport.add_child(world)
	_view_area.gui_input.connect(world.handle_gui_input)
	var views: Array[SubViewport] = [_viewport]
	world.register_views(views, null)

	stage = StageClean.new()
	stage.apply(world)


# ==========================================
# КАТАЛОГ
# ==========================================

func _populate() -> void:
	_tree.clear()
	_items.clear()
	var root := _tree.create_item()
	# категория -> тег -> Array[EntitySetting]
	var by_cat := {}
	for s in EntityCatalogProvider.load_all():
		if s.hide or not COLLECTION_CATEGORIES.has(s.category):
			continue
		if not by_cat.has(s.category):
			by_cat[s.category] = {}
		var tags: Dictionary = by_cat[s.category]
		if not tags.has(s.tag):
			tags[s.tag] = []
		(tags[s.tag] as Array).append(s)

	for cat in COLLECTION_CATEGORIES:
		if not by_cat.has(cat):
			continue
		var cat_item := _tree.create_item(root)
		cat_item.set_text(0, str((CatalogMeta.CATEGORIES.get(cat, {}) as Dictionary).get("name", cat)))
		cat_item.set_selectable(0, false)
		var tags: Dictionary = by_cat[cat]
		for tag in CatalogMeta.sort_tags(cat, tags.keys()):
			var tag_item := _tree.create_item(cat_item)
			tag_item.set_text(0, str(tag))
			tag_item.set_selectable(0, false)
			var list: Array = tags[tag]
			list.sort_custom(_sort_objects)
			for s in list:
				var it := _tree.create_item(tag_item)
				it.set_text(0, _title_of(s))
				it.set_metadata(0, s)
				_items[s.get_key()] = it


static func _sort_objects(a: EntitySetting, b: EntitySetting) -> bool:
	if a.sort_order != b.sort_order:
		return a.sort_order < b.sort_order
	return a.resource_path.get_file() < b.resource_path.get_file()


static func _title_of(s: EntitySetting) -> String:
	return s.name if s.name != "" else String(s.get_key())


func _on_item_selected() -> void:
	var it := _tree.get_selected()
	if it == null:
		return
	var s := it.get_metadata(0) as EntitySetting
	if s != null:
		_show_object(s)


func _select_last() -> void:
	var last := str(settings.get_value("state", "last_key", ""))
	var it: TreeItem = null
	if last != "" and _items.has(StringName(last)):
		it = _items[StringName(last)]
	elif not _items.is_empty():
		it = _items.values()[0]
	if it == null:
		return
	it.select(0)
	_tree.scroll_to_item(it)
	_show_object(it.get_metadata(0) as EntitySetting)


func _show_object(s: EntitySetting) -> void:
	if s == _current:
		return
	_current = s
	settings.set_value("state", "last_key", String(s.get_key()))
	if workspace != null:
		workspace.on_loading(s)
	var t0 := Time.get_ticks_msec()
	var info: Dictionary = await world.set_subject(s, StudioWorld.SOURCE_ENTITY, SETTLE_FRAMES)
	if info.stale or s != _current or _closing:
		return
	if info.ok:
		world.fit()
	if workspace != null:
		workspace.on_subject(s, info, Time.get_ticks_msec() - t0)


# ==========================================
# ОБЛАСТИ И ПРАВИЛА
# ==========================================

func _set_workspace(ws: LibraryWorkspace) -> void:
	if workspace != null:
		workspace.exit()
		_right_box.remove_child(workspace)
		workspace.queue_free()
	workspace = ws
	workspace.setup(self)
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_box.add_child(workspace)
	workspace.enter()


func _on_cycle_rules() -> void:
	rules.cycle_debug()
	_rules_label.text = "Правила: " + rules.label()
	profile.rules = rules.to_dict()
	VariantIO.save_profile(profile)
