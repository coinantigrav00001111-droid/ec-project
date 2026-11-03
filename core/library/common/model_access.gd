class_name ModelAccess extends RefCounted

# XX claude-library (новый файл)
########################
## ModelAccess. Открыта ли модель игроку и текст условия открытия (ATTN_22 §22.4, §22.7.1, шаг L2)
########################
## Открыта, если каталог открыт правилами (песочница, debug.all), игрок открыл модель (профиль),
## у модели нет паспорта или в паспорте условие «free». Иначе закрыта: условие в паспорте (xp, chapter, kit).
## Закрытая модель остаётся серым силуэтом с условием, ничего не блокируя и не наказывая (ATTN_22 §22.3 п. 5).


static func is_open(rules: LibraryRules, profile: LibraryProfile, key: StringName, info: ModelInfo) -> bool:
	if rules != null and rules.catalog_open():
		return true
	if profile != null and profile.is_owned(key):
		return true
	return info == null or info.unlock_kind() == "free"


## Условие открытия для игрока; пусто у свободных моделей
static func condition_text(info: ModelInfo) -> String:
	if info == null:
		return ""
	match info.unlock_kind():
		"xp":
			return "Откроется за %d опыта." % info.xp_cost()
		"chapter":
			return "Откроется в главе «%s»." % str(info.unlock.get("id", ""))
		"kit":
			return "Откроется после сборки набора."
	return ""
