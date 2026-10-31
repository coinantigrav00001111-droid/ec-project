# ATTN 12. Switch (стрелка), Crossing, Buffer Stop

Статус: **S1 (стрелка, ручная и дистанционная, электрика E0)**, **S2 (упор)**, **S3 (кросс)**, **S4 (правки по тестам)**, **S5 (раздельные цепи кросса)**, **S6 (E1, power routing стрелки)**, **S7 (E2, крестовина и КЗ; защита загрузки положения)**, **S8 (настройки в паспорт, вкладка «Стрелка»)**.
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
* **E1 (power routing, S6)**: ток идет от носка только на выбранную ветку. `SwitchConfig.power_routing` в паспорте (по умолчанию false = E0).
  Сокет неактивной ветки мертвый (`C_Socket.set_socket_live`), PGM не ходит через него ни наружу, ни внутрь. Трак за невыбранной веткой
  обесточен, пока его не питает свой клип. При переключении `C_Switch` просит пересчет сети. Если выбранная ветка соединяет два
  разных контура, срабатывает обычное "столкновение контуров" PGM (в реальности КЗ между цепями). Слой электрики: невыбранная
  ветка без подсветки (в зоне носка рельсы двух веток лежат друг на друге, там возможно мерцание цвета). `set_power_routing(bool)`
  меняет режим в игре. Сохраняется в сейве.
* **E2 (токопроводящая крестовина, frog, S7)**: `SwitchConfig.frog`. Внутренние рельсы двух путей пересекаются в крестовине и имеют
  разную полярность, поэтому у токопроводящей крестовины (electrofrog) ее полярность должна переключаться вместе со стрелкой.
  Режимы `C_Switch.Frog`:
  * `INSULATED` (по умолчанию): пластиковая крестовина, КЗ нет (поведение E0/E1);
  * `LIVE_FIXED`: крестовина привязана к пути 0. На пути 1 тележка в зоне крестовины (`FROG_HALF` = 1.5 ю вокруг `frog_s`) замыкает
    цепь: `PGM.trip_contour(cid, "frog")` отключает контур (как аварийный стоп, но один контур), стрелка вспыхивает красным,
    событие `on_switch_short {contour}`. Условие: у контура есть напряжение. Слежение включено только на пути 1;
  * `LIVE_SWITCHED`: полярность крестовины переключается вместе со стрелкой (контакты привода, реле, frog juicer в DCC): КЗ нет.
  При `power_routing = true` КЗ нет в любом режиме: ток на крестовину идет через остряки.
  Положение крестовины `frog_s` (по каждому пути) считается по геометрии: где ответвление ушло от оси на колею.
  Сброс отключенного контура: `PGM.reset_contour(cid)` или аварийный стоп выкл/вкл (`emergency_stop(false)`). `PGM.contour_tripped` для UI.
  Тип крестовины задается в паспорте (`SwitchConfig.frog`), в игре его меняет вкладка «Стрелка» инфопанели (`C_Switch.set_frog_mode()`). Мертвая зона пластиковой
  крестовины (короткие локо глохнут) и переключение крестовины аксессуаром (провода, Roadmap 13) не сделаны.
* **E3 (кросс)**: режимы joined (один проводник) и insulated (раздельные цепи), см. раздел про кросс. Сделано в S5.

## Упор (Buffer Stop, S2)
Прямой трак (одна кривая) с буферным брусом на конце. Пересобирает путь тем же визуалом, что стрелка
(`SwitchVisualSettings.lever = false`), своих сцен нет.

| Файл | Роль |
|---|---|
| `setting/buffer_stop_config.gd` | `BufferStopConfig` (наследует TrackConfig): radius = длина (11.9), stop_at_end, max_speed |
| `c_buffer_stop.gd` | физика стены, брус и стойки, закрытый стык |
| `bufferstop_setting.gd` | `BufferStopSettings` (адаптер: паспорт `BufferStopConfig` -> компонент) |
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

## Где живут настройки (S8)
Правило: **паспорт** (`C_Identity.object_config`, `SwitchConfig`, `CrossingConfig`, `BufferStopConfig`) хранит, что за объект, и
начальные параметры. Ресурс общий для всех экземпляров, в игре его не меняют. **Компонент** хранит состояние в игре (положение, режим,
тип крестовины), оно сохраняется в `save_data`. **ComponentSettings** это адаптеры: читают паспорт (`SwitchConfig.from_entity(entity)`,
типизированно) и переносят значения в поля компонента при создании. Компоненты стрелки, кросса и упора паспорт сами не читают и
`get_config` не вызывают.

| Паспорт | Поля |
|---|---|
| `TrackConfig` | `radius` (длина), `collision_width` (0 = из стиля) и прочие общие |
| `SwitchConfig` | `diverge_deg`, `diverge_radius`, `hand`, `start_route`, `auto_fit`, `end_clearance`, `control`, `throw_time`, `power_routing`, `frog` |
| `CrossingConfig` | `cross_deg`, `auto_fit`, `end_clearance`, `separate_circuits` |
| `BufferStopConfig` | `stop_at_end`, `max_speed`, `zeta` |

`SwitchSettings`, `SwitchShapeSettings`, `CrossingShapeSettings`, `BufferStopSettings` без своих полей. Значения, раньше лежавшие в `SwitchSettings`
(`power_routing` у `switch_r`, `frog` у `switch_wl_wood`), перенесены в паспорта этих `.tres`.
`C_Identity.get_config` устаревает: работает как раньше, но один раз предупреждает об имени, которого нет в конфиге.
Переход по семействам: стрелка, кросс, упор (S8), путь трака (S9), поезда (S10), осталось террейн; в конце функция удаляется.

**Путь трака (S9).** `PathSetting.apply_passport(path, entity)` единственное место, где путь читает паспорт (`TrackConfig`: `radius`, `deg`,
`rise`, `height`, `allow_underground`). Им пользуются `PathSetting`, `FlexVisualSetting`, `StyleVisualSetting`. `C_Path` паспорт не читает:
поля `has_passport`, `track_height`, `allow_underground` и прежние `radius/deg/rise` задает адаптер. Без паспорта `TrackConfig` путь не
строится (`push_error`), как и раньше молча. Поля `radius/deg` в `PathSetting` удалены: паспорт всегда имел приоритет (поле в `TrackConfig`
существует), поэтому поведение не меняется. В `.tres` у `g15`, `g119`, `g231`, `g239*`, `r1*`..`r4` остались лишние строки `radius`/`deg` в
блоке `PathSetting`: они безвредны, редактор уберет их при следующем сохранении файла.

**Вкладка «Стрелка»** (отладка, `info_panel.gd`, строится кодом): состояние, замок, контур, положение крестовины; кнопка «Переложить»
в обход рычага (`source = force`, замок под вагоном остается), управление Manual/Remote, галка power routing, тип крестовины.
Меняет состояние `C_Switch` (`set_control`, `set_power_routing`, `set_frog_mode`), паспорт не трогает.

**Поезда (S10).** Паспорт `WagonConfig` читает только адаптер, через `WagonConfig.from_entity(entity)` (типизированно). Компоненты получают значения
в поля при создании: `KinematicsSetting`, `EngineSetting`, `CouplerSetting` (как раньше, но типизированно), `TrainVisualSettings`
(`scene`, `bogie_configs`, `offset_mesh_y` задаются до `add_component`: базовый `C_Visual` строит вагон в `on_added`), `ChassisSetting`
(`bogie_configs`, `suspension_config`), `BogieSetting` (`bogie_configs`), `MechanismsSetting` (`mechanism_configs`, `light_configs`),
`TrainDraggableSettings` (`coupler_offset`). `C_TrainVisual`, `C_Bogie`, `C_Chassis`, `C_Mechanisms`, `C_TrainDraggable` паспорт не читают.
Без `WagonConfig` в паспорте адаптер пишет `push_error` и оставляет значения по умолчанию. Вкладка «Основное» (`main_tab.gd`): раньше читались
несуществующие поля `'power'` и `'maxspeed'` (всегда дефолт 0.0 и 700.0). Теперь у локомотива показываются `max_tractive_force` и
`max_theoretical_speed` из паспорта, у вагона «-»; масса по-прежнему `mass`.

## Правки по итогам тестов (S4)
* **Подсветка активного пути.** После перекладки (`on_switch_changed`, кроме init и load) `C_SwitchVisual` рисует ленту над
  рельсами активного маршрута: цвет как у рычага (прямо зеленый, ответвление янтарный), держится 1.5 с, гаснет 1 с
  (`FLASH_HOLD`, `FLASH_FADE`).
* **Замок и сход.** `C_Switch.is_occupied()` не считает вагон, у которого `C_Bogie.is_derailed` или `C_Chassis.is_on_rails = false`
  (current_track у его тележек еще указывает на стрелку, но она не держит).
* **Закрытый сокет.** `C_Socket._is_socket_occupied` для сокета с `monitoring = false` (закрытый стык упора, flex в растяжке)
  возвращает true (занят) без вызова `get_overlapping_areas()`. Ошибка при драге пропала, магнит такой сокет пропускает.
* **Ширина коллизии в конфиге.** `TrackConfig.collision_width` (0 = из `TrackStyle`, по умолчанию 3.2). `C_SwitchVisual` берет ее
  и правит копию стиля. Для C_StyleVisual (жесткие траки) читается так же: `(identity.object_config as TrackConfig).collision_width`.
* **auto_fit.** Концы веток стрелки разнесены на L * tan(a / 2), концы путей кросса на L * sin(a / 2). Если меньше
  `collision_width + end_clearance` (0.1), угол увеличивается (стрелка: только при `diverge_radius = 0`), иначе предупреждение
  в консоль. Для L = 23.9 и ширины 3.2 угол стрелки 15 -> 15.7, кросса 15 -> 15.9. Отключается `auto_fit = false`.

## Сохранение положения стрелки (S7)
Баг: положение после переключения не восстанавливалось из сейва. Причину по коду однозначно найти не удалось, добавлена защита:
`C_Switch` помнит, что `load_data` уже отработал (`_loaded`), и `on_entity_ready` не сбрасывает положение в стартовое.
Диагностика: `tests/switch_save_test.tscn` проходит весь путь save -> ResourceSaver -> load -> load_data и по шагам показывает,
где положение теряется (если после S7 баг остался, пришлите вывод).

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
* `tests/switch_frog_test.tscn` (F6): E2, крестовина и КЗ, 6 сценариев.
* `tests/switch_save_test.tscn` (F6): диагностика сохранения положения стрелки.
Ожидаемый результат в шапках скриптов.

`tests/switch_drive_test.tscn` (F6): 6 сценариев проезда вагона. Ожидаемый вывод в шапке скрипта.
