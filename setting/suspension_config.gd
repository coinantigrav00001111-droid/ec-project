class_name SuspensionConfig extends Resource

########################
## Паспорт подвески кузова одного типа вагона.
## Цепляется в WagonConfig.suspension. Если там null - C_Chassis возьмёт SuspensionConfig.new() (значения ниже).
########################
## Единицы: длины - юниты Godot, скорости - ю/с, ускорения - ю/с², углы - градусы.

@export_category("Mass")
## Масса "эталонного" вагона. Частоты ниже заданы для неё.
## Тяжелее -> ниже частоты и слабее удары; легче -> наоборот (с ограничением, см. SuspensionState.setup).
@export var ref_mass: float = 1.0

@export_category("Body modes (частота при ref_mass, Гц / демпфирование ζ)")
## 2-6 Гц хорошо читаются на экране, выше ~8 Гц превращается в мерцание.
@export_range(0.5, 8.0, 0.1) var heave_hz: float = 3.5
@export_range(0.05, 1.0, 0.01) var heave_zeta: float = 0.30
@export_range(0.5, 8.0, 0.1) var pitch_hz: float = 2.6
@export_range(0.05, 1.0, 0.01) var pitch_zeta: float = 0.28
@export_range(0.5, 8.0, 0.1) var roll_hz: float = 3.0
@export_range(0.05, 1.0, 0.01) var roll_zeta: float = 0.25
@export_range(0.5, 8.0, 0.1) var sway_hz: float = 2.2
@export_range(0.05, 1.0, 0.01) var sway_zeta: float = 0.35
@export_range(0.5, 8.0, 0.1) var yaw_hz: float = 2.0
@export_range(0.05, 1.0, 0.01) var yaw_zeta: float = 0.40

@export_category("Travel limits (упоры)")
@export var limit_heave: float = 0.05       ## ход по вертикали, ю (бывш. vertical_travel_y)
@export var limit_sway: float = 0.03         ## боковой люфт, ю (бывш. lateral_play_x)
@export var limit_pitch_deg: float = 3.0
@export var limit_roll_deg: float = 4.0
@export var limit_yaw_deg: float = 1.5

@export_category("Response to acceleration")
## Кивок: угол при насыщении и ускорение, при котором достигается ~76% от него (tanh).
@export var pitch_accel_deg: float = 2.0
@export var pitch_accel_ref: float = 4.0
## Крен в кривой: угол при насыщении и боковое ускорение, при котором ~76%.
@export var roll_accel_deg: float = 3.0
@export var roll_accel_ref: float = 6.0
## Смещение кузова наружу кривой на рессорах при насыщении, ю
@export var sway_accel_shift: float = 0.02
## Доп. крен при максимальном боковом смещении (кузов "ложится" в сторону смещения)
@export var sway_roll_deg: float = 1.0

@export_category("Track input (стыки и неровности)")
## 0 - стыки только на границах траков. >0 - ещё и внутри длинного трака через каждые N юнитов.
@export var joint_spacing: float = 0.0
## Вертикальный толчок на стыке: (ю/с) на каждый ю/с скорости движения
@export var joint_kick: float = 0.12
## Во сколько раз сильнее толчок на границе траков, чем на внутреннем стыке
@export var joint_track_gain: float = 1.5
## Доля бокового толчка от вертикального
@export var joint_lateral_ratio: float = 0.35
## Скорость, выше которой толчок уже не растёт
@export var joint_speed_cap: float = 20.0
## Неровности пути: амплитуда по вертикали/в сторону (ю) и длина волны (ю). Привязаны к ТРАКУ, не ко времени.
@export var irregularity_vertical: float = 0.010
@export var irregularity_lateral: float = 0.006
@export var irregularity_wavelength: float = 8.0

@export_category("Hunting (рыскание тележек)")
## Скорость, около которой вагон начинает рыскать. Двухосные модели - ниже.
@export var hunting_v_crit: float = 22.0
## Длина волны рыскания, ю (от времени не зависит - привязана к пути).
## Две тележки качаются со сдвигом фаз база/длина_волны: при волне ≈ 2×база они в противофазе,
## кузов почти не едет в сторону и только рыскает (yaw). Волна ≈ 3-4×база даёт заметный боковой сдвиг.
@export var hunting_wavelength: float = 16.0
## Амплитуда бокового смещения тележек, ю
@export var hunting_amp: float = 0.02
## Подпитка рыскания от изменения бокового ускорения (вход/выход из кривой)
@export var hunting_curve_gain: float = 0.10

@export_category("Geometry")
## Высота (от начала координат вагона), вокруг которой кренится и кивает кузов
@export var pivot_height: float = 0.8
