extends Control
## The level-up screen of the HUD (GameHud.show_level_up): a level up is a screen of its own in
## which you choose one of your stats to make stronger. Over the dimmed world (the game
## paused), in the style of the reward screen (UiStyle: INK panel, ACCENT frame, pixel fonts):
## - at the top "LEVEL OMHOOG" and the new level big ("LEVEL 3"), with the XP that did it
##   ("+150 XP") when it came with a reward (GameHud.show_reward: one screen for both);
## - one row per stat (OPTIONS): its icon and colour (GameHud.STATS / PIXEL_ICONS), its name,
##   what it does for you and its maximum now -> after;
## - at the bottom the keys.
## W/S or the arrows choose, 1..4 pick at once, Enter, Space or E (or a click on a row) takes it.
## The choice goes to `choose` (PlayerController.raise_stat); then it closes and `finished`
## fires. Escape does nothing: a level up is always used.

signal finished

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const PixelIcon = preload("res://scripts/ui/widgets/pixel_icon.gd")
const LightRays = preload("res://scripts/ui/widgets/light_rays.gd")

const PANEL_SIZE := Vector2(600, 0)
## The colour of the XP that did it (as the XP of the reward screen).
const XP_COLOUR := Color("#8BE36B")
const PADDING := 24.0
## Seconds before a key counts (a key still held from the game must not pick at once).
const KEYS_AFTER := 0.5
## The stats you can raise, in this order: the stat (PlayerController.STAT_NAMES), how it is
## called here and what it does for you. How much: PlayerController.LEVEL_UP_RAISE.
const OPTIONS := [
	{"stat": "gezondheid", "name": "GEZONDHEID", "text": "Je kunt meer hebben."},
	{"stat": "uithoudingsvermogen", "name": "UITHOUDINGSVERMOGEN", "text": "Je kunt langer rennen."},
	{"stat": "honger", "name": "GROTERE MAAG", "text": "Je houdt het langer uit zonder eten."},
	{"stat": "overprikkeldheid", "name": "INCASSERINGSVERMOGEN", "text": "Je kunt meer prikkels aan."},
]

var font_title: Font
var font_pixel: Font
var font_body: Font
## GameHud.STATS and GameHud.PIXEL_ICONS: colour and icon per stat.
var stat_looks := {}
var pixel_icons := {}
## Called to the HUD when it closes: is the game kept paused (another screen still up)?
var keep_paused := Callable()

var _level := 0
var _choose := Callable()            # Callable(stat name), the player's raise_stat
var _current := Callable()           # Callable(stat name) -> Vector2(value, maximum), to show now -> after
var _raise := {}                     # stat name -> how much its maximum goes up
var _selected := 0
var _since := 0.0
var _was_paused := false
var _level_label: Label
var _xp_label: Label
var _rows: Array[PanelContainer] = []
var _row_values: Array[Label] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func is_showing() -> bool:
	return visible


## Opens for `level`: `choose` gets the stat chosen, `current` gives (value, maximum) of a stat,
## `raise` how much each stat goes up (stat name -> amount).
func open(level: int, choose: Callable, current: Callable, raise: Dictionary, xp_gained := 0) -> void:
	_level = level
	_xp_label.text = "+%d XP" % xp_gained
	_xp_label.visible = xp_gained > 0
	_choose = choose
	_current = current
	_raise = raise
	_level_label.text = "LEVEL %d" % level
	_selected = 0
	_since = 0.0
	_refresh()
	if not visible:
		_was_paused = get_tree().paused
		get_tree().paused = true
		visible = true
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


## The stat chosen now (for the checks).
func selected_stat() -> String:
	return String(OPTIONS[_selected].stat)


## A key press or click while open: true if the screen used it (every key is its own then).
func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		match key:
			KEY_W, KEY_UP:
				_select(posmod(_selected - 1, OPTIONS.size()))
			KEY_S, KEY_DOWN:
				_select(posmod(_selected + 1, OPTIONS.size()))
			KEY_1, KEY_2, KEY_3, KEY_4:
				if _since >= KEYS_AFTER:
					_select(key - KEY_1)
					take()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
				if _since >= KEYS_AFTER:
					take()
		return true
	if event is InputEventMouseMotion:
		var hovered := _row_at((event as InputEventMouseMotion).position)
		if hovered >= 0 and hovered != _selected:
			_select(hovered)
		return true
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var clicked := _row_at((event as InputEventMouseButton).position)
		if clicked >= 0 and _since >= KEYS_AFTER:
			_select(clicked)
			take()
		return true
	return event is InputEventKey or event is InputEventMouseButton


## Takes the stat chosen now: raised, and the screen closes.
func take() -> void:
	if not visible:
		return
	if _choose.is_valid():
		_choose.call(selected_stat())
	visible = false
	get_tree().paused = bool(keep_paused.call()) if keep_paused.is_valid() else _was_paused
	UiSounds.play(self, "doe", -4.0)
	finished.emit()


func _process(delta: float) -> void:
	if visible:
		_since += delta


func _select(index: int) -> void:
	if index == _selected:
		return
	_selected = index
	UiSounds.play(self, "kies", -8.0)
	_refresh()


## The row under a point of the window (the event's position), -1 for none. The HUD's
## picture has the size of the window (the design scaled in it), so a row's rectangle with
## that scale is where it is in the window (the slight bend of the CRT left aside).
func _row_at(point: Vector2) -> int:
	for index in _rows.size():
		var row := _rows[index]
		if (row.get_global_transform() * Rect2(Vector2.ZERO, row.size)).has_point(point):
			return index
	return -1


func _refresh() -> void:
	for index in _rows.size():
		var stat_name := String(OPTIONS[index].stat)
		var colour: Color = stat_looks.get(stat_name, {}).get("colour", UiStyle.ACCENT)
		var chosen := index == _selected
		_rows[index].add_theme_stylebox_override("panel", _row_style(colour, chosen))
		var now: Vector2 = _current.call(stat_name) if _current.is_valid() else Vector2.ZERO
		var raised := float(_raise.get(stat_name, 0.0))
		_row_values[index].text = "%d → %d" % [roundi(now.y), roundi(now.y + raised)]
		_row_values[index].add_theme_color_override("font_color", colour if chosen else UiStyle.MUTED)


# ------------------------------------------------------------------ building

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.INK, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel := PanelContainer.new()
	panel.name = "LevelOmhoog"
	panel.custom_minimum_size = PANEL_SIZE
	var panel_style := UiStyle.box_style(UiStyle.PANEL, UiStyle.ACCENT, 3)
	panel_style.content_margin_left = PADDING
	panel_style.content_margin_right = PADDING
	panel_style.content_margin_top = PADDING * 0.75
	panel_style.content_margin_bottom = PADDING * 0.75
	panel_style.shadow_color = UiStyle.INK
	panel_style.shadow_offset = Vector2.ONE * UiStyle.SHADOW_OFFSET
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	var heading := _make_label("◆ LEVEL OMHOOG", font_pixel, 16, UiStyle.ACCENT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	# the new level big, the rays turning behind it
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(PANEL_SIZE.x - PADDING * 2.0, 110)
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stage)
	var rays := LightRays.new()
	rays.count = 12
	rays.length = 0.8
	rays.colour = Color(UiStyle.ACCENT, 0.12)
	stage.add_child(rays)
	_level_label = _make_label("", font_title, 56, UiStyle.ACCENT)
	_level_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_label.add_theme_color_override("font_shadow_color", UiStyle.INK)
	_level_label.add_theme_constant_override("shadow_offset_x", 4)
	_level_label.add_theme_constant_override("shadow_offset_y", 4)
	stage.add_child(_level_label)
	_xp_label = _make_label("", font_pixel, 16, XP_COLOUR)
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_label.visible = false
	column.add_child(_xp_label)
	var ask := _make_label("Waar word je sterker in?", font_body, 16, UiStyle.TEXT)
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(ask)
	for index in OPTIONS.size():
		column.add_child(_build_row(index))
	var footer := _make_label("[W/S] KIES   [1-4]   [ENTER] NEEM", font_pixel, 13, UiStyle.MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(footer)


func _build_row(index: int) -> PanelContainer:
	var option: Dictionary = OPTIONS[index]
	var stat_name := String(option.stat)
	var look: Dictionary = stat_looks.get(stat_name, {})
	var colour: Color = look.get("colour", UiStyle.ACCENT)
	var row := PanelContainer.new()
	row.name = "Keuze%d" % (index + 1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_stylebox_override("panel", _row_style(colour, false))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	line.add_child(_make_label(str(index + 1), font_pixel, 14, UiStyle.MUTED))
	var icon := PixelIcon.new()
	icon.pixel = 3.0
	icon.colour = colour
	icon.bitmap = pixel_icons.get(String(look.get("icon", "")), [])
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(words)
	words.add_child(_make_label(String(option.name), font_pixel, 14, colour))
	words.add_child(_make_label(String(option.text), font_body, 14, UiStyle.TEXT))
	var values := _make_label("", font_pixel, 14, UiStyle.MUTED)
	values.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(values)
	_rows.append(row)
	_row_values.append(values)
	return row


func _row_style(colour: Color, chosen: bool) -> StyleBoxFlat:
	var style := UiStyle.box_style(Color(colour, 0.14) if chosen else UiStyle.INK, colour if chosen else Color(colour, 0.35), 2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _make_label(text: String, font: Font, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
