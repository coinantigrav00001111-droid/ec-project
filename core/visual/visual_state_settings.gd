class_name VisualStateSettings extends Resource

const SHARED_PATH := "res://core/visual/visual_state.tres"
static var _shared: VisualStateSettings

## Единственный ресурс визуальных состояний. Раньше его подставляли в каждый ComponentSettings полем settings,
## во всех .tres он был один и тот же. load, а не preload: .tres сам ссылается на этот скрипт
static func shared() -> VisualStateSettings:
	if _shared == null:
		_shared = load(SHARED_PATH) as VisualStateSettings
	return _shared


@export_category('Materials')
@export var ghost_material: Material
@export var selected_material: Material
@export var blocked_material: Material
@export var hover_material: Material
@export var power_material: Material

@export_category('Shader Materials')
@export var ghost_shader_material: Material
@export var selected_shader_material: Material
@export var power_shader: Shader = preload("res://core/visual/materials/shader_power_track.gdshader")
#@export var power_shader_material: Material

@export_category('Colors')
@export var ghost_color: Color
@export var selected_color: Color
@export var hover_color: Color
@export var blocked_color: Color
@export var CONTOUR_COLORS = {
	0: Color(0.5, 0.5, 0.5), # Серый (нет контура)
	1: Color(0.0, 0.8, 1.0), # Голубой
	2: Color(0.7, 0.2, 0.9), # Фиолетовый
	3: Color(0.2, 1.0, 0.2), # Салатовый
	4: Color(0.72, 0.666, 0.313, 1.0), # замена Оранжевый в резерве
	5: Color(1.0, 0.4, 0.8), # Розовый (Маджента)
	6: Color(0.0, 0.6, 0.6), # Бирюзовый / Морская волна
	7: Color(0.8, 0.6, 1.0), # Сиреневый / Лаванда
	8: Color(0.5, 0.3, 0.1), # Коричневый
	9: Color(0.357, 0.6, 0.071, 1.0), # Белый / Светло-кремовый
	10: Color(0.3, 0.0, 0.5), # Индиго / Глубокий фиолетовый
}
@export_category('Other')
@export var use_outline: bool = true
@export var use_fill: bool = true

@export var fade_speed: float = 6.0
# Палитра цветов для контуров (0 - ошибка/нейтралка, 1..MAX - рабочие)
