class_name FilterBar extends HBoxContainer

###########################
## FilterBar. Ряд фильтров каталога над сеткой объектов (U3b)
###########################
## Один выпадающий список на фильтр: «Любой» и значения. Сама ничего не отбирает: сообщает сигналом
## изменённый набор {id фильтра: значение}, отбирает провайдер. Состояние хранит ToolbarController.

## ⚡Сигнал: набор выбранных значений изменился
signal filters_changed(values: Dictionary)

var _values := {}
var _empty_label: Label
var _reset_btn: Button


func _init() -> void:
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_PASS


## Перестраивает ряд под filters (get_filters провайдера) и выбранные values. Нет фильтров: ряд скрыт
func setup(filters: Array[Dictionary], values: Dictionary) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_values = values.duplicate()
	visible = not filters.is_empty()
	for f in filters:
		var lbl := Label.new()
		lbl.text = str(f["title"]) + ":"
		add_child(lbl)
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		ob.add_item("Любой")
		ob.set_item_metadata(0, "")
		var selected := 0
		for o in f["options"]:
			ob.add_item(str(o["name"]))
			ob.set_item_metadata(ob.item_count - 1, str(o["id"]))
			if str(_values.get(f["id"], "")) == str(o["id"]):
				selected = ob.item_count - 1
		ob.select(selected)
		ob.item_selected.connect(_on_selected.bind(ob, f["id"]))
		add_child(ob)
	_reset_btn = Button.new()
	_reset_btn.text = "Сброс"
	_reset_btn.focus_mode = Control.FOCUS_NONE
	_reset_btn.pressed.connect(_on_reset)
	add_child(_reset_btn)
	_empty_label = Label.new()
	_empty_label.text = "Нет объектов с такими признаками"
	_empty_label.hide()
	add_child(_empty_label)


## Показать надпись «ничего не найдено»
func set_empty(empty: bool) -> void:
	if _empty_label:
		_empty_label.visible = empty


func _on_selected(index: int, ob: OptionButton, id: StringName) -> void:
	var v := str(ob.get_item_metadata(index))
	if v == "":
		_values.erase(id)
	else:
		_values[id] = v
	filters_changed.emit(_values.duplicate())


func _on_reset() -> void:
	_values.clear()
	filters_changed.emit({})
