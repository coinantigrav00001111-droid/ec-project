class_name C_Reverser extends C_PowerDevice

#####################
## Реверсор (DPDT) (ATTN_10 §10.9 D5)
#####################
## Вход и выход. Положение «реверс» меняет полярность на выходе: поезд за ним едет в другую сторону.
## Единственный способ вести реверсивную петлю в реалистичном режиме (с изостыками по обе стороны петли).

func title() -> String:
	return "Реверсор"


func positions() -> int:
	return 2


func pos_text(p: int) -> String:
	return "реверс" if p == 1 else "прямо"


func _build_terminals() -> void:
	_add_term(&"in", PowerTerminal.Role.DEV_IN, -1.2)
	_add_term(&"out", PowerTerminal.Role.DEV_OUT, 1.2)


func _links_of(t: PowerTerminal) -> Array:
	if t != term(&"out"):
		return []
	return [{"terminal": term(&"in"), "flip": pos == 1, "via": self}]


func _knob_color() -> Color:
	return Color(0.95, 0.6, 0.15) if pos == 1 else Color(0.3, 0.75, 0.35)
