class_name TrackStyleSet extends Resource

########################
## Параметры стиля проекта: набор стилей траков (ATTN_17 §17.13, C4)
########################
## Один ресурс `res://setting/track_style_set.tres`. Новый стиль это новая строка массива `styles`
## (файл стиля из `data/tracks/styles/`). `id` стиля берётся из самого `TrackStyle.id` и должен быть
## уникальным. `default_id` это стиль новой игры (и запасной, если нужного id в наборе нет).

@export var styles: Array[TrackStyle] = []
## Стиль новой игры. Должен быть в `styles`
@export var default_id: StringName = &"wood_ballast"


func has_style(id: StringName) -> bool:
	return get_style(id) != null


## Стиль по id. null, если такого нет (подмену на запасной делает TSM)
func get_style(id: StringName) -> TrackStyle:
	for st in styles:
		if st != null and st.id == id:
			return st
	return null


## Все id по порядку набора
func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for st in styles:
		if st != null:
			out.append(st.id)
	return out


## Проблемы набора текстом (пусто = всё в порядке): пустые строки, повтор id, нет default_id
func validate() -> PackedStringArray:
	var out := PackedStringArray()
	var seen := {}
	for i in styles.size():
		var st := styles[i]
		if st == null:
			out.append("TrackStyleSet: строка %d пустая" % i)
			continue
		if st.id == &"":
			out.append("TrackStyleSet: у стиля в строке %d нет id" % i)
		elif seen.has(st.id):
			out.append("TrackStyleSet: id '%s' повторяется (строки %d и %d)" % [st.id, seen[st.id], i])
		else:
			seen[st.id] = i
	if styles.is_empty():
		out.append("TrackStyleSet: набор пуст, траки будут строиться стилем по умолчанию TrackStyle")
	elif not seen.has(default_id):
		out.append("TrackStyleSet: default_id '%s' нет в наборе" % default_id)
	return out
