extends Control
## How the level-up screen looks (the graphics layer of scripts/ui/level_up_screen.gd, which
## is the behaviour and has this as its child; level_up_screen_rules.gd has the logic,
## level_up_screen_layout.gd the sizes): the world dimmed, a panel in the style of the
## reward screen with "LEVEL OMHOOG", the new level big over turning rays, the XP that did
## it, a row per stat (its icon and colour, its name, what it does, its maximum now ->
## after) and the keys. It shows what it is handed (show_level, show_xp, show_rows) and
## says which row is under a point (row_at); it decides nothing.
##   const LevelUpScreenView = preload("res://scripts/ui/screens/level_up_screen_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const PixelIcon = preload("res://scripts/ui/widgets/pixel_icon.gd")
const LightRays = preload("res://scripts/ui/widgets/light_rays.gd")
const LevelUpScreenLayout = preload("res://scripts/ui/screens/level_up_screen_layout.gd")
const HEADING := "◆ LEVEL OMHOOG"
const ASK := "Waar word je sterker in?"
const KEYS := "[W/S] KIES   [1-4]   [ENTER] NEEM"
## The colour of the XP that did it (as the XP of the reward screen).
const XP_COLOUR := Color("#8BE36B")
const DIM_ALPHA := 0.72
const RAYS_ALPHA := 0.12
## How strong the colour of its stat is behind the chosen row and round the others.
const CHOSEN_FILL_ALPHA := 0.14
const OTHER_BORDER_ALPHA := 0.35
## Seconds the screen takes to come up.
const FADE_IN := 0.25

## The new level, the XP that did it, and per stat its row and its maximum now -> after.
var level_label: Label
var xp_label: Label
var rows: Array[PanelContainer] = []
var row_values: Array[Label] = []
var _row_colours: Array[Color] = []
var _font_title: Font
var _font_pixel: Font
var _font_body: Font


## `options`: per row {"stat", "name", "text"}; `stat_looks`: stat -> {"colour", "icon"};
## `pixel_icons`: icon name -> bitmap.
func _init(font_title: Font = null, font_pixel: Font = null, font_body: Font = null, options: Array = [], stat_looks := {}, pixel_icons := {}) -> void:
	name = "Beeld"
	_font_title = font_title
	_font_pixel = font_pixel
	_font_body = font_body
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.INK, DIM_ALPHA)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", LevelUpScreenLayout.COLUMN_SEPARATION)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel(centre).add_child(column)
	column.add_child(_centred(UiStyle.label(HEADING, _font_pixel, 16, UiStyle.ACCENT)))
	column.add_child(_stage())
	xp_label = _centred(UiStyle.label("", _font_pixel, 16, XP_COLOUR))
	xp_label.visible = false
	column.add_child(xp_label)
	column.add_child(_centred(UiStyle.label(ASK, _font_body, 16, UiStyle.TEXT)))
	for index in options.size():
		var option: Dictionary = options[index]
		column.add_child(_row(index, option, stat_looks.get(String(option.stat), {}), pixel_icons))
	column.add_child(_centred(UiStyle.label(KEYS, _font_pixel, 13, UiStyle.MUTED)))


## Writes the new level big ("LEVEL 3").
func show_level(text: String) -> void:
	level_label.text = text


## Writes the XP that did it, or (`shown` false) hides the line.
func show_xp(text: String, shown: bool) -> void:
	xp_label.text = text
	xp_label.visible = shown


## Lights row `selected` in the colour of its stat and writes per row its maximum now ->
## after (`value_texts`, top to bottom).
func show_rows(selected: int, value_texts: Array) -> void:
	for index in rows.size():
		var colour := _row_colours[index]
		var chosen := index == selected
		rows[index].add_theme_stylebox_override("panel", _row_style(colour, chosen))
		if index < value_texts.size():
			row_values[index].text = String(value_texts[index])
		row_values[index].add_theme_color_override("font_color", colour if chosen else UiStyle.MUTED)


## Brings the screen up from nothing (FADE_IN s).
func fade_in() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_IN)


## The row under a point of the window (an event's position), -1 for none. The HUD's
## picture has the size of the window (the design scaled in it), so a row's rectangle with
## that scale is where it is in the window (the slight bend of the CRT left aside).
func row_at(point: Vector2) -> int:
	var rectangles: Array = []
	for row in rows:
		rectangles.append(LevelUpScreenLayout.on_screen(row.get_global_transform(), row.size))
	return LevelUpScreenLayout.index_at(rectangles, point)


static func _centred(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _panel(centre: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "LevelOmhoog"
	panel.custom_minimum_size = LevelUpScreenLayout.PANEL_SIZE
	var panel_style := UiStyle.box_style(UiStyle.PANEL, UiStyle.ACCENT, LevelUpScreenLayout.PANEL_BORDER)
	panel_style.content_margin_left = LevelUpScreenLayout.PADDING
	panel_style.content_margin_right = LevelUpScreenLayout.PADDING
	panel_style.content_margin_top = LevelUpScreenLayout.panel_margin_top()
	panel_style.content_margin_bottom = LevelUpScreenLayout.panel_margin_top()
	panel_style.shadow_color = UiStyle.INK
	panel_style.shadow_offset = Vector2.ONE * UiStyle.SHADOW_OFFSET
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(panel)
	return panel


## The new level big, the rays turning behind it.
func _stage() -> Control:
	var stage := Control.new()
	stage.custom_minimum_size = LevelUpScreenLayout.stage_size()
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rays := LightRays.new()
	rays.count = 12
	rays.length = 0.8
	rays.colour = Color(UiStyle.ACCENT, RAYS_ALPHA)
	stage.add_child(rays)
	level_label = UiStyle.label("", _font_title, 56, UiStyle.ACCENT)
	level_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.add_theme_color_override("font_shadow_color", UiStyle.INK)
	level_label.add_theme_constant_override("shadow_offset_x", 4)
	level_label.add_theme_constant_override("shadow_offset_y", 4)
	stage.add_child(level_label)
	return stage


func _row(index: int, option: Dictionary, look: Dictionary, pixel_icons: Dictionary) -> PanelContainer:
	var colour: Color = look.get("colour", UiStyle.ACCENT)
	var row := PanelContainer.new()
	row.name = "Keuze%d" % (index + 1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_stylebox_override("panel", _row_style(colour, false))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", LevelUpScreenLayout.ROW_SEPARATION)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	line.add_child(UiStyle.label(str(index + 1), _font_pixel, 14, UiStyle.MUTED))
	var icon := PixelIcon.new()
	icon.pixel = LevelUpScreenLayout.ICON_PIXEL
	icon.colour = colour
	icon.bitmap = pixel_icons.get(String(look.get("icon", "")), [])
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", LevelUpScreenLayout.WORDS_SEPARATION)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(words)
	words.add_child(UiStyle.label(String(option.name), _font_pixel, 14, colour))
	words.add_child(UiStyle.label(String(option.text), _font_body, 14, UiStyle.TEXT))
	var values := UiStyle.label("", _font_pixel, 14, UiStyle.MUTED)
	values.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(values)
	rows.append(row)
	row_values.append(values)
	_row_colours.append(colour)
	return row


static func _row_style(colour: Color, chosen: bool) -> StyleBoxFlat:
	var style := UiStyle.box_style(Color(colour, CHOSEN_FILL_ALPHA) if chosen else UiStyle.INK,
		colour if chosen else Color(colour, OTHER_BORDER_ALPHA), LevelUpScreenLayout.ROW_BORDER)
	style.content_margin_left = LevelUpScreenLayout.ROW_MARGIN_SIDE
	style.content_margin_right = LevelUpScreenLayout.ROW_MARGIN_SIDE
	style.content_margin_top = LevelUpScreenLayout.ROW_MARGIN_TOP
	style.content_margin_bottom = LevelUpScreenLayout.ROW_MARGIN_TOP
	return style
