class_name TrackStyle extends Resource

########################
## Стиль flex-трака: рельсы, шпалы, балласт. Косметика, растет ВНИЗ от поверхности катания.
########################
## Контракт (общий для всех стилей): колея (rail_x) и высота головки рельса над origin пути (head_height()).
## Все, кто ездит по траку или садится на него, читают только C_Path.head_height(), а он берет число отсюда.
##
## Профили задаются ломаной в осях (x, y):
##  - обход слева направо ПОВЕРХ (по часовой стрелке), днище не задается (его не видно);
##  - ballast_profile: x от оси трака, y от origin пути (низ балласта = 0);
##  - rail_profile: x от оси рельса, y от подошвы рельса.
## Меш шпалы (если задан): origin в центре площади опоры, низ на y = 0, длина вдоль Z, ширина вдоль X.
## Размеры из sleeper_size берутся, только если sleeper_mesh пуст (тогда шпала это BoxMesh).
##
## Примеры:
##  с балластом (по умолчанию): head_height = 0.5 + (0.2 - 0.1) + 0.25 = 0.85
##  без балласта:               ballast_enabled = false, collision_width = 3.0 -> 0.2 + 0.25 = 0.45

@export var id: StringName = &"ballast"

@export_category("Rails")
## Половина колеи (до оси рельса), ю
@export var rail_x := 0.875
@export var rail_profile := PackedVector2Array([
	Vector2(-0.1, 0.0), Vector2(-0.1, 0.25), Vector2(0.1, 0.25), Vector2(0.1, 0.0)])
## null = общий материал рельсов из C_VisualFlex
@export var rail_material: Material

@export_category("Sleepers")
## null = BoxMesh размера sleeper_size
@export var sleeper_mesh: Mesh
@export var sleeper_size := Vector3(3.0, 0.2, 0.3)   # ширина, высота, длина вдоль пути
## Зазор между шпалами, ю
@export var sleeper_gap := 0.4
## На сколько шпала вдавлена в балласт, ю (без балласта игнорируется)
@export var sleeper_embed := 0.1
## null = общий материал шпал (для своего sleeper_mesh null оставляет материалы самого меша)
@export var sleeper_material: Material

@export_category("Ballast")
@export var ballast_enabled := true
@export var ballast_profile := PackedVector2Array([
	Vector2(-1.6, 0.0), Vector2(-1.1, 0.5), Vector2(1.1, 0.5), Vector2(1.6, 0.0)])
@export var ballast_material: Material

@export_category("Collision")
## Ширина коллизии основания (балласт/шпалы), ю
@export var collision_width := 3.2


# ==========================================
# Производные высоты
# ==========================================

func sleeper_dims() -> Vector3:
	return sleeper_mesh.get_aabb().size if sleeper_mesh else sleeper_size


func sleeper_step() -> float:
	return sleeper_dims().z + sleeper_gap


func ballast_height() -> float:
	return _max_y(ballast_profile) if ballast_enabled else 0.0


## Низ шпалы над origin пути
func sleeper_bottom() -> float:
	var embed := sleeper_embed if ballast_enabled else 0.0
	return maxf(ballast_height() - embed, 0.0)


## Низ рельса (верх шпал) над origin пути
func base_height() -> float:
	return sleeper_bottom() + sleeper_dims().y


func rail_height() -> float:
	return _max_y(rail_profile)


func rail_width() -> float:
	var lo := INF
	var hi := -INF
	for p in rail_profile:
		lo = minf(lo, p.x)
		hi = maxf(hi, p.x)
	return hi - lo if hi > lo else 0.2


## Поверхность катания над origin пути. Единственный источник высоты для C_Path.head_height()
func head_height() -> float:
	return base_height() + rail_height()


func _max_y(p: PackedVector2Array) -> float:
	var m := 0.0
	for v in p:
		m = maxf(m, v.y)
	return m
