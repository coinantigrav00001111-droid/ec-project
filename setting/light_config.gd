class_name LightConfig extends Resource

########################
## Описание одного источника света вагона/локо/здания. Массив лежит в WagonConfig.lights.
## Исполняет C_Mechanisms (общий компонент механизмов и света, ATTN_16_mechanisms.md).
########################
## Источник создаётся КОДОМ в точке из этого конфига, в сцене модели маркеры ставить не нужно.
## Реализованы: kind = SPOT / OMNI, rule = COMMAND / NIGHT / DIRECTION / ALWAYS.
## Остальное - заготовки под следующие шаги (EMISSIVE: L6, правила POWERED и SPEED: L8, ROUTE: L7).
##
## Координаты. Если anchor_role пусто, позиция считается в системе корня сцены модели (instance):
##   то же пространство, что у bogie_configs и coupler_offset. Ось -Z = FRONT (нос), +Z = REAR (хвост),
##   +Y вверх, +X вправо по ходу. Если anchor_role задан, позиция в системе этого узла (например, фара на двери).
## Направление. SpotLight светит вдоль своей оси -Z. rotation_deg = (0, 0, 0) значит "светит вперёд (в нос)".
##   Фара назад: (0, 180, 0). Наклон вниз: rotation_deg.x < 0 (например, -8).
## Единицы: 1 юнит = 1 см модели, стол 200 x 100. Дальность фары около 20-40, окна дома около 10-20.

enum Kind { SPOT, OMNI, EMISSIVE }
## Кто выставляет состояние. COMMAND: только игрок. NIGHT: по времени суток. DIRECTION: по направлению движения.
## ALWAYS: горит с создания. POWERED, SPEED, ROUTE пока заготовки.
## Команда игрока (InfoPanel, I) ставит manual и перекрывает правило до события-сброса:
## смена времени суток (NIGHT), смена направления (DIRECTION), кнопка "Авто" в InfoPanel.
enum Rule { COMMAND, NIGHT, DIRECTION, POWERED, SPEED, ROUTE, ALWAYS }
## DIRECTION: к какому торцу относится источник
enum End { FRONT, REAR }

## Предел множителя яркости в InfoPanel
const GAIN_MAX := 2.0

@export var id: StringName = &"headlight_front"
## Подпись для InfoPanel
@export var title: String = "Фара"

@export_category("Что и как светит")
@export var kind: Kind = Kind.SPOT
@export var rule: Rule = Rule.COMMAND
## DIRECTION: горит, когда состав идёт этим торцем вперёд. FRONT - нос (-Z), REAR - хвост (+Z).
## Пока стоит, остаётся направление последнего движения (до первого движения - нос вперёд)
@export var dir_end: End = End.FRONT
## NIGHT: id времён суток (GFX), когда горит
@export var night_times: PackedStringArray = ["evening", "night"]

@export_category("Где")
## Роль узла-родителя (Custom Property "role" либо имя узла). Пусто: корень сцены модели
@export var anchor_role: StringName = &""
@export var anchor_aliases: PackedStringArray = []
## Позиция в системе родителя
@export var position: Vector3 = Vector3.ZERO
## Поворот в градусах. Для SPOT: куда светит (по умолчанию в нос)
@export var rotation_deg: Vector3 = Vector3.ZERO

@export_category("Свет")
@export var color: Color = Color(1.0, 0.95, 0.8)
## Энергия при состоянии 1.0
@export var energy: float = 2.0
## Стартовый множитель яркости (в игре меняется слайдером в InfoPanel, 0..GAIN_MAX)
@export_range(0.0, 2.0) var brightness: float = 1.0
## Дальность, юниты
@export var light_range: float = 30.0
## SPOT: половина угла конуса, градусы
@export_range(1.0, 89.0) var spot_angle: float = 35.0
## SPOT: затухание к краю конуса (больше - мягче край)
@export var spot_attenuation: float = 1.0

@export_category("Состояние")
## Секунд на полное включение или выключение
@export var fade_time: float = 0.25
## Состояние при создании: 0 = выключен, 1 = горит
@export_range(0.0, 1.0) var start_state: float = 0.0
## false: команды игнорируются, источник остаётся как есть
@export var enabled: bool = true
