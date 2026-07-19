class_name VisualStateSettings extends Resource

@export_category('Materials')
@export var ghost_material: Material
@export var selected_material: Material
@export var blocked_material: Material
@export var hover_material: Material
@export var power_material: Material

@export_category('Shader Materials')
@export var ghost_shader_material: Material
@export var selected_shader_material: Material


@export_category('Colors')
@export var ghost_color: Color
@export var selected_color: Color
@export var hover_color: Color
@export var blocked_color: Color

@export_category('Other')
@export var use_outline: bool = true
@export var use_fill: bool = true

@export var fade_speed: float = 6.0
