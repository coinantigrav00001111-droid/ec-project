extends Node
# class_name не задаём: это синглтон TSM (autoload)

###########################
##💡 TSM - TrackStyleManager: стиль траков сессии (ATTN_17 §17.13, ATTN_15 §5.3)
############################
## Держит набор стилей проекта (TrackStyleSet) и активный стиль. Новые траки создаются в активном
## стиле: EntityFactory кладёт запрос в Entity.style_request, визуал трака, у которого поле `style`
## в сеттинге пустое («следовать сессии»), берёт стиль здесь через resolve_for() и записывает итог в
## Entity.style_id (он уходит в сейв). Визуал с непустым `style` зафиксирован, сессию не слушает.
## Активный стиль хранится в сейве макета (SavedGame.track_style). Новая игра берёт default_id.

## Активный стиль сменился (id уже из набора)
signal current_changed(id: StringName)

const SET_PATH := "res://setting/track_style_set.tres"

var style_set: TrackStyleSet
var current_id: StringName = &""

## Стиль новой игры (из набора)
var default_id: StringName:
	get:
		return style_set.default_id if style_set else &""


func _ready() -> void:
	style_set = load(SET_PATH) as TrackStyleSet
	if style_set == null:
		push_error("TSM: нет набора стилей %s, траки строятся стилем по умолчанию" % SET_PATH)
		style_set = TrackStyleSet.new()
	for msg in style_set.validate():
		push_warning(msg)
	current_id = _fallback_id()


## Стиль по id. Нет такого id: запасной (default_id), набор пуст: null (визуал возьмёт TrackStyle.new())
func get_style(id: StringName) -> TrackStyle:
	var st := style_set.get_style(id)
	if st == null:
		st = style_set.get_style(style_set.default_id)
	if st == null and not style_set.styles.is_empty():
		st = style_set.styles[0]
	return st


func current_style() -> TrackStyle:
	return get_style(current_id)


## Сменить активный стиль. Неизвестный id игнорируется с предупреждением. Уже стоящие траки не меняются
func set_current(id: StringName) -> void:
	if not style_set.has_style(id):
		push_warning("TSM: стиля '%s' нет в наборе" % id)
		return
	if id == current_id:
		return
	current_id = id
	current_changed.emit(id)


## Для сейва: пустой или неизвестный id означает стиль по умолчанию
func set_current_from_save(id: StringName) -> void:
	set_current(id if style_set.has_style(id) else _fallback_id())


## Стиль для визуала трака. `fixed` это поле `style` из сеттинга: непустое зафиксировано (style_id
## сущности остаётся пустым), пустое следует запросу фабрики или активному стилю.
func resolve_for(entity: Entity, fixed: TrackStyle) -> TrackStyle:
	if fixed != null:
		return fixed
	var id: StringName = entity.style_request if entity.style_request != &"" else current_id
	var st := get_style(id)
	if st != null:
		entity.style_id = st.id
	return st


func _fallback_id() -> StringName:
	var st := style_set.get_style(style_set.default_id)
	if st == null and not style_set.styles.is_empty():
		st = style_set.styles[0]
	return st.id if st else &""
