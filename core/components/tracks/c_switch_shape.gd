class_name C_SwitchShape extends ICapability

# XX claude-switch (новый файл)
####################
## Способность. Хозяин формы стрелки: строит кривые маршрутов и отдает их в C_Path.set_routes.
####################
## Логика как у C_FlexShape (форма считается тут, путь живет в C_Path), но форма статична:
## после сборки не меняется, переключается только активный маршрут (C_Switch).
##   маршрут 0 - прямой, маршрут 1 - ответвление. Оба в системе координат C_Path, общий носок в начале.
## Должен стоять в массиве компонентов ПОСЛЕ C_Path и ДО C_Socket (сокеты берутся из всех маршрутов).

## Параметры задает SwitchShapeSettings из паспорта (SwitchConfig), компонент паспорт не читает
var length := 23.9
var diverge_deg := 15.0
var diverge_radius := 0.0
var hand := 1.0
var start_route := 0
var auto_fit := true
var end_clearance := 0.1


func on_entity_ready() -> void:
	var path := get_comp(C_Path) as C_Path
	if path == null:
		push_error("C_SwitchShape: нужен C_Path перед компонентом")
		return
	var start := start_route

	# Подгонка под коллизию: концы веток разнесены на L * tan(a / 2) (при R = L / sin a)
	var vis := get_comp(C_SwitchVisual) as C_SwitchVisual
	var width := vis.style.collision_width if vis and vis.style else 3.2
	var need := width + end_clearance
	if auto_fit and diverge_radius <= 0.0 and length > 0.1:
		diverge_deg = maxf(diverge_deg, rad_to_deg(2.0 * atan(need / length)))

	var routes: Array[Curve3D] = build_routes(path, length, diverge_deg, diverge_radius, hand)
	var c1 := routes[1]
	var sep := c1.sample_baked(c1.get_baked_length()).distance_to(routes[0].sample_baked(routes[0].get_baked_length()))
	if sep < need - 0.01:
		push_warning("C_SwitchShape: концы веток разнесены на %.2f, а коллизии соседей требуют %.2f. Увеличьте угол или радиус (или auto_fit)" % [sep, need])
	path.set_routes(routes, start)


## Кривые маршрутов. Чистая функция (без состояния): годится и для призраков, и для тестов
static func build_routes(path: C_Path, len_straight: float, deg: float, r: float, side: float) -> Array[Curve3D]:
	var res: Array[Curve3D] = []
	var a := clampf(deg, 1.0, 60.0)
	var rad := r if r > 0.0 else len_straight / sin(deg_to_rad(a))
	res.append(path.generate_track_curve(len_straight, 0.0))
	res.append(path.generate_track_curve(rad, a * side))
	return res
