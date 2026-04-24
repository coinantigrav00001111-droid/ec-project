class_name ICapability extends Component
####################################
## 📦  Базовый класс для всех "способностей"
####################################

## === ЧТО ЭТО ===
# Интерфейс "что объект умеет"
# Используется Controller'ом

## === ПРИМЕРЫ ===
# IDraggable
# ISelectable
# IRotatable

# От них будут С_Draggable - такой же, но может быть С_Draggable_Wagon - а там другая логика, но оба от IDraggable

# Ничего не реализует — только контракт
## --- Пример способности перемещения ---

#class_name IDraggable extends ICapability
#
#func start_drag(hit_pos: Vector3): pass
#func update_drag(target_pos: Vector3, normal: Vector3): pass
#func end_drag(): pass
#
## --- Пример способности выбора ---
#class_name ISelectable extends ICapability
#
#func on_hover_start(): pass
#func on_hover_end(): pass
#func on_select(): pass
#func on_deselect(): pass
