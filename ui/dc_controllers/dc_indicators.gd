class_name DCIndicators extends VBoxContainer

########################
## Индикаторы пульта (ATTN_10 D3): лампы «Сеть», «Перегрузка», «КЗ», полоса тока, «Сброс», кнопка «Сеть»
########################
## Строится кодом и вешается под панель (сцены панелей не правятся). Читает PowerSource панели,
## обновляется по сигналам PGM (шаг решателя 10 Гц, события защиты, загрузка). Состояние не только цветом:
## у каждой лампы есть слово, у включенной знак ●, у выключенной ○.

const COL_OK := Color(0.0, 0.824, 0.0, 1.0)
const COL_WARN := Color(1.0, 0.75, 0.1, 1.0)
const COL_BAD := Color(1.0, 0.25, 0.2, 1.0)
const COL_OFF := Color(0.6, 0.6, 0.6, 1.0)

var source: PowerSource

var _model: Label
var _lamp_mains: Label
var _lamp_over: Label
var _lamp_short: Label
var _bar: ProgressBar
var _bar_label: Label
var _mains_btn: CheckButton
var _reset_btn: Button


func setup(src: PowerSource, panel_width: float) -> void:
	source = src
	name = "DCIndicators"
	custom_minimum_size = Vector2(panel_width, 0)
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_PASS

	_model = Label.new()
	_model.add_theme_font_size_override("font_size", 11)
	add_child(_model)

	var lamps := HBoxContainer.new()
	lamps.add_theme_constant_override("separation", 10)
	add_child(lamps)
	_lamp_mains = _make_lamp(lamps)
	_lamp_over = _make_lamp(lamps)
	_lamp_short = _make_lamp(lamps)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 8)
	add_child(_bar)
	_bar_label = Label.new()
	_bar_label.add_theme_font_size_override("font_size", 11)
	add_child(_bar_label)

	var btns := HBoxContainer.new()
	add_child(btns)
	_mains_btn = CheckButton.new()
	_mains_btn.text = "Сеть"
	_mains_btn.toggled.connect(_on_mains_toggled)
	btns.add_child(_mains_btn)
	_reset_btn = Button.new()
	_reset_btn.text = "Сброс"
	_reset_btn.pressed.connect(_on_reset_pressed)
	btns.add_child(_reset_btn)

	PGM.solver_stepped.connect(refresh)
	PGM.output_event.connect(_on_output_event)
	PGM.power_updated.connect(_on_power_updated)
	PGM.state_loaded.connect(refresh)
	PGM.state_reset.connect(refresh)
	refresh()


func _on_output_event(_label: int, _kind: String, _reason: String) -> void:
	refresh()


func _on_power_updated(_label: int, _voltage: float) -> void:
	refresh()


func _make_lamp(parent: Control) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 12)
	parent.add_child(l)
	return l


## Выводы, по которым показываем ток: выбранный на пульте, при «все» это самый нагруженный
func shown_output() -> PowerOutput:
	if source == null or source.outputs.is_empty():
		return null
	if source.selected > 0:
		var o := source.output_by_label(source.selected)
		if o != null:
			return o
	var best: PowerOutput = source.outputs[0]
	for o in source.outputs:
		if o.current > best.current:
			best = o
	return best


func refresh() -> void:
	if source == null or not is_instance_valid(_model):
		return
	var md := source.data()
	_model.text = "%s · лимит %.1f А" % [String(md.name), float(md.i_max)]

	var needs := source.needs_supply()
	var net_ok: bool = (not needs) or PGM.mains.on
	_set_lamp(_lamp_mains, "Сеть", net_ok, COL_OK)
	if not net_ok:
		_lamp_mains.modulate = COL_BAD   # сеть выключена: красный, знак ○ и слово остаются

	var over := false
	var short := false
	var any_tripped := false
	for o in source.outputs:
		if o.tripped:
			any_tripped = true
			if o.trip_reason == "overload":
				over = true
			else:
				short = true
		elif o.state == PowerOutput.State.OVERLOAD:
			over = true
	_set_lamp(_lamp_over, "Перегрузка", over, COL_WARN if not any_tripped else COL_BAD)
	_set_lamp(_lamp_short, "КЗ", short, COL_BAD)

	var out := shown_output()
	if out != null:
		_bar.max_value = out.i_max * 2.0
		_bar.value = out.current
		_bar_label.text = "Вывод %d: %.2f А из %.1f А%s" % [out.label, out.current, out.i_max, ("  · " + out.state_text() if out.state != PowerOutput.State.OK else "")]
	_mains_btn.visible = needs
	_mains_btn.set_pressed_no_signal(PGM.mains.on)
	_reset_btn.disabled = not any_tripped


func _set_lamp(l: Label, text: String, on: bool, col: Color) -> void:
	l.text = ("● " if on else "○ ") + text
	l.modulate = col if on else COL_OFF


func _on_mains_toggled(on: bool) -> void:
	PGM.set_mains(on)


func _on_reset_pressed() -> void:
	PGM.reset_protection(source)
