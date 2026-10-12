class_name RailPhysics extends RefCounted

########################
## Общие константы и формулы для C_Chassis (рельсы) и C_Kinematics (стол).
## Меняешь здесь - меняется и там, и там.
########################

## g для качения/тяги (как было в шасси, roll_resistance не ломается)
const G_ROLL := 9.8
## Тот же временной масштаб, что у вертикального ассиста (C_Kinematics._assist_vertical)
const VERTICAL_SCALE := 80.0
## g для скольжения корпусом / боковой юз
const G_SLIDE := 9.8 * VERTICAL_SCALE
## Пинок: J = power_kick * K [Н*с], dv = J / m. Одинаково на рельсах и на столе
const KICK_IMPULSE_K := 2.0


## dv за шаг от кулоновского трения. Не даёт трению развернуть скорость.
static func friction_dv(v: float, mu: float, g: float, dt: float) -> float:
	return -signf(v) * minf(mu * g * dt, absf(v))
