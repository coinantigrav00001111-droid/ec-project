class_name C_BlockSelector extends C_PowerDevice

#####################
## Селектор блоков (ATTN_10 §10.9 D5)
#####################
## Два входа (от выводов разных пультов), один выход (к клипам блока). Положения: выкл, вход A, вход B.
## Выбранный вход соединён с выходом; «выкл»: блок обесточен (клип с проводом в разрыв не получает питания).

func title() -> String:
	return "Селектор блоков"


func positions() -> int:
	return 3


func pos_text(p: int) -> String:
	return ["выкл", "вход A", "вход B"][clampi(p, 0, 2)]


func _build_terminals() -> void:
	_add_term(&"in_a", PowerTerminal.Role.DEV_IN, -1.6)
	_add_term(&"in_b", PowerTerminal.Role.DEV_IN, 0.0)
	_add_term(&"out", PowerTerminal.Role.DEV_OUT, 1.6)


func _links_of(t: PowerTerminal) -> Array:
	if t != term(&"out") or pos == 0:
		return []
	var src := term(&"in_a") if pos == 1 else term(&"in_b")
	return [{"terminal": src, "flip": false, "via": self}]


func _knob_color() -> Color:
	return [Color(0.4, 0.4, 0.4), Color(0.2, 0.8, 0.3), Color(0.2, 0.55, 0.95)][pos]
