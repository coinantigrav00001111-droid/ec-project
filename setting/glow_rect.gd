class_name GlowRect extends Resource

########################
## Светящийся прямоугольник (окно, табло) для LightConfig.glow_rects (ATTN_16, шаг L6).
########################
## Позиция и поворот в системе родителя источника (по умолчанию корень сцены модели, как у LightConfig.position).
## Прямоугольник смотрит вдоль своей оси +Z. Наружу в +Z: rotation_deg = (0, 0, 0), в -Z: (0, 180, 0),
## в +X: (0, 90, 0), в -X: (0, -90, 0). Материал двусторонний, поэтому сторона не критична.

@export var position: Vector3 = Vector3.ZERO
@export var rotation_deg: Vector3 = Vector3.ZERO
## Ширина и высота
@export var size: Vector2 = Vector2(1.0, 1.0)
