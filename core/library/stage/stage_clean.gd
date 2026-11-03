extends "res://core/library/stage/library_stage.gd"

# XX claude-library (новый файл)
########################
## Чистая студия: нейтральный фон, студийный свет, тень на «ловце» (ATTN_22 §22.5.3, вариант A, шаг L1)
########################
## Шаблон Icon Studio берётся целиком, меняется только то, что нужно экрану: размер кадра по виду.
## Качество (QualityPreset) не передаётся: оно меняет глобальные настройки теней и SSAO через
## RenderingServer, а Library открывается поверх игры. MSAA вида выставляет экран.

const Template := preload("res://core/library/icon_studio/icon_template.gd")


func _init() -> void:
	id = &"clean"
	title = "Чистая студия"


func make_template() -> Resource:
	var t: Resource = Template.new()
	t.output_size = Vector2i(1600, 900)
	t.bg_mode = 1
	t.bg_color = Color(0.2, 0.22, 0.25)
	t.ground_color = Color(0.3, 0.31, 0.33)
	t.shadow = true
	return t


func apply(world: Node3D) -> void:
	world.apply_template(make_template(), null)
