class_name SuspensionState extends RefCounted

#####################################
## Подвеска кузова вагона. НЕ нода и НЕ компонент: владеет ею C_Chassis,
## вызывает update() один раз за физ. тик и забирает get_offset_transform().
#####################################
## Модель: 5 независимых пружинных мод кузова (heave, pitch, roll, sway, yaw).
## Каждая мода - осциллятор  x'' = w²(target - x) - 2ζw·x'  (+ разовые толчки в скорость).
##
## ВХОДЫ (по каналам-маскам, см. CH_*):
##   VERTICAL - стыки (толчок по скорости) и неровности пути (target) на ДВУХ тележках
##              heave = среднее, pitch = разность / база. "та-дум, та-дум" получается сам.
##   PITCH    - продольное ускорение (кивок при разгоне/торможении), чисто визуальный tilt
##   ROLL     - боковое ускорение в кривой (крен наружу)
##   LATERAL  - боковые неровности + смещение кузова наружу кривой + толчки на стыках
##   HUNTING  - волна рыскания (длина волны постоянна, амплитуда растёт у v_crit)
##
## Выключение канала/подвески обнуляет ВХОД, а не состояние: моды сами возвращаются
## в покой по своей динамике (без рывков), после чего подвеска "засыпает" и не стоит ничего.
##
## Требует Godot 4.1+ (static var).

## ⚡ Стык рельс: bogie_index 0 = передняя, 1 = задняя. kind: &"track" | &"rail". Для звука/анимации.
signal rail_joint(bogie_index: int, kind: StringName, strength: float)

const CH_VERTICAL := 1
const CH_PITCH := 2
const CH_ROLL := 4
const CH_LATERAL := 8
const CH_HUNTING := 16
const CH_ALL := 31

const JOINT_TRACK := &"track"
const JOINT_RAIL := &"rail"

const A_MAX := 40.0            # ю/с², отсечка ускорений (пинки и т.п. дают 1-кадровые выбросы)
const MOVING_SPEED := 0.05     # ю/с, ниже - считаем, что стоим
const SPEED_RAMP_LO := 0.1     # ю/с, начиная отсюда включается тряска от пути
const SPEED_RAMP_HI := 2.0
const HUNT_DECAY := 2.0        # с, затухание "подпитки" рыскания от кривой
const YAW_FILTER := 0.06       # с, фильтр угловой скорости (хорда по baked-точкам чуть дрожит)


## Одна мода кузова. Полунеявный Эйлер с подшагами: устойчив пока w*dt < ~1.
class Mode extends RefCounted:
	var x := 0.0
	var v := 0.0

	func step(dt: float, w: float, zeta: float, target: float, limit: float) -> void:
		var n := clampi(ceili(w * dt / 0.8), 1, 4)
		var h := dt / float(n)
		for _i in n:
			v += (w * w * (target - x) - 2.0 * zeta * w * v) * h
			x += v * h
		# упор: гасим скорость, уходящую за предел
		if x > limit:
			x = limit
			v = minf(v, 0.0)
		elif x < -limit:
			x = -limit
			v = maxf(v, 0.0)

	func at_rest() -> bool:
		return absf(x) < 0.0003 and absf(v) < 0.003

	func zero() -> void:
		x = 0.0
		v = 0.0


## Память по одной тележке: на каком траке была, в каком "сегменте" стыков.
class Mem extends RefCounted:
	var track_id := 0
	var idx := 0
	var noise_off := 0.0


var cfg: SuspensionConfig

var heave := Mode.new()    # вертикальный сдвиг, ю
var pitch := Mode.new()    # рад. + = нос вверх (поворот вокруг +X; перёд вагона = -Z)
var roll := Mode.new()     # рад. + = правый борт вверх (поворот вокруг +Z)
var sway := Mode.new()     # боковой сдвиг, ю. + = вправо (+X)
var yaw := Mode.new()      # рад. + = влево (поворот вокруг +Y)

var _span := 4.0           # расстояние между крайними тележками, ю
var _w_scale := 1.0
var _kick_scale := 1.0
var _w_heave := 0.0
var _w_pitch := 0.0
var _w_roll := 0.0
var _w_sway := 0.0
var _w_yaw := 0.0
var _lim_pitch := 0.0
var _lim_roll := 0.0
var _lim_yaw := 0.0
var _a_pitch := 0.0
var _a_roll := 0.0
var _a_sway_roll := 0.0

var _cache_dt := -1.0
var _f_yaw := 0.0                  # 1 - exp(-dt / YAW_FILTER)
var _f_hunt := 0.0                 # exp(-dt / HUNT_DECAY)

var _mem: Array[Mem] = [Mem.new(), Mem.new()]
var _asleep := true
var _prev_speed := 0.0
var _k := 1.0                      # speed>0 едет по носу (+1) или по корме (-1)
var _prev_fwd_h := Vector3.ZERO
var _yaw_rate_f := 0.0
var _a_lat_prev := 0.0
var _hunt_phase := 0.0
var _hunt_excite := 0.0

# значения текущего тика (нужны в _joint / _sample)
var _kick_gain := 0.0              # intensity, если канал VERTICAL включён
var _kick_gain_lat := 0.0          # intensity, если канал LATERAL включён
var _g_vert := 0.0                 # то же, но с разгоном по скорости (для неровностей)
var _g_lat := 0.0

# для get_debug_info
var _dbg_a_long := 0.0
var _dbg_a_lat := 0.0
var _dbg_hunt := 0.0

static var _noise: FastNoiseLite


static func _get_noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
		_noise.seed = 1337
		_noise.frequency = 1.0      # длину волны задаём делением координаты
	return _noise


## span - расстояние между крайними тележками (0 для одной тележки - возьмём 1.0)
func setup(c: SuspensionConfig, mass: float, span: float) -> void:
	cfg = c
	_span = maxf(span, 1.0)
	# Масса через частоту и через вход: f = f_ref*sqrt(m_ref/m), толчок ~ 1/m. Крайности режем.
	var ratio := c.ref_mass / maxf(mass, 0.01)
	_w_scale = clampf(sqrt(ratio), 0.6, 1.6)
	_kick_scale = clampf(ratio, 0.4, 2.5)
	_w_heave = TAU * c.heave_hz * _w_scale
	_w_pitch = TAU * c.pitch_hz * _w_scale
	_w_roll = TAU * c.roll_hz * _w_scale
	_w_sway = TAU * c.sway_hz * _w_scale
	_w_yaw = TAU * c.yaw_hz * _w_scale
	_lim_pitch = deg_to_rad(c.limit_pitch_deg)
	_lim_roll = deg_to_rad(c.limit_roll_deg)
	_lim_yaw = deg_to_rad(c.limit_yaw_deg)
	_a_pitch = deg_to_rad(c.pitch_accel_deg)
	_a_roll = deg_to_rad(c.roll_accel_deg)
	_a_sway_roll = deg_to_rad(c.sway_roll_deg)
	reset()


## Жёсткий сброс: драг, сход, посадка на рельсы. В остальных случаях моды возвращаются сами.
func reset() -> void:
	heave.zero()
	pitch.zero()
	roll.zero()
	sway.zero()
	yaw.zero()
	for m in _mem:
		m.track_id = 0
	_asleep = true
	_prev_speed = 0.0
	_prev_fwd_h = Vector3.ZERO
	_yaw_rate_f = 0.0
	_a_lat_prev = 0.0
	_hunt_excite = 0.0


func is_at_rest() -> bool:
	return _asleep


## Локальное смещение кузова относительно entity. rb.global_transform = entity.global_transform * это
func get_offset_transform() -> Transform3D:
	var roll_total := roll.x
	if cfg.limit_sway > 0.0:
		roll_total -= (sway.x / cfg.limit_sway) * _a_sway_roll   # кузов наклоняется в сторону смещения
	var b := Basis.from_euler(Vector3(pitch.x, yaw.x, roll_total))   # порядок YXZ: yaw, pitch, roll
	var c := Vector3(0.0, cfg.pivot_height, 0.0)                     # вращаем вокруг точки, не вокруг начала
	return Transform3D(b, c - b * c + Vector3(sway.x, heave.x, 0.0))


## Один физ. тик. Вызывать ПОСЛЕ того, как C_Chassis поставил entity (позиция и базис по хорде).
##   speed    - current_speed шасси (знак - по сплайну)
##   v3       - фактическая 3D-скорость entity (current_velocity_3d)
##   front/rear - первая и последняя тележка (rear = null, если тележка одна)
##   mask     - OR из CH_*
##   intensity - общий множитель входов (effect_multiplier); 0 = всё выключено
func update(dt: float, speed: float, v3: Vector3, basis: Basis,
		front: C_Bogie.BogieData, rear: C_Bogie.BogieData,
		mask: int, intensity: float) -> void:
	if dt <= 0.0:
		return

	if dt != _cache_dt:
		_cache_dt = dt
		_f_yaw = 1.0 - exp(-dt / YAW_FILTER)
		_f_hunt = exp(-dt / HUNT_DECAY)

	var speed_abs := absf(speed)
	var dspeed := speed - _prev_speed
	_prev_speed = speed

	# Подвеска "в деле", если есть что-то включённое. Выключенная или стоящая подвеска, у которой
	# все моды в покое, спит и не стоит ничего.
	var active := mask != 0 and intensity > 0.0
	var parked := speed_abs < MOVING_SPEED and absf(dspeed) < 0.0001
	if _asleep:
		if not active or parked:
			return
		_asleep = false

	# ---------- 1. Кинематика движения в осях кузова ----------
	var fwd := -basis.z
	var vf := v3.dot(fwd)
	if speed_abs > MOVING_SPEED and absf(vf) > MOVING_SPEED:
		_k = signf(vf) * signf(speed)           # связь знака speed с носом/кормой вагона
	var a_long := clampf(dspeed / dt, -A_MAX, A_MAX) * _k     # + = ускорение вперёд (по носу)
	var v_body := speed * _k

	# Боковое ускорение = -yaw_rate * v (центростремительное, в оси +X кузова). Не зависит от
	# is_flipped/полярности/направления: считается из фактического поворота хорды.
	var fh := Vector3(fwd.x, 0.0, fwd.z)
	var yaw_rate := 0.0
	if fh.length_squared() > 0.0001:
		fh = fh.normalized()
		if _prev_fwd_h != Vector3.ZERO:
			yaw_rate = _prev_fwd_h.signed_angle_to(fh, Vector3.UP) / dt
		_prev_fwd_h = fh
	else:
		_prev_fwd_h = Vector3.ZERO
	_yaw_rate_f = lerpf(_yaw_rate_f, yaw_rate, _f_yaw)
	var a_lat := clampf(-_yaw_rate_f * v_body, -A_MAX, A_MAX)
	var da_lat := absf(a_lat - _a_lat_prev)
	_a_lat_prev = a_lat
	_dbg_a_long = a_long
	_dbg_a_lat = a_lat

	# ---------- 2. Каналы ----------
	var k_speed := smoothstep(SPEED_RAMP_LO, SPEED_RAMP_HI, speed_abs)
	_kick_gain = intensity if (mask & CH_VERTICAL) != 0 else 0.0
	_kick_gain_lat = intensity if (mask & CH_LATERAL) != 0 else 0.0
	_g_vert = _kick_gain * k_speed
	_g_lat = _kick_gain_lat * k_speed

	# ---------- 3. Вход от пути на двух тележках ----------
	var s_f := _sample(0, front, speed_abs)
	var s_r := _sample(1, rear, speed_abs)
	if rear == null:
		s_r = s_f
	var span := _span

	var u_heave := (s_f.x + s_r.x) * 0.5 * _g_vert
	var u_pitch := (s_f.x - s_r.x) / span * _g_vert                 # перёд выше -> нос вверх
	var u_sway := (s_f.y + s_r.y) * 0.5 * _g_lat
	var u_yaw := (s_r.y - s_f.y) / span * _g_lat                    # перёд вправо -> поворот вправо (yaw < 0)

	# ---------- 4. Вход от ускорений ----------
	var u_roll := 0.0
	if (mask & CH_PITCH) != 0:
		u_pitch += _a_pitch * tanh(a_long / cfg.pitch_accel_ref) * intensity
	if (mask & CH_ROLL) != 0:
		u_roll = _a_roll * tanh(a_lat / cfg.roll_accel_ref) * intensity   # a_lat<0 (левая кривая) -> крен вправо, наружу
	if (mask & CH_LATERAL) != 0:
		u_sway -= cfg.sway_accel_shift * tanh(a_lat / cfg.roll_accel_ref) * intensity

	# ---------- 5. Hunting ----------
	_dbg_hunt = 0.0
	if (mask & CH_HUNTING) != 0 and cfg.hunting_amp > 0.0 and speed_abs > 0.5:
		_hunt_excite = clampf(_hunt_excite * _f_hunt + da_lat * cfg.hunting_curve_gain, 0.0, 1.0)
		var crit := smoothstep(cfg.hunting_v_crit * 0.7, cfg.hunting_v_crit * 1.2, speed_abs)
		var amp := cfg.hunting_amp * clampf(crit + _hunt_excite, 0.0, 1.0) \
				* smoothstep(0.5, 2.0, speed_abs) * intensity
		_hunt_phase = fposmod(_hunt_phase + speed_abs * dt / cfg.hunting_wavelength, 1.0)
		var lag := fposmod(span / cfg.hunting_wavelength, 1.0)
		var d_f := amp * sin(TAU * _hunt_phase)
		var d_r := amp * sin(TAU * (_hunt_phase - lag))
		u_sway += (d_f + d_r) * 0.5
		u_yaw += (d_r - d_f) / span
		_dbg_hunt = amp
	else:
		_hunt_excite *= _f_hunt

	# ---------- 6. Интегрируем моды ----------
	heave.step(dt, _w_heave, cfg.heave_zeta, u_heave, cfg.limit_heave)
	pitch.step(dt, _w_pitch, cfg.pitch_zeta, u_pitch, _lim_pitch)
	roll.step(dt, _w_roll, cfg.roll_zeta, u_roll, _lim_roll)
	sway.step(dt, _w_sway, cfg.sway_zeta, u_sway, cfg.limit_sway)
	yaw.step(dt, _w_yaw, cfg.yaw_zeta, u_yaw, _lim_yaw)

	# ---------- 7. Засыпаем, когда стоим и всё успокоилось ----------
	if (not active or (speed_abs < MOVING_SPEED and absf(dspeed) < 0.001)) \
			and heave.at_rest() and pitch.at_rest() and roll.at_rest() \
			and sway.at_rest() and yaw.at_rest():
		heave.zero()
		pitch.zero()
		roll.zero()
		sway.zero()
		yaw.zero()
		_asleep = true


## Опрос одной тележки: детект стыков (толчок в скорость) + неровности пути.
## Возвращает Vector2(вертикаль, боковое) в ю. Координата шума - расстояние по ТРАКУ, поэтому
## одно и то же место макета трясёт всегда одинаково (и после загрузки сейва тоже).
func _sample(i: int, b: C_Bogie.BogieData, speed_abs: float) -> Vector2:
	var m: Mem = _mem[i]
	if b == null or not is_instance_valid(b.current_track):
		m.track_id = 0
		return Vector2.ZERO

	var tr: Entity = b.current_track
	var s := b.track_distance
	var id := tr.get_instance_id()
	var moving := speed_abs > MOVING_SPEED
	var spacing := cfg.joint_spacing

	if id != m.track_id:
		var had_track := m.track_id != 0       # после reset() первая привязка - не стык
		m.track_id = id
		m.noise_off = _noise_offset(tr)
		m.idx = floori(s / spacing) if spacing > 0.0 else 0
		if had_track and moving:
			_joint(i, JOINT_TRACK, speed_abs, m)
	elif spacing > 0.0:
		var k := floori(s / spacing)
		if k != m.idx:
			m.idx = k
			if moving:
				_joint(i, JOINT_RAIL, speed_abs, m)

	if _g_vert <= 0.0 and _g_lat <= 0.0:
		return Vector2.ZERO
	var n := _get_noise()
	var x := s / cfg.irregularity_wavelength + m.noise_off
	return Vector2(n.get_noise_1d(x) * cfg.irregularity_vertical,
			n.get_noise_1d(x + 517.3) * cfg.irregularity_lateral)


## Толчок тележки i на стыке. Вертикаль вниз ("провал" и отскок) + небольшой боковой.
## Тележка спереди даёт нос вниз, сзади - нос вверх: пара ударов даёт характерное "та-дум".
func _joint(i: int, kind: StringName, speed_abs: float, m: Mem) -> void:
	var strength := cfg.joint_kick * minf(speed_abs, cfg.joint_speed_cap)
	if kind == JOINT_TRACK:
		strength *= cfg.joint_track_gain
	strength *= _kick_scale

	# Детерминированный "характер" стыка (не randf): тот же стык бьёт одинаково
	var r := fposmod(sin(m.noise_off * 12.9898 + float(m.idx) * 78.233) * 43758.5453, 1.0)
	var side := 1.0 if i == 0 else -1.0

	if _kick_gain > 0.0:
		var kv := -strength * (0.6 + 0.4 * r) * _kick_gain
		heave.v += kv * 0.5
		pitch.v += kv / _span * side
	if _kick_gain_lat > 0.0:
		var kl := strength * cfg.joint_lateral_ratio * (2.0 * r - 1.0) * _kick_gain_lat
		sway.v += kl * 0.5
		yaw.v += -kl / _span * side

	rail_joint.emit(i, kind, strength)


func _noise_offset(tr: Entity) -> float:
	var p := tr.global_position
	var h := hash(Vector3i(roundi(p.x * 10.0), roundi(p.y * 10.0), roundi(p.z * 10.0)))
	return float(h & 0xFFFF) * 0.31


## Для вкладки Debug в InfoPanel
func get_debug_info() -> Array[String]:
	var res: Array[String] = []
	res.append("susp: %s  w x%.2f" % ["sleep" if _asleep else "awake", _w_scale])
	res.append("heave %.3f  pitch %.2f  roll %.2f" % [heave.x, rad_to_deg(pitch.x), rad_to_deg(roll.x)])
	res.append("sway %.3f  yaw %.2f" % [sway.x, rad_to_deg(yaw.x)])
	res.append("a_long %.2f  a_lat %.2f  hunt %.3f" % [_dbg_a_long, _dbg_a_lat, _dbg_hunt])
	return res
