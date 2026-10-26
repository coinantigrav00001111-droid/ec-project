class_name C_CrossingShape extends ICapability

# XX claude-switch (новый файл)
####################
## Способность. Форма кросса: два прямых пути, пересекающихся в центре под углом cross_deg.
####################
## Как C_SwitchShape, но оба маршрута активны одновременно (C_Path.set_routes(..., parallel = true)):
## вагон едет по тому, на который въехал (BogieData.route, выбирается по сокету входа или по курсору при посадке).
##   маршрут 0: вдоль -Z, как у прямого трака; маршрут 1: он же, повернутый вокруг центра на cross_deg.
## Сокеты (C_Socket строит их по маршрутам по порядку): [0] начало 0, [1] конец 0, [2] начало 1, [3] конец 1.
## Центр пересечения = середина маршрута 0, после центрирования C_Path он в начале координат Entity.
## Должен стоять в массиве компонентов ПОСЛЕ C_Path и ДО C_Socket.
## Пока только прямые пути (радиус на кроссе всегда INF).

var length := 0.0
var cross_deg := 15.0


func on_entity_ready() -> void:
	var path := get_comp(C_Path) as C_Path
	var identity := get_comp(C_Identity) as C_Identity
	if path == null or identity == null:
		push_error("C_CrossingShape: нужен C_Path и C_Identity (CrossingConfig)")
		return
	length = float(identity.get_config('radius', 23.9))
	cross_deg = clampf(absf(float(identity.get_config('cross_deg', 15.0))), 5.0, 90.0)

	# Подгонка под коллизию: соседние концы двух путей разнесены на L * sin(a / 2)
	var vis := get_comp(C_SwitchVisual) as C_SwitchVisual
	var width := vis.style.collision_width if vis and vis.style else 3.2
	var need := width + float(identity.get_config('end_clearance', 0.1))
	if length > 0.1:
		var sep := length * sin(deg_to_rad(cross_deg) * 0.5)
		if sep < need - 0.01:
			if bool(identity.get_config('auto_fit', true)):
				cross_deg = clampf(rad_to_deg(2.0 * asin(minf(need / length, 1.0))), 5.0, 90.0)
			else:
				push_warning("C_CrossingShape: концы путей разнесены на %.2f, а коллизии соседей требуют %.2f. Увеличьте угол (или auto_fit)" % [sep, need])
	path.set_routes(build_routes(path, length, cross_deg), 0, true)


## Чистая функция: два пути. Путь 1 = путь 0, повернутый вокруг его середины на deg
static func build_routes(path: C_Path, len_straight: float, deg: float) -> Array[Curve3D]:
	var a := path.generate_track_curve(len_straight, 0.0)
	var center := a.sample_baked(a.get_baked_length() * 0.5)
	var rot := Basis(Vector3.UP, deg_to_rad(deg))
	var b: Curve3D = a.duplicate()
	for i in b.point_count:
		b.set_point_position(i, center + rot * (a.get_point_position(i) - center))
		b.set_point_in(i, rot * a.get_point_in(i))
		b.set_point_out(i, rot * a.get_point_out(i))
	var res: Array[Curve3D] = [a, b]
	return res
