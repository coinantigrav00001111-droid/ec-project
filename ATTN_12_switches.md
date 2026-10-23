# ATTN 12. Switch (стрелка), Crossing, Buffer Stop

Статус: **S1 (стрелка, ручная и дистанционная, электрика E0)**, **S2 (упор)**, **S3 (кросс)** написаны. E1-E3 впереди.
S1 прогнан в headless Godot 4.6 (логика и проезд вагона). S2 и S3 написаны без запуска Godot, проверка за вами
(tests/buffer_stop_test.tscn, tests/crossing_drive_test.tscn). Серия перенесена на main c8ff188 (тоннели T6 и др.).

## Принцип
Стрелка = один Entity и один C_Path с несколькими кривыми (`routes`). В системе координат Path3D общий носок в начале.
`C_Path.curve` и `path_node.curve` всегда указывают на **активный** маршрут, поэтому вагон (C_Bogie, C_Chassis,
C_TrainDraggable) видит только его и о стрелках ничего не знает. Всей геометрии (опоры, сокеты, коллизии, проверка
"под землей") нужен `C_Path.all_curves()`.

Построение по логике flex, но форма статична: `C_SwitchShape` строит кривые один раз (`C_Path.set_routes`),
`C_SwitchVisual` строит меш, шпалы и коллизии по `TrackStyle` через `TrackMeshBuilder` (общий код с flex и будущими
жесткими траками). Сцен из Blender нет.

## Компоненты
| Файл | Роль |
|---|---|
| `setting/switch_config.gd` | `SwitchConfig` (наследует TrackConfig): radius = длина прямой, diverge_deg, diverge_radius (0 = L/sin a, торцы на одной линии), hand (+1 правая, -1 левая), start_route |
| `c_switch_shape.gd` | кривые маршрутов 0 (прямой) и 1 (ответвление) |
| `c_switch_visual.gd` | меш и шпалы на каждый маршрут, общий пул коллизий, рычаг (слой handles, мета `switch_lever`) |
| `c_switch.gd` | положение, MANUAL / REMOTE, время перекладки, замок под вагоном, save/load |
| `c_path.gd` (+блок `claude-switch`) | `routes`, `active_route`, `set_routes`, `set_active_route`, `all_curves`, `accepts_entry` |
| `c_socked.gd` | сокеты со всех маршрутов: [0] носок, [1] конец прямой, [2] конец ответвления |
| `c_bogie.gd` | `accepts_entry` при въезде на трак; группа `bogie_owner` для замка |
| `c_tracksupport.gd` | опоры под всеми маршрутами |
| `power_grid_manager.gd` | `_calc_flip`: начало маршрута из флага сокета `start` (S3) |
| `select_tool.gd` | `_try_press_lever`: клик по рычагу без выделения |

Порядок в .tres: Identity, SwitchVisual, Draggable, Pivot, Hoverable, Selectable, Blockable, Path, **SwitchShape**,
Socket, PowerTrack, TrackSupport, **Switch**. Объекты: `data/tracks/objects/switch_r.tres`, `switch_l.tres` (тег `switch`).

## Правила
* Въезд на стрелку только у концов активного маршрута (`accepts_entry`). С неактивной ветки: тележка не находит
  трак и сходит (`bogie derailed`). Пошерстное проезд с перекладкой (spring switch) пока нет.
* Замок: пока тележка стоит на стрелке, команда отклоняется (`occupied`), в том числе `force`.
* `C_Switch.Drive.MANUAL`: рычаг (клик). `REMOTE`: рычаг заблокирован, команды `on_switch_request {route, source=remote}`.
  `throw_time` > 0: состояние MOVING, ветка меняется по окончании хода. Временная кнопка пульта: **T** по выбранной стрелке.
* События: `on_switch_request`, `on_lever_pressed`; исходящие `on_switch_changed`, `on_switch_moving`,
  `on_switch_rejected`, `on_routes_changed`, `on_route_activated`. `on_curve_changed` стрелка НЕ шлет (это событие flex).
* Террейн: стрелка не `is_flat`, листы под ней не подгоняются (отдельная задача).

## Электрика
* **E0 (сделано)**: стрелка один проводящий трак, оба ответвления всегда под током, один контур. Полярность по
  `_calc_flip` работает как есть (сокет 0 = начало, 1 и 2 = конец). Реверсивная петля через стрелку дает существующее КЗ полярности.
* **E1 (power routing)**: ток только на выбранную ветку. План: `is_socket_live(i)` и проверка в обходе PGM, пересчет по `on_switch_changed`.
* **E2 (токопроводящее сердечник, frog)**: полярность сердечника переключается вместе со стрелкой (контакты привода, реле, frog juicer); без нее КЗ при заезде на сердечник.
* **E3 (кросс)**: режимы joined (один контур и полярность) и insulated.

## Упор (Buffer Stop, S2)
Прямой трак (одна кривая) с буферным брусом на конце. Пересобирает путь тем же визуалом, что стрелка
(`SwitchVisualSettings.lever = false`), своих сцен нет.

| Файл | Роль |
|---|---|
| `setting/buffer_stop_config.gd` | `BufferStopConfig` (наследует TrackConfig): radius = длина (11.9), stop_at_end, max_speed |
| `c_buffer_stop.gd` | физика стены, брус и стойки, закрытый стык |
| `bufferstop_setting.gd` | `BufferStopSettings` (zeta) |
| `data/tracks/objects/buffer_stop.tres` | объект, тег `buffer` |

Физика (формулы как у контакта буферов в `C_Coupler`, партнер неподвижен, приоритет -10, до `C_Chassis`):
* стена стоит в конце кривой; торец вагона (`offset_z` у `C_Coupler`) считаем в плоскости XZ;
* первый контакт: dv = (1 + e) * v_close. Если dv > `impact_dv_limit` вагона или v_close > `max_speed` упора,
  вагон сходит (`on_derailed`, reason `buffer_stop_impact`), иначе отскок на буферах;
* дальше сила пружины с демпфером и жестким упором ходом буфера вагона (`buffer_travel`), уходит в шасси как `on_coupler_force`;
* вагону те же события, что при ударе сцепок (`on_coupler_impact`), упору наружу `on_buffer_impact`;
* сокет у стены выключается (`on_socket_enabled`), пристыковаться можно только открытым концом.
Порядок в .tres: ... Path, Socket, PowerTrack, TrackSupport, **BufferStop** (после Socket).

## Кросс (Crossing, S3)
Один Entity, два прямых пути (`routes`), пересекающихся в центре под `cross_deg` (15). В отличие от стрелки
**оба пути активны сразу**: `C_Path.parallel_routes = true`, а какой путь у вагона, хранит тележка (`BogieData.route`).

* `C_Path.curve_of(r)`: кривая пути r. Обычному траку и стрелке отдает активную `curve` и номер игнорирует, поэтому
  остальной код работает как раньше.
* `C_Path.entry_route(gpos)`: на какой путь въезжает тележка (по концу пути, -1 = закрыто). Пользуется `C_Bogie` при переходе.
* `C_Path.route_at(local_pos)`: путь, ближайший к точке. Нужен при посадке вагона на кросс мышью
  (`C_TrainDraggable`) и при загрузке сейва (`C_Chassis.restore_snap_after_load`). В сейв номер не пишем, он считается по положению.
* Правки в `C_Bogie`, `C_Chassis`, `C_TrainDraggable`: везде, где читалась `path_comp.curve`, теперь `curve_of(route)`;
  `route` приходит в `track_data` (`on_train_snapped {track, offset, route}`).
* Сокеты кросса: [0] начало 0, [1] конец 0, [2] начало 1, [3] конец 1. У сокетов новый флаг `start` (начало маршрута),
  PGM берет его в `_calc_flip` вместо `id == 0` (для старых траков значение то же).
* Файлы: `setting/crossing_config.gd` (`cross_deg`), `c_crossing_shape.gd`, `crossingshape_setting.gd`,
  `data/tracks/objects/crossing.tres` (тег `crossing`). Визуал тот же `C_SwitchVisual` без рычага.
* Электрика (упрощение E3 joined): один `C_PowerTrack` на оба пути, один контур и одна полярность. Конфликт полярности
  между путями даст обычное КЗ PGM. В реальности рамки кросса изолируют, раздельные контуры путей (insulated)
  потребуют `C_PowerTrack` на каждый путь: следующий этап.
* Ограничения: только прямые пути; концы путей на расстоянии около 3.1 ю (при 15°), балласт соседних траков у концов
  может слегка пересечься.

## Известные ограничения (S1-S3)
* Террейн: стрелка и кросс не `is_flat`, листы пенопласта под ними не подгоняются. `C_TrackSupport._notify_terrain` берет
  `ballast_samples()` по активной кривой.
* Тоннельный флаг (U) на стрелке и кроссе: свод и метка только по активной кривой (`C_Tunnel` и террейн знают одну кривую).

## Проверка
* `tests/switch_drive_test.tscn` (F6): 6 сценариев проезда через стрелку.
* `tests/buffer_stop_test.tscn` (F6): вагон в упор на скоростях 1.0, 1.5, 3.0.
* `tests/crossing_drive_test.tscn` (F6): вагон по путям A и B кросса, вперед и назад.
Ожидаемый результат в шапках скриптов.

`tests/switch_drive_test.tscn` (F6): 6 сценариев проезда вагона. Ожидаемый вывод в шапке скрипта.
