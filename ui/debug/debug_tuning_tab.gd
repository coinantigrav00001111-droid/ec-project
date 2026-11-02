class_name DebugTuningTab extends DebugTab

###########################
## Вкладка «Tuning»: настройка выбранного вагона (U14)
###########################
## Строки строятся один раз по WagonTuning.PARAMS. При выборе показываются только те, что есть у цели
## (у вагона без мотора нет группы «Мотор»). Кнопка «R» у строки и «Вернуть все» возвращают значения на момент
## выбора вагона: так можно крутить ручки и вернуться, не перезагружая макет.
## Значения живут в компонентах вагона и не сохраняются в макет: это отладка, а не настройка паспорта.

## Строки: key -> {control, kind, nodes: Array[Control], group}
var _rows: Dictionary = {}
## Группы: id -> {header, grid}
var _groups: Dictionary = {}
## Значения на момент выбора вагона
var _baseline: Dictionary = {}

var _title: Label
var _hint: Label
var _body: VBoxContainer


func _init() -> void:
	name = &"Tuning"
	_title = Label.new()
	_title.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
	add_child(_title)
	_hint = make_note("Выберите вагон в режиме Select. Здесь меняются параметры подвески, кинематики, тела и мотора.")
	add_child(_hint)

	_body = VBoxContainer.new()
	add_child(_body)

	var reset_all := Button.new()
	reset_all.text = "Вернуть все (как при выборе)"
	reset_all.pressed.connect(_reset_all)
	_body.add_child(reset_all)

	for g in WagonTuning.GROUPS:
		var header := make_header(g.title)
		_body.add_child(header)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override(&"h_separation", 6)
		_body.add_child(grid)
		_groups[g.id] = {"header": header, "grid": grid}

	for p in WagonTuning.PARAMS:
		_add_row(p)
	_body.hide()


func _add_row(p: Dictionary) -> void:
	var grid: GridContainer = _groups[p.group].grid
	var label := Label.new()
	label.text = p.label
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_PASS   # без этого тултип на подписи не покажется
	if p.has("tip"):
		label.tooltip_text = p.tip
	grid.add_child(label)

	var key: String = p.key
	var control: Control
	if p.kind == WagonTuning.Kind.TOGGLE:
		var cb := CheckBox.new()
		cb.size_flags_horizontal = Control.SIZE_SHRINK_END
		cb.toggled.connect(func(on: bool) -> void: WagonTuning.write(target, key, on))
		control = cb
	else:
		var spin := make_spin(p.min, p.max, p.step)
		spin.value_changed.connect(func(v: float) -> void: WagonTuning.write(target, key, v))
		control = spin
	grid.add_child(control)

	var reset := Button.new()
	reset.text = "R"
	reset.flat = true
	reset.tooltip_text = "Вернуть значение, которое было при выборе вагона"
	reset.pressed.connect(func() -> void: _reset_one(key))
	grid.add_child(reset)

	_rows[key] = {"control": control, "kind": p.kind, "nodes": [label, control, reset], "group": p.group}


func _on_bind() -> void:
	_baseline.clear()
	var wagon := WagonTuning.is_wagon(target)
	_body.visible = wagon
	_hint.visible = not wagon
	if not wagon:
		_title.text = "Нет вагона" if target == null else "%s: не вагон" % target.name
		return
	_title.text = str(target.name)
	_baseline = WagonTuning.snapshot(target)
	# Показываем только ручки, которые есть у цели
	var shown := {}
	for key in _rows:
		var row: Dictionary = _rows[key]
		var has_it := _baseline.has(key)
		for n: Control in row.nodes:
			n.visible = has_it
		if has_it:
			shown[row.group] = true
	for gid in _groups:
		_groups[gid].header.visible = shown.has(gid)
		_groups[gid].grid.visible = shown.has(gid)
	_fill_controls(true)


func refresh() -> void:
	if not WagonTuning.is_wagon(target):
		# Вагон удалили, пока он был выбран
		if _body.visible:
			_on_bind()
		return
	_fill_controls(false)


## Читает значения из вагона в контролы (без сигналов; поле в фокусе не трогаем)
func _fill_controls(force: bool) -> void:
	for key in _rows:
		var row: Dictionary = _rows[key]
		if not _baseline.has(key):
			continue
		var v: Variant = WagonTuning.read(target, key)
		if v == null:
			continue
		if row.kind == WagonTuning.Kind.TOGGLE:
			(row.control as CheckBox).set_pressed_no_signal(bool(v))
		elif force:
			(row.control as SpinBox).set_value_no_signal(float(v))
		else:
			set_spin(row.control as SpinBox, float(v))


func _reset_one(key: String) -> void:
	if not _baseline.has(key) or not WagonTuning.is_wagon(target):
		return
	WagonTuning.write(target, key, _baseline[key])
	_fill_controls(true)


func _reset_all() -> void:
	if not WagonTuning.is_wagon(target):
		return
	WagonTuning.restore(target, _baseline)
	_fill_controls(true)
