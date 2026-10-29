class_name UIAnim extends RefCounted

###########################
## UIAnim. Общие анимации интерфейса
###########################
## Раньше `animate_wrapper` был скопирован в трех контроллерах (Build, Operate, Observe).

const SLIDE_TIME := 0.4


## Показывает панель. Если внутри есть узел `AnimatedWrapper`, он выезжает снизу вверх с появлением.
## Без обертки панель просто показывается
static func slide_up(panel: Control, time: float = SLIDE_TIME) -> void:
	var wrapper := panel.get_node_or_null("AnimatedWrapper") as Control
	if wrapper == null:
		panel.show()
		return

	panel.show()
	wrapper.modulate.a = 0.0
	wrapper.offset_transform_position.y = wrapper.size.y   # старт: смещены вниз на высоту панели

	var tween := wrapper.create_tween().set_parallel(true)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(wrapper, "offset_transform_position:y", 0.0, time)
	tween.tween_property(wrapper, "modulate:a", 1.0, time)
