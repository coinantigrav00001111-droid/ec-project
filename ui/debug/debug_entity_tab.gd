class_name DebugEntityTab extends DebugTab

###########################
## Вкладка «Entity»: список компонентов выбранного объекта (U14)
###########################
## Бывший EntityDebugger. Раньше он каждые 0.5 с пересоздавал все Label; теперь текст собирается одной
## строкой и присваивается, только если он изменился (прокрутка и выделение не сбрасываются).

const REBUILD_MSEC := 500

var _tool_controller: ToolController
var _text: RichTextLabel
var _props: CheckBox
var _last_msec := 0


func _init() -> void:
	name = &"Entity"
	_props = CheckBox.new()
	_props.text = "Показывать свойства компонентов"
	_props.toggled.connect(func(_on: bool) -> void: _rebuild())
	add_child(_props)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 320.0
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_text)


## Нужен для строки «Tool». Без него строка просто пустая
func setup(tool_controller: ToolController) -> void:
	_tool_controller = tool_controller


func _on_bind() -> void:
	_rebuild()


func refresh() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_msec < REBUILD_MSEC:
		return
	_rebuild()


func _rebuild() -> void:
	_last_msec = Time.get_ticks_msec()
	var s := ""
	if _tool_controller and is_instance_valid(_tool_controller.active_tool):
		s += "[color=#8888ff]Tool: %s[/color]\n" % _tool_controller.active_tool.name
	if not is_instance_valid(target):
		s += "Ничего не выбрано"
	else:
		s += "[color=green]%s : %s[/color]\n" % [target.get_script().get_global_name(), target.name]
		for child in target.get_children():
			if child is Component:
				s += _component_block(child as Component)
	if _text.text != s:
		_text.text = s


func _component_block(comp: Component) -> String:
	var script_name: String = comp.get_script().get_global_name()
	var s := ""
	if comp.is_state:
		s += "[color=yellow]- %s - state[/color]\n" % script_name
	else:
		s += "- %s\n" % script_name
	if not _props.button_pressed:
		return s
	for p in comp.get_property_list():
		if not (p.usage & PROPERTY_USAGE_EDITOR):
			continue
		var value: Variant = comp.get(p.name)
		var v := str(value)
		if v != "":
			# [ в значении сломал бы разметку
			s += "    %s: %s\n" % [p.name, v.replace("[", "[lb]")]
	return s
