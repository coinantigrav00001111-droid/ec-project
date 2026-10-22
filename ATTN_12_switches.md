# ATTN 12. Switch (стрелка), Crossing, Buffer Stop

Статус: **S1 (стрелка, ручная и дистанционная, электрика E0)** сделан. Кросс, упор, E1-E3 впереди.

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

## Проверка
`tests/switch_drive_test.tscn` (F6): 6 сценариев проезда вагона. Ожидаемый вывод в шапке скрипта.
