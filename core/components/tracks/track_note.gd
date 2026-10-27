class_name TrackNote extends RefCounted

# XX claude-terra 13.1.7 (новый файл)
#######################
## Одна метка Label3D над траком на все подписи и предупреждения.
#######################
## Раньше уровень, отказ снапа, форма flex и TUNNEL были четырьмя Label3D в одной точке и налезали друг на друга
## (при отказе снапа читалось "Ур.6 ... Излом ..." кашей). Теперь у Entity одна метка "TrackNote", а компоненты
## держат каждый свою строку (Line) и меняют ее как раньше: text, modulate, visible, position.
## Строки идут сверху вниз по order. Цвет метки у самой тревожной строки: красный, желтый, белый, голубой (инфо).
## Положение метки берется у верхней видимой строки.
##
##   var _label := TrackNote.line(entity, &"flex", 0)
##   _label.text = "L 12.0"
##   _label.modulate = Color(1.0, 0.35, 0.35)
##   _label.queue_free()     # убрать строку

const PIXEL_SIZE := 0.0015
const FONT_SIZE := 32
const META := &"track_note"

var _entity: Node3D
var _label: Label3D
var _lines: Array[Line] = []


## Строка метки. Свойства-сеттеры сами обновляют метку
class Line extends RefCounted:
	var _note: TrackNote
	var key: StringName
	var order := 0
	var text := "":
		set(v):
			if text != v:
				text = v
				_changed()
	var modulate := Color.WHITE:
		set(v):
			if modulate != v:
				modulate = v
				_changed()
	var visible := true:
		set(v):
			if visible != v:
				visible = v
				_changed()
	var position := Vector3(0.0, 6.0, 0.0):
		set(v):
			if position != v:
				position = v
				_changed()

	func _changed() -> void:
		if _note:
			_note._refresh()

	## Убрать строку. Когда строк не осталось, метка удаляется
	func queue_free() -> void:
		if _note:
			var n := _note
			_note = null
			n._remove(self)


## Строка метки у сущности по ключу (создается, если еще нет)
static func line(entity: Node3D, key: StringName, order: int = 0) -> Line:
	var note: TrackNote = entity.get_meta(META) if entity.has_meta(META) else null
	if note == null:
		note = TrackNote.new()
		note._entity = entity
		entity.set_meta(META, note)
	for existing in note._lines:
		if existing.key == key:
			return existing
	var created := Line.new()
	created._note = note
	created.key = key
	created.order = order
	note._lines.append(created)
	note._lines.sort_custom(func(a: Line, b: Line): return a.order < b.order)
	return created


func _remove(l: Line) -> void:
	_lines.erase(l)
	if _lines.is_empty():
		if is_instance_valid(_label):
			_label.queue_free()
		_label = null
		if is_instance_valid(_entity) and _entity.has_meta(META):
			_entity.remove_meta(META)
		return
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(_entity):
		return
	var parts: PackedStringArray = []
	var top: Line = null
	var alert := -INF
	var color := Color.WHITE
	for l in _lines:
		if not l.visible or l.text == "":
			continue
		parts.append(l.text)
		if top == null:
			top = l
		var a := l.modulate.r - l.modulate.g    # красный > желтый > белый > голубой
		if a > alert:
			alert = a
			color = l.modulate
	if top == null:
		if is_instance_valid(_label):
			_label.visible = false
		return
	if not is_instance_valid(_label):
		_label = Label3D.new()
		_label.name = "TrackNote"
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.fixed_size = true
		_label.no_depth_test = true
		_label.pixel_size = PIXEL_SIZE
		_label.font_size = FONT_SIZE
		_label.outline_size = 8
		_entity.add_child(_label)
	var txt := "\n".join(parts)
	if _label.text != txt:
		_label.text = txt
	_label.modulate = color
	_label.position = top.position
	_label.visible = true
