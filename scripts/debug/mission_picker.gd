extends CanvasLayer
## Debug: the mission picker. In a debug build F8 (anywhere in the town, also with the game
## menu open) opens a list of every mission (Story.missions, data/missies) with its steps
## under it; W/S or the arrows choose (Page Up/Down: from mission to mission), Enter jumps
## there, Escape or F8 closes. A jump loads the town again and goes to the start of the
## mission, or to the step chosen with the steps before it done (MissionJump.start_in_game,
## the same as `-- --snel --missie 2 --stap hofvijver`), so also back to an earlier one.
## In the list: ✓ done, ▶ under way (the step you are at), · not yet. Under it the other debug
## keys (DebugKeys.HELP: money, XP, the stats), which also work with it open.
## The HUD puts it in the town (GameHud._ready, debug builds only).

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const MissionJump = preload("res://scripts/debug/mission_jump.gd")
const DebugKeys = preload("res://scripts/debug/debug_keys.gd")

const KEY_OPEN := KEY_F8
const PANEL_SIZE := Vector2(760, 640)
const SELECTED_COLOUR := UiStyle.ACCENT

## The Story node (scripts/story/story.gd) of the town; found in the current scene when empty.
var story: Node

var _was_paused := false
var _entries: Array[Dictionary] = []   # per row: {"mission", "step" ("" = the mission itself)}
var _rows: Array[Label] = []
var _selected := 0
var _list: VBoxContainer
var _scroll: ScrollContainer
var _font_pixel: Font
var _font_body: Font


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_font_pixel = UiStyle.font(UiStyle.FONT_PIXEL)
	_font_body = UiStyle.font(UiStyle.FONT_BODY)
	_build()


func is_open() -> bool:
	return visible


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).keycode
	if not visible:
		if key == KEY_OPEN:
			open()
			get_viewport().set_input_as_handled()
		return
	match key:
		KEY_OPEN, KEY_ESCAPE:
			close()
		KEY_W, KEY_UP:
			_select(_selected - 1)
		KEY_S, KEY_DOWN:
			_select(_selected + 1)
		KEY_PAGEUP:
			_select(_mission_row(-1))
		KEY_PAGEDOWN:
			_select(_mission_row(1))
		KEY_ENTER, KEY_KP_ENTER:
			jump()
	# while open no key reaches the game
	get_viewport().set_input_as_handled()


## Opens on the list of the missions, on the step under way (or the first row).
func open() -> void:
	if story == null:
		var scene := get_tree().current_scene
		story = scene.get_node_or_null("Verhaal") if scene else null
	if story == null or not ("missions" in story) or story.missions.is_empty():
		push_warning("missiekiezer: geen verhaal met missies in deze scène")
		return
	_fill()
	_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	_select(_row_under_way())


func close() -> void:
	visible = false
	get_tree().paused = _was_paused


## The row chosen: {"mission", "step"} (for the checks).
func selected_entry() -> Dictionary:
	return _entries[_selected] if _selected < _entries.size() else {}


## Jumps to the row chosen (MissionJump.start_in_game).
func jump() -> void:
	var entry := selected_entry()
	if entry.is_empty():
		return
	print("missiekiezer: naar %s%s" % [entry.mission, (", stap " + String(entry.step)) if entry.step != "" else ""])
	visible = false
	MissionJump.start_in_game(get_tree(), String(entry.mission), String(entry.step))


# ------------------------------------------------------------------ the list

func _fill() -> void:
	for row in _list.get_children():
		_list.remove_child(row)
		row.queue_free()
	_entries.clear()
	_rows.clear()
	for data: Dictionary in story.missions:
		var mission_id := String(data.id)
		var started: bool = story.is_started(mission_id)
		var finished: bool = story.is_finished(mission_id)
		var mark := "✓" if finished else ("▶" if started else "·")
		_add_row({"mission": mission_id, "step": ""},
				"%s %s · %s" % [mark, String(data.get("label", mission_id)), String(data.get("titel", ""))], true)
		var under_way_found := false
		for step_data: Dictionary in data.get("stappen", []):
			var step_id := String(step_data.id)
			var step_mark := "·"
			if story.step_done(mission_id, step_id) or finished:
				step_mark = "✓"
			elif started and not under_way_found:
				step_mark = "▶"
				under_way_found = true
			var text := String(step_data.get("tekst", "")).replace("\n", " ")
			if text.length() > 60:
				text = text.left(58) + "…"
			_add_row({"mission": mission_id, "step": step_id}, "    %s %s — %s" % [step_mark, step_id, text], false)


func _add_row(entry: Dictionary, text: String, is_mission: bool) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _font_pixel if is_mission else _font_body)
	label.add_theme_font_size_override("font_size", 15 if is_mission else 14)
	label.add_theme_color_override("font_color", UiStyle.TEXT if is_mission else UiStyle.MUTED)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(label)
	_entries.append(entry)
	_rows.append(label)


## The row of the step under way of the first mission under way (else the first row).
func _row_under_way() -> int:
	for index in _rows.size():
		if _rows[index].text.strip_edges().begins_with("▶") and _entries[index].step != "":
			return index
	return 0


## The row of the next (+1) or previous (-1) mission from the one chosen.
func _mission_row(direction: int) -> int:
	var index := _selected
	while true:
		index += direction
		if index < 0 or index >= _entries.size():
			return _selected
		if _entries[index].step == "":
			return index
	return _selected


func _select(index: int) -> void:
	if _rows.is_empty():
		return
	_selected = clampi(index, 0, _rows.size() - 1)
	for row_index in _rows.size():
		var is_mission: bool = _entries[row_index].step == ""
		var colour := SELECTED_COLOUR if row_index == _selected else (UiStyle.TEXT if is_mission else UiStyle.MUTED)
		_rows[row_index].add_theme_color_override("font_color", colour)
	_scroll.ensure_control_visible.call_deferred(_rows[_selected])


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.INK, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	var style := UiStyle.box_style(UiStyle.PANEL, UiStyle.ACCENT, 3)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "◆ DEBUG · NAAR MISSIE OF TAAK"
	heading.add_theme_font_override("font", _font_pixel)
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", UiStyle.ACCENT)
	column.add_child(heading)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	column.add_child(_build_key_help())
	var footer := Label.new()
	footer.text = "[W/S] KIES   [PGUP/PGDN] MISSIE   [ENTER] SPRING (STAD LAADT OPNIEUW)   [ESC] DICHT"
	footer.add_theme_font_override("font", _font_pixel)
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", UiStyle.MUTED)
	column.add_child(footer)


## The other debug keys (DebugKeys.HELP) in two columns: key, what it does (Shift: what then).
func _build_key_help() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var heading := Label.new()
	heading.text = "DEBUGTOETSEN (OOK MET DIT SCHERM OPEN)"
	heading.add_theme_font_override("font", _font_pixel)
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", UiStyle.ACCENT)
	box.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	for entry: Array in DebugKeys.HELP:
		var line := Label.new()
		line.text = "%s  %s   ⇧ %s" % entry
		line.add_theme_font_override("font", _font_body)
		line.add_theme_font_size_override("font_size", 13)
		line.add_theme_color_override("font_color", UiStyle.MUTED)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(line)
	return box
