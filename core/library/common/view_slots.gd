class_name ViewSlots extends RefCounted

# XX claude-library (новый файл)
########################
## ViewSlots. Шесть слотов ракурсов экрана Library (ATTN_22 §22.7.1, шаг L2)
########################
## Слот это словарь StudioWorld.capture_slot(): yaw, pitch, ortho, fov, zoom, pivot (Vector3, доля диагонали).
## Хранятся в user://library.cfg (ConfigFile хранит Vector3). Значения по умолчанию те же, что у Icon Studio.
## sanitize принимает всё, что вернул ConfigFile: неверный тип или неполный слот заменяется слотом по умолчанию.

const COUNT := 6
## yaw, pitch, ortho: 3/4 сверху, борт, перед, вид сверху, борт ортогонально, 3/4 сзади
const DEFAULTS := [
	[35.0, -25.0, false], [90.0, 0.0, false], [0.0, 0.0, false],
	[35.0, -89.0, false], [90.0, 0.0, true], [-35.0, -25.0, false],
]


static func defaults() -> Array:
	var out: Array = []
	for v in DEFAULTS:
		out.append({"yaw": v[0], "pitch": v[1], "ortho": v[2], "fov": 30.0, "zoom": 1.0, "pivot": Vector3.ZERO})
	return out


static func sanitize(raw: Variant) -> Array:
	var out := defaults()
	if raw is Array:
		var a: Array = raw
		for i in mini(COUNT, a.size()):
			if _is_valid(a[i]):
				out[i] = (a[i] as Dictionary).duplicate()
	return out


static func _is_valid(x: Variant) -> bool:
	if not (x is Dictionary):
		return false
	var d: Dictionary = x
	for k in ["yaw", "pitch", "fov", "zoom"]:
		if not (d.get(k) is float or d.get(k) is int):
			return false
	if not (d.get("ortho") is bool):
		return false
	return d.get("pivot") is Vector3
