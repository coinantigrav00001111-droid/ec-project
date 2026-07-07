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
# ISnappable



# От них будут С_Draggable - такой же, но может быть С_Draggable_Wagon - а там другая логика, но оба от IDraggable
# или C_Socket extends ISnappable притягиваемая способность у сокет

# 💡C_Path тоже способность, хоть и не имеет контракта типа IPathable, потому что пока нет в дальнейшем вариантов этого C_Path. Хотя при необходимости можно переделать, но пока:
#class_name C_Path extends ICapability

# Ничего не реализует — только контракт
## --- Пример способности перемещения ---

#class_name IDraggable extends ICapability
## --- Пример способности выбора ---
#class_name ISelectable extends ICapability
