class_name InfoTerrainTab extends InfoTab

###########################
## Вкладка «Материал» листа пенопласта (T7, XX claude-terra)
###########################
## Создается кодом. Видна только у настоящего листа (C_TerrainLayer без C_Ghost). Стадия: C_TerrainLayer.FoamStage.

const STAGE_NAMES := ["Сырой пенопласт", "Шпаклёвка", "Краска", "Трава"]

var _stage_option: OptionButton
var _terrain_info: Label
# XX claude-terra 13.2 B4: толщина листа
var _levels_spin: SpinBox
var _terrain_msg: Label


func _setup() -> void:
	var box := make_page("Материал")
	_terrain_info = Label.new()
	box.add_child(_terrain_info)
	# XX claude-terra 13.2 B4: толщина листа в слоях (верх растёт, низ на месте)
	var row := HBoxContainer.new()
	var row_lbl := Label.new()
	row_lbl.text = "Толщина, слоёв  "
	row.add_child(row_lbl)
	_levels_spin = SpinBox.new()
	_levels_spin.min_value = 1
	_levels_spin.max_value = C_TerrainLayer.MAX_LEVELS
	_levels_spin.step = 1
	_levels_spin.rounded = true
	_levels_spin.value_changed.connect(_on_levels_changed)
	row.add_child(_levels_spin)
	box.add_child(row)
	_terrain_msg = Label.new()
	_terrain_msg.modulate = Color(1.0, 0.35, 0.35)
	box.add_child(_terrain_msg)
	var lbl := Label.new()
	lbl.text = "Стадия отделки листа"
	box.add_child(lbl)
	_stage_option = OptionButton.new()
	for n in STAGE_NAMES:
		_stage_option.add_item(n)
	_stage_option.item_selected.connect(_on_stage_selected)
	box.add_child(_stage_option)


func can_show(entity: Entity) -> bool:
	return _layer_of(entity) != null


static func _layer_of(entity: Entity) -> C_TerrainLayer:
	if entity == null or entity.has_comp(C_Ghost):
		return null
	return entity.get_comp(C_TerrainLayer) as C_TerrainLayer


func _get_terrain_layer() -> C_TerrainLayer:
	return _layer_of(target)


## Живая подпись (размер, слои, уровни): форма и толщина меняются ручками и инструментами
func refresh() -> void:
	var layer := _get_terrain_layer()
	if layer:
		_refresh_terrain_info(layer)


func _on_bind() -> void:
	var layer := _get_terrain_layer()
	if layer:
		_stage_option.select(layer.stage)
		_terrain_msg.text = ""
		_refresh_terrain_info(layer)


## Размер в плане, толщина и положение по уровням. Живые значения: вкладка обновляется при смене цели и стадии
func _refresh_terrain_info(layer: C_TerrainLayer) -> void:
	var T: float = Global.settings.layer_height
	# XX claude-terra 13.2 B1: размер берем из контура листа, а не из TerrainConfig (лист может быть любой формы)
	var contour := target.get_comp(C_Contour) as C_Contour
	var _size := Vector2.ZERO
	if contour:
		_size = contour.size()
	else:
		var identity := target.get_comp(C_Identity) as C_Identity
		_size = identity.get_config('size', Vector2.ZERO) if identity else Vector2.ZERO
	var base := roundi(layer.base_y() / T)
	var shape_text := ""
	if contour and not contour.is_rect():
		shape_text = "Вершин: %d, площадь: %.0f u²\n" % [contour.points.size(), contour.area()]
	_terrain_info.text = "Размер: %d × %d u\n%sСлоёв: %d (высота %.1f u)\nНижний уровень: %d, верхний: %d\nВырезов: %d" % [
		roundi(_size.x), roundi(_size.y), shape_text, layer.levels, layer.levels * T, base, base + layer.levels, layer.cuts.size()]
	if _levels_spin and int(_levels_spin.value) != layer.levels:   # не трогаем, пока значение то же (идет ввод)
		_levels_spin.set_value_no_signal(layer.levels)


## XX claude-terra 13.2 B4. Толщина из SpinBox: C_TerrainLayer либо принимает, либо пишет причину отказа в "error"
func _on_levels_changed(value: float) -> void:
	var layer := _get_terrain_layer()
	if layer == null:
		return
	var d := {"levels": int(value)}
	target.send_event("on_terrain_levels_set", d)
	_terrain_msg.text = String(d.get("error", ""))
	_refresh_terrain_info(layer)   # при отказе вернёт в SpinBox прежнее значение


func _on_stage_selected(index: int) -> void:
	if _get_terrain_layer():
