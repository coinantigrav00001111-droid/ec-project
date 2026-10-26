# ATTN 12. Switch (стрелка), Crossing, Buffer Stop

Статус: **S1 (стрелка, ручная и дистанционная, электрика E0)**, **S2 (упор)**, **S3 (кросс)**, **S4 (правки по тестам)**, **S5 (раздельные цепи кросса)**, **S6 (E1, power routing стрелки)**. E2 впереди.
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
* **E1 (power routing, S6)**: ток идет от носка только на выбранную ветку. `SwitchSettings.power_routing` (по умолчанию false = E0).
  Сокет неактивной ветки мертвый (`C_Socket.set_socket_live`), PGM не ходит через него ни наружу, ни внутрь. Трак за невыбранной веткой
  обесточен, пока его не питает свой клип. При переключении `C_Switch` просит пересчет сети. Если выбранная ветка соединяет два
  разных контура, срабатывает обычное "столкновение контуров" PGM (в реальности КЗ между цепями). Слой электрики: невыбранная
  ветка без подсветки (в зоне носка рельсы двух веток лежат друг на друге, там возможно мерцание цвета). `set_power_routing(bool)`
  меняет режим в игре. Сохраняется в сейве.
* **E2 (токопроводящее сердечник, frog)**: полярность сердечника переключается вместе со стрелкой (контакты привода, реле, frog juicer); без нее КЗ при заезде на сердечник.
* **E3 (кросс)**: режимы joined (один проводник) и insulated (раздельные цепи), см. раздел про кросс. Сделано в S5.

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
* Электрика (E3): `CrossingConfig.separate_circuits` (по умолчанию true) делает два **независимых луча** (`C_PowerTrack.legs = 2`):
  у каждого пути свой контур и своя полярность, как у кросса с изолированными рамками. false: один проводник на оба пути
  (joined, как в S3), конфликт полярности даст КЗ в PGM.
  * `C_PowerTrack`: `contour_id` и `is_flipped` это луч 0 (старый код не меняется). `contour_of(leg)`, `flip_of(leg)`, `set_leg`, `reset`.
    Тележка спрашивает луч по `bogie.route`: `C_Engine`, `C_Bogie` (направление, поза), `C_Chassis.get_motion_axis`.
  * `C_Socket`: у каждого сокета ключ `leg` (луч), `leg_of_socket(i)`. У кросса сокеты 0,1 луч 0, сокеты 2,3 луч 1.
  * `power_grid_manager.gd`: обход ходит по парам (сущность, луч). Стык ищется по ближайшим сокетам (`_find_joint`),
    контур идет по лучу своего сокета и на другой путь кросса не переходит. Для остальных траков луч всегда 0, поведение прежнее.
  * Клип питания на кроссе питает путь 0 (стоит у его начала сбоку); путь 1 получает ток от соседей. `clip_transform()` у
    стрелки, кросса и упора теперь свой (с противоположной ответвлению стороны, на 6 ю от начала).
  * Слой электрики красит рельсы каждого пути по своему лучу, InfoPanel показывает "1 | 2".
  * Ограничение: сосед, касающийся кросса сразу двумя концами (короткое звено между путями), определяется по ближайшему стыку.
* Ограничения: только прямые пути; концы путей на расстоянии около 3.1 ю (при 15°), балласт соседних траков у концов
  может слегка пересечься.

## Правки по итогам тестов (S4)
* **Подсветка активного пути.** После перекладки (`on_switch_changed`, кроме init и load) `C_SwitchVisual` рисует ленту над
  рельсами активного маршрута: цвет как у рычага (прямо зеленый, ответвление янтарный), держится 1.5 с, гаснет 1 с
  (`FLASH_HOLD`, `FLASH_FADE`).
* **Замок и сход.** `C_Switch.is_occupied()` не считает вагон, у которого `C_Bogie.is_derailed` или `C_Chassis.is_on_rails = false`
  (current_track у его тележек еще указывает на стрелку, но она не держит).
* **Закрытый сокет.** `C_Socket._is_socket_occupied` для сокета с `monitoring = false` (закрытый стык упора, flex в растяжке)
  возвращает true (занят) без вызова `get_overlapping_areas()`. Ошибка при драге пропала, магнит такой сокет пропускает.
* **Ширина коллизии в конфиге.** `TrackConfig.collision_width` (0 = из `TrackStyle`, по умолчанию 3.2). `C_SwitchVisual` берет ее
  и правит копию стиля. Для C_StyleVisual (жесткие траки) можно читать так же: `identity.get_config('collision_width', 0.0)`.
* **auto_fit.** Концы веток стрелки разнесены на L * tan(a / 2), концы путей кросса на L * sin(a / 2). Если меньше
  `collision_width + end_clearance` (0.1), угол увеличивается (стрелка: только при `diverge_radius = 0`), иначе предупреждение
  в консоль. Для L = 23.9 и ширины 3.2 угол стрелки 15 -> 15.7, кросса 15 -> 15.9. Отключается `auto_fit = false`.

## Известные ограничения (S1-S3)
* Террейн: стрелка и кросс не `is_flat`, листы пенопласта под ними не подгоняются. `C_TrackSupport._notify_terrain` берет
  `ballast_samples()` по активной кривой.
* Тоннельный флаг (U) на стрелке и кроссе: свод и метка только по активной кривой (`C_Tunnel` и террейн знают одну кривую).

## Проверка
* `tests/switch_drive_test.tscn` (F6): 6 сценариев проезда через стрелку.
* `tests/buffer_stop_test.tscn` (F6): вагон в упор на скоростях 1.0, 1.5, 3.0.
* `tests/crossing_drive_test.tscn` (F6): вагон по путям A и B кросса, вперед и назад.
* `tests/crossing_power_test.tscn` (F6): раздельные контуры кросса.
* `tests/switch_power_test.tscn` (F6): E1, ток только на выбранную ветку, два сценария.
Ожидаемый результат в шапках скриптов.

`tests/switch_drive_test.tscn` (F6): 6 сценариев проезда вагона. Ожидаемый вывод в шапке скрипта.
