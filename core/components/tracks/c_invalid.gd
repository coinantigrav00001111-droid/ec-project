class_name C_Invalid extends Component

# XX claude-terra (новый файл)
#######################
## State. Флаг активности. Невалидная геометрия (flex вне пределов r/L/уклона или уходит под землю).
## Красит призрак как blocked и запрещает постановку в BuildTool. Не путать с C_Blocked:
## C_Blockable сам снимает его по overlaps.
#######################

func on_added():
	name = 'C_Invalid'


func _init():
	is_state = true
