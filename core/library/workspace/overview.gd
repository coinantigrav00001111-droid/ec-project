extends "res://core/library/workspace/workspace.gd"

# XX claude-library (новый файл)
########################
## Осмотр: паспорт модели, габариты, ракурсы, автовращение (ATTN_22 §22.7.1, шаг L2)
########################
## Паспорт берётся из ModelInfo (res://data/library/info/<key>.tres); без паспорта показываются имя, key и габариты.
## Закрытая модель показывается силуэтом (его рисует экран) и условием открытия.
## Слоты ракурсов: клик переходит, Shift+клик или Shift+1..6 сохраняет текущий (как в Icon Studio). Хранятся в
## user://library.cfg. Автовращение крутит камеру вокруг модели; выключается при переходе к слоту.

const TURN_SPEED := 20.0     ## градусов в секунду

var _title: Label
var _sub: Label
var _lock: Label
var _proto: Label
var _scale: Label
var _dims: Label
var _story: Label
var _tech: Label
var _status: Label
var _slot_buttons: Array[Button] = []
var _turn_check: CheckBox
var _slots: Array = []
var _turn := false


func _init() -> void:
	id = &"overview"
	title = "Осмотр"


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var card := VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", 6)
	scroll.add_child(card)

	_title = _make_label(card, 18)
	_title.text = "Осмотр"
	_sub = _make_label(card, 0, true)
	_lock = _make_label(card)
	_lock.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
	_lock.visible = false
	card.add_child(HSeparator.new())
	_proto = _make_label(card)
	_scale = _make_label(card)
	_dims = _make_label(card)
	_story = _make_label(card)
	_tech = _make_label(card, 0, true)
	_tech.visible = false
	_proto.text = "Выберите объект в каталоге слева."

	add_child(HSeparator.new())
	var hdr := Label.new()
	hdr.text = "Ракурсы"
	add_child(hdr)
	var row := HBoxContainer.new()
	add_child(row)
	for i in ViewSlots.COUNT:
		var b := Button.new()
		b.text = str(i + 1)
		b.custom_minimum_size = Vector2(36, 0)
		b.tooltip_text = "Ракурс %d. Shift+клик (Shift+%d): сохранить текущий ракурс в слот" % [i + 1, i + 1]
		b.pressed.connect(_on_slot.bind(i))
		row.add_child(b)
		_slot_buttons.append(b)
	var row2 := HBoxContainer.new()
	add_child(row2)
	_turn_check = CheckBox.new()
	_turn_check.text = "Автовращение"
	_turn_check.toggled.connect(_on_turn_toggled)
	row2.add_child(_turn_check)
	var fit := Button.new()
	fit.text = "Вписать (F)"
	fit.pressed.connect(func() -> void: screen.world.fit())
	row2.add_child(fit)
	_status = _make_label(self, 0, true)
	set_process(false)


func enter() -> void:
	_slots = ViewSlots.sanitize(screen.settings.get_value("view", "slots", null))
	_apply_turn(bool(screen.settings.get_value("view", "turntable", false)))


func exit() -> void:
	set_process(false)


func _process(delta: float) -> void:
	var w = screen.world
	if w != null:
		w.set_view(w.yaw + TURN_SPEED * delta, w.pitch)


func handle_key(event: InputEventKey) -> bool:
	if event.keycode >= KEY_1 and event.keycode < KEY_1 + ViewSlots.COUNT:
		_on_slot(event.keycode - KEY_1)
		return true
	return false


func on_loading(setting: EntitySetting) -> void:
	_title.text = "Загрузка: %s ..." % setting.name
	_lock.visible = false


func on_subject(setting: EntitySetting, info: Dictionary, ms: int) -> void:
	var key := setting.get_key()
	var passport := ModelInfo.find(key)
	var open := ModelAccess.is_open(screen.rules, screen.profile, key, passport)
	var heading := setting.name if setting.name != "" else String(key)
	if passport != null and passport.title != "":
		heading = passport.title
	_title.text = heading
	_sub.text = "%s · %s / %s" % [key, setting.category, setting.tag]

	_lock.visible = not open
	if not open:
		_lock.text = ("Закрыто. " + ModelAccess.condition_text(passport)).strip_edges()

	var proto_line := passport.prototype_line() if passport != null else ""
	_proto.text = ("Прототип: " + proto_line) if proto_line != "" else "Данные о прототипе не внесены."
	_scale.visible = passport != null and passport.scale_note != ""
	if _scale.visible:
		_scale.text = "Масштаб: " + passport.scale_note
	_story.visible = passport != null and passport.story != ""
	if _story.visible:
		_story.text = passport.story

	if info.get("ok", false):
		var a: AABB = info.aabb
		_dims.text = "Габариты (ю): %.2f × %.2f × %.2f\n≈ %.1f × %.1f × %.1f м прототипа (ориентир: 1 ю около 1 м)" % [
			a.size.x, a.size.y, a.size.z,
			ModelInfo.prototype_meters(a.size.x), ModelInfo.prototype_meters(a.size.y), ModelInfo.prototype_meters(a.size.z)]
	else:
		_dims.text = "Габариты не определены."

	var tech: Array[String] = []
	if Global.debug_mode:
		tech.append("Источник: %s, %d мс, мешей: %d" % [info.get("via", ""), ms, int(info.get("meshes", 0))])
	if str(info.get("warn", "")) != "":
		tech.append("Внимание: " + str(info.warn))
	if str(info.get("error", "")) != "":
		tech.append("Ошибка: " + str(info.error))
	_tech.visible = not tech.is_empty()
	_tech.text = "\n".join(tech)


# ==========================================
# РАКУРСЫ И ВРАЩЕНИЕ
# ==========================================

func _on_slot(i: int) -> void:
	var w = screen.world
	if w == null or i < 0 or i >= _slots.size():
		return
	if Input.is_key_pressed(KEY_SHIFT):
		_slots[i] = w.capture_slot()
		screen.settings.set_value("view", "slots", _slots)
		_status.text = "Ракурс сохранён в слот %d" % (i + 1)
	else:
		_apply_turn(false)
		screen.settings.set_value("view", "turntable", false)
		w.go_slot(_slots[i], true)
		_status.text = ""


func _on_turn_toggled(on: bool) -> void:
	_apply_turn(on)
	screen.settings.set_value("view", "turntable", on)


func _apply_turn(on: bool) -> void:
	_turn = on
	_turn_check.set_pressed_no_signal(on)
	set_process(on)


func _make_label(parent: Node, font_size := 0, muted := false) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	if muted:
		l.modulate = Color(1, 1, 1, 0.6)
	parent.add_child(l)
	return l
