class_name FlexZones extends RefCounted

# XX claude-terra 13.1.7 (новый файл)
#######################
## Зоны проблем flex-трака: где вагон не впишется в радиус или не потянет уклон.
#######################
## Раньше flex с выключенным контролем лимитов (клавиша L) или с выбранными вручную изгибами ставился, а где именно
## тесно, было видно только по сходу вагона. Теперь кривая режется на участки по FlexZones.STEP, каждому ставится
## тяжесть, а C_FlexShape рисует поверх рельсов полосу с цветом участков:
##   зеленый  - в норме (только у призрака, выбранного и редактируемого трака, чтобы не красить всю сеть)
##   желтый   - близко к пределу (радиус меньше r_min * WARN_R или уклон больше WARN_G от максимума)
##   оранжевый - уклон больше flex_max_grade
##   красный  - радиус меньше flex_r_min (вагон с min_curve_radius = flex_r_min сойдет)
## Пределы те же, что у метки и C_Invalid (GlobalSetting.flex_r_min, flex_max_grade).
## Чистая функция от кривой C_Path: без ссылок на сцену, кроме самого пути.

const STEP := 1.0
const HALF_WIDTH := 1.4
const LIFT := 0.04            # над поверхностью катания, чтобы не мигало на рельсах
const WARN_R := 1.15          # радиус меньше r_min * WARN_R: предупреждение
const WARN_G := 0.85          # уклон больше max_grade * WARN_G: предупреждение

enum Sev { OK, WARN, GRADE, RADIUS }

const COLORS := {
	Sev.OK: Color(0.25, 0.9, 0.35, 0.55),
	Sev.WARN: Color(1.0, 0.85, 0.2, 0.6),
	Sev.GRADE: Color(1.0, 0.5, 0.1, 0.7),
	Sev.RADIUS: Color(1.0, 0.2, 0.2, 0.7),
}

static var _mat: StandardMaterial3D


## Тяжесть участка: радиус и уклон на нем. Радиус INF на прямой
static func severity(radius: float, grade: float, r_min: float, max_grade: float) -> int:
	if radius < r_min * 0.98:      # то же допущение 0.98, что у проверки "R" в C_FlexShape
		return Sev.RADIUS
	if grade > max_grade:
		return Sev.GRADE
	if radius < r_min * WARN_R or grade > max_grade * WARN_G:
		return Sev.WARN
	return Sev.OK


## Полоса по участкам. full = false: рисуем только проблемные участки (желтые, оранжевые, красные).
## Возвращает null, если рисовать нечего. Координаты в системе кривой C_Path (node.transform у вызывающего)
static func build_mesh(path: C_Path, r_min: float, max_grade: float, full: bool) -> ArrayMesh:
	if path == null or path.curve == null:
		return null
	var curve := path.curve
	var length := curve.get_baked_length()
	if length < 0.5:
		return null
	var n := maxi(1, ceili(length / STEP))
	var pos: Array[Vector3] = []
	var right: Array[Vector3] = []
	var rad: Array[float] = []
	var lift := path.head_height() + LIFT
	for i in n + 1:
		var s := length * i / n
		var t := curve.sample_baked_with_rotation(s)
		pos.append(t.origin + Vector3(0.0, lift, 0.0))
		right.append(t.basis.x.normalized() * HALF_WIDTH)
		rad.append(path.radius_at(s))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for i in n:
		var dh := Vector2(pos[i + 1].x - pos[i].x, pos[i + 1].z - pos[i].z).length()
		var grade := absf(pos[i + 1].y - pos[i].y) / maxf(dh, 0.001)
		var sev := severity(minf(rad[i], rad[i + 1]), grade, r_min, max_grade)
		if sev == Sev.OK and not full:
			continue
		any = true
		st.set_color(COLORS[sev])
		st.set_normal(Vector3.UP)
		var a_l := pos[i] - right[i]
		var a_r := pos[i] + right[i]
		var b_l := pos[i + 1] - right[i + 1]
		var b_r := pos[i + 1] + right[i + 1]
		for v in [a_l, a_r, b_r, a_l, b_r, b_l]:
			st.add_vertex(v)
	if not any:
		return null
	return st.commit()


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.vertex_color_use_as_albedo = true
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat
