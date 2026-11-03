class_name WagonTuning extends RefCounted

###########################
## WagonTuning. Список ручек вагона и доступ к ним (U14)
###########################
## Единственное место, которое знает, где у вагона лежит каждый параметр: подвеска и сцепление в
## компонентах C_Chassis, C_Kinematics, C_Engine, трение и демпфирование в RigidBody3D.
## DebugPanel строит строки по PARAMS и ходит в вагон только через read / write / has.
## Ничего не знает про UI и ничего не хранит: цель приходит параметром.

## Тип строки
enum Kind { SPIN, TOGGLE }

## Группы в порядке показа: id -> заголовок
const GROUPS: Array[Dictionary] = [
	{"id": "suspension", "title": "Подвеска"},
	{"id": "kinematics", "title": "Кинематика и сцепление"},
	{"id": "body", "title": "Тело (RigidBody)"},
	{"id": "engine", "title": "Мотор"},
]

## Ручки. key: уникальное имя; group: id группы; kind: SPIN или TOGGLE;
## min/max/step: границы SpinBox (max можно превысить руками); tip: подсказка
const PARAMS: Array[Dictionary] = [
	# Подвеска (C_Chassis)
	{"key": "enable_suspension", "group": "suspension", "kind": Kind.TOGGLE, "label": "Подвеска включена",
		"tip": "Выключение гасит входы подвески, кузов плавно возвращается в покой"},
	{"key": "debug_susp_vertical", "group": "suspension", "kind": Kind.TOGGLE, "label": "Вертикаль (стыки, неровности)"},
	{"key": "debug_susp_pitch", "group": "suspension", "kind": Kind.TOGGLE, "label": "Кивок (разгон, торможение)"},
	{"key": "debug_susp_roll", "group": "suspension", "kind": Kind.TOGGLE, "label": "Крен в кривых"},
	{"key": "debug_susp_lateral", "group": "suspension", "kind": Kind.TOGGLE, "label": "Боковая раскачка"},
	{"key": "debug_susp_hunting", "group": "suspension", "kind": Kind.TOGGLE, "label": "Рыскание тележек"},
	{"key": "effect_multiplier", "group": "suspension", "kind": Kind.SPIN, "label": "Множитель эффектов",
		"min": 0.0, "max": 10.0, "step": 0.1, "tip": "Общий множитель входов подвески"},
	# Кинематика (C_Kinematics)
	{"key": "mass", "group": "kinematics", "kind": Kind.SPIN, "label": "Масса",
		"min": 0.1, "max": 10000.0, "step": 0.1, "tip": "Пишется и в C_Kinematics, и в RigidBody (сцепка берет массу тела)"},
	{"key": "max_grip", "group": "kinematics", "kind": Kind.SPIN, "label": "Max grip (реборда)",
		"min": 0.0, "max": 1000.0, "step": 0.1},
	{"key": "roll_resistance", "group": "kinematics", "kind": Kind.SPIN, "label": "Сопротивление качению",
		"min": 0.0, "max": 5.0, "step": 0.01},
	{"key": "longitudinal_grip", "group": "kinematics", "kind": Kind.SPIN, "label": "Продольное сцепление",
		"min": 0.1, "max": 10.0, "step": 0.1, "tip": "Выше этого значения колеса уходят в пробуксовку"},
	{"key": "min_curve_radius", "group": "kinematics", "kind": Kind.SPIN, "label": "Мин. радиус кривой",
		"min": 0.0, "max": 100.0, "step": 0.1},
	{"key": "max_yaw_deg", "group": "kinematics", "kind": Kind.SPIN, "label": "Макс. поворот тележки, °",
		"min": 0.0, "max": 90.0, "step": 1.0},
	{"key": "yaw_spring", "group": "kinematics", "kind": Kind.SPIN, "label": "Возвратная пружина yaw",
		"min": 0.0, "max": 50.0, "step": 0.1},
	{"key": "slide_friction", "group": "kinematics", "kind": Kind.SPIN, "label": "μ бокового скольжения",
		"min": 0.0, "max": 5.0, "step": 0.01},
	{"key": "locked_wheel_friction", "group": "kinematics", "kind": Kind.SPIN, "label": "μ юза локо",
		"min": 0.0, "max": 10.0, "step": 0.1},
	# Тело (RigidBody3D в C_Kinematics.rb)
	{"key": "friction", "group": "body", "kind": Kind.SPIN, "label": "Трение (physics material)",
		"min": 0.0, "max": 5.0, "step": 0.01},
	{"key": "linear_damp", "group": "body", "kind": Kind.SPIN, "label": "Linear damp",
		"min": 0.0, "max": 10.0, "step": 0.01},
	{"key": "angular_damp", "group": "body", "kind": Kind.SPIN, "label": "Angular damp",
		"min": 0.0, "max": 10.0, "step": 0.01},
	# Мотор (C_Engine)
	{"key": "max_tractive_force", "group": "engine", "kind": Kind.SPIN, "label": "Макс. сила тяги, Н",
		"min": 0.0, "max": 10000.0, "step": 0.1},
	{"key": "max_theoretical_speed", "group": "engine", "kind": Kind.SPIN, "label": "Макс. скорость, м/с",
		"min": 0.0, "max": 1000.0, "step": 0.1},
]


## Ключи по месту хранения
const _CHASSIS_KEYS: Array[String] = ["enable_suspension", "debug_susp_vertical", "debug_susp_pitch",
		"debug_susp_roll", "debug_susp_lateral", "debug_susp_hunting", "effect_multiplier"]
const _KINEMATICS_KEYS: Array[String] = ["mass", "max_grip", "roll_resistance", "longitudinal_grip",
		"min_curve_radius", "max_yaw_deg", "yaw_spring", "slide_friction", "locked_wheel_friction"]
const _ENGINE_KEYS: Array[String] = ["max_tractive_force", "max_theoretical_speed"]


## Есть ли у цели то, где лежит параметр (нужные компоненты и тело)
static func has(entity: Entity, key: String) -> bool:
	if not is_instance_valid(entity):
		return false
	if key in _CHASSIS_KEYS:
		return entity.get_comp(C_Chassis) != null
	if key in _KINEMATICS_KEYS:
		return entity.get_comp(C_Kinematics) != null
	if key in _ENGINE_KEYS:
		return entity.get_comp(C_Engine) != null
	if key == "friction":
		var rb := _body(entity)
		return rb != null and rb.physics_material_override != null
	if key == "linear_damp" or key == "angular_damp":
		return _body(entity) != null
	return false


## Текущее значение или null, если у цели такого параметра нет
static func read(entity: Entity, key: String) -> Variant:
	if not has(entity, key):
		return null
	var chassis := entity.get_comp(C_Chassis) as C_Chassis
	var kin := entity.get_comp(C_Kinematics) as C_Kinematics
	var engine := entity.get_comp(C_Engine) as C_Engine
	match key:
		"enable_suspension": return chassis.enable_suspension
		"debug_susp_vertical": return chassis.debug_susp_vertical
		"debug_susp_pitch": return chassis.debug_susp_pitch
		"debug_susp_roll": return chassis.debug_susp_roll
		"debug_susp_lateral": return chassis.debug_susp_lateral
		"debug_susp_hunting": return chassis.debug_susp_hunting
		"effect_multiplier": return chassis.effect_multiplier
		"mass": return kin.mass
		"max_grip": return kin.max_grip
		"roll_resistance": return kin.roll_resistance
		"longitudinal_grip": return kin.longitudinal_grip
		"min_curve_radius": return kin.min_curve_radius
		"max_yaw_deg": return kin.max_yaw_deg
		"yaw_spring": return kin.yaw_spring
		"slide_friction": return kin.slide_friction
		"locked_wheel_friction": return kin.locked_wheel_friction
		"friction": return _body(entity).physics_material_override.friction
		"linear_damp": return _body(entity).linear_damp
		"angular_damp": return _body(entity).angular_damp
		"max_tractive_force": return engine.max_tractive_force
		"max_theoretical_speed": return engine.max_theoretical_speed
	return null


## Записывает значение. Без нужного компонента ничего не делает
static func write(entity: Entity, key: String, value: Variant) -> void:
	if not has(entity, key):
		return
	var chassis := entity.get_comp(C_Chassis) as C_Chassis
	var kin := entity.get_comp(C_Kinematics) as C_Kinematics
	var engine := entity.get_comp(C_Engine) as C_Engine
	match key:
		"enable_suspension": chassis.enable_suspension = bool(value)
		"debug_susp_vertical": chassis.debug_susp_vertical = bool(value)
		"debug_susp_pitch": chassis.debug_susp_pitch = bool(value)
		"debug_susp_roll": chassis.debug_susp_roll = bool(value)
		"debug_susp_lateral": chassis.debug_susp_lateral = bool(value)
		"debug_susp_hunting": chassis.debug_susp_hunting = bool(value)
		"effect_multiplier": chassis.effect_multiplier = float(value)
		"mass":
			kin.mass = float(value)
			if is_instance_valid(kin.rb):
				kin.rb.mass = maxf(float(value), 0.001)   # RigidBody3D не принимает массу <= 0
		"max_grip": kin.max_grip = float(value)
		"roll_resistance": kin.roll_resistance = float(value)
		"longitudinal_grip": kin.longitudinal_grip = float(value)
		"min_curve_radius": kin.min_curve_radius = float(value)
		"max_yaw_deg": kin.max_yaw_deg = float(value)
		"yaw_spring": kin.yaw_spring = float(value)
		"slide_friction": kin.slide_friction = float(value)
		"locked_wheel_friction": kin.locked_wheel_friction = float(value)
		"friction": _body(entity).physics_material_override.friction = float(value)
		"linear_damp": _body(entity).linear_damp = float(value)
		"angular_damp": _body(entity).angular_damp = float(value)
		"max_tractive_force": engine.max_tractive_force = float(value)
		"max_theoretical_speed": engine.max_theoretical_speed = float(value)


## Где в коде лежит параметр (для режима «Переменные» в DebugPanel)
static func var_name(key: String) -> String:
	if key in _CHASSIS_KEYS:
		return "C_Chassis." + key
	if key in _KINEMATICS_KEYS:
		return "C_Kinematics." + key + (" (+ rb.mass)" if key == "mass" else "")
	if key in _ENGINE_KEYS:
		return "C_Engine." + key
	if key == "friction":
		return "rb.physics_material_override.friction"
	return "rb." + key


## Значения всех доступных цели ручек: key -> значение. Для кнопки «сбросить»
static func snapshot(entity: Entity) -> Dictionary:
	var snap := {}
	for p in PARAMS:
		var v: Variant = read(entity, p.key)
		if v != null:
			snap[p.key] = v
	return snap


## Возвращает значения из snapshot()
static func restore(entity: Entity, snap: Dictionary) -> void:
	for key in snap:
		write(entity, key, snap[key])


## Вагон ли это: есть кинематика (тело и масса). Остальные компоненты у вагона разные (мотор только у локо)
static func is_wagon(entity: Entity) -> bool:
	return is_instance_valid(entity) and entity.get_comp(C_Kinematics) != null


static func _body(entity: Entity) -> RigidBody3D:
	var kin := entity.get_comp(C_Kinematics) as C_Kinematics
	if kin == null or not is_instance_valid(kin.rb):
		return null
	return kin.rb


# --- Паспорт (WagonConfig в .tres типа вагона) ---

## Параметры, которые живут и в паспорте (WagonConfig с теми же именами полей). Остальные ручки (подвеска, трение,
## демпфирование тела) в паспорте не хранятся и остаются только на этом вагоне
const PASSPORT_KEYS: Array[String] = ["mass", "max_grip", "roll_resistance", "longitudinal_grip", "min_curve_radius",
		"max_yaw_deg", "yaw_spring", "slide_friction", "locked_wheel_friction", "max_tractive_force",
		"max_theoretical_speed"]


## Паспорт вагона (общий для всех вагонов этого типа) или null
static func passport(entity: Entity) -> WagonConfig:
	if not is_instance_valid(entity):
		return null
	return WagonConfig.from_entity(entity)


## Путь .tres, в котором лежит паспорт (EntitySetting типа вагона). Пусто, если записать некуда
static func passport_path(entity: Entity) -> String:
	var idc := entity.get_comp(C_Identity) as C_Identity if is_instance_valid(entity) else null
	if idc == null or idc.setting == null:
		return ""
	var path := idc.setting.resource_path
	# «файл::Resource_id» это вложенный ресурс, отдельно его не сохранить
	return path if path.ends_with(".tres") and not path.contains("::") else ""


## Чем вагон отличается от паспорта: [{key, old, value}] только по ключам паспорта (мотор только у вагона с C_Engine)
static func passport_diff(entity: Entity) -> Array[Dictionary]:
	var diff: Array[Dictionary] = []
	var cfg := passport(entity)
	if cfg == null:
		return diff
	for key in PASSPORT_KEYS:
		var now: Variant = read(entity, key)
		if now == null:
			continue
		var old: Variant = cfg.get(key)
		if not is_equal_approx(float(old), float(now)):
			diff.append({"key": key, "old": float(old), "value": float(now)})
	return diff


## Пишет отличия в паспорт и сохраняет .tres. Возвращает {ok: bool, message: String}.
## Уже стоящие вагоны этого типа не меняются (значения копируются в компоненты при создании), новые берут новые значения.
## Работает там, где res:// доступен для записи (запуск из редактора); в собранной игре вернет ошибку записи
static func save_to_passport(entity: Entity) -> Dictionary:
	var cfg := passport(entity)
	var path := passport_path(entity)
	if cfg == null:
		return {"ok": false, "message": "У вагона нет паспорта (WagonConfig)."}
	if path == "":
		return {"ok": false, "message": "Паспорт не лежит в отдельном .tres, записывать некуда."}
	var diff := passport_diff(entity)
	if diff.is_empty():
		return {"ok": true, "message": "Паспорт уже совпадает с вагоном."}
	for d in diff:
		cfg.set(d.key, d.value)
	var setting := (entity.get_comp(C_Identity) as C_Identity).setting
	var err := ResourceSaver.save(setting, path)
	if err != OK:
		for d in diff:   # не оставляем в памяти значения, которых нет в файле
			cfg.set(d.key, d.old)
		return {"ok": false, "message": "Не записано в %s: %s." % [path, error_string(err)]}
	return {"ok": true, "message": "Записано в %s: %d знач." % [path, diff.size()]}


## Отличия текстом «поле = значение» (для буфера обмена: вставить в инспектор паспорта руками)
static func passport_diff_text(entity: Entity) -> String:
	var lines: PackedStringArray = []
	for d in passport_diff(entity):
		lines.append("%s = %s" % [d.key, _num(d.value)])
	return "\n".join(lines)


static func _num(v: float) -> String:
	return String.num(v, 4)
