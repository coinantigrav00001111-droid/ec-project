class_name TrackStyleSetIO extends RefCounted

## Track Studio: добавить сохранённый стиль строкой в набор стилей проекта (setting/track_style_set.tres).
## Заменяет «тестовый объект в каталог» (ATTN_17 §17.13, C4): кнопки каталога стиль не знают, новый стиль
## появляется в списке стилей сессии и новые траки любой формы строятся в нём.


## Проверка перед добавлением: {"ok": bool, "already": bool, "error": String}.
## already = этот же файл стиля уже в наборе (ok = true, добавлять не нужно)
static func check_add(set_: TrackStyleSet, style: TrackStyle, path: String) -> Dictionary:
	var fail := func(msg: String) -> Dictionary:
		return {"ok": false, "already": false, "error": msg}
	if set_ == null:
		return fail.call("Набор стилей проекта не загружен")
	if style == null or path.is_empty():
		return fail.call("Сначала сохраните стиль (Ctrl+S): в набор попадает файл стиля")
	if style.use_scene:
		return fail.call("Стиль-сцена (budget) в набор через Studio не добавляется")
	if not TrackStyleIO.is_valid_id(String(style.id)):
		return fail.call("Недопустимый id стиля '%s'" % style.id)
	for st in set_.styles:
		if st == null or st.id != style.id:
			continue
		if st.resource_path == path:
			return {"ok": true, "already": true, "error": ""}
		return fail.call("В наборе уже есть другой стиль с id '%s' (%s)" % [style.id, st.resource_path])
	return {"ok": true, "already": false, "error": ""}


## Добавляет файл стиля в набор проекта (TSM) и записывает набор. Результат как у check_add плюс "id"
static func add_to_project(path: String) -> Dictionary:
	# REPLACE: взять с диска свежую версию, а не кэш (стиль мог быть только что сохранён)
	var style := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as TrackStyle
	var r := check_add(TSM.style_set, style, path)
	if style != null:
		r["id"] = style.id
	if not r["ok"] or r["already"]:
		return r
	var err := TSM.add_style(style)
	if err != OK:
		return {"ok": false, "already": false, "error": "Не удалось записать набор стилей (код ошибки %d)" % err, "id": style.id}
	return r
