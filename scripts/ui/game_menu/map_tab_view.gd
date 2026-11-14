extends MarginContainer
## What the KAART tab of the game menu looks like (graphics; docs/CODE_LAGEN.md): the whole
## map of the HUD's minimap in a frame, the fog over the neighbourhoods not visited yet,
## the player as a white triangle, the names of the visited neighbourhoods, the marks of
## the places (a square; a supermarket in the colour and shape of its chain: DERREK a red
## square, ALFRED STEYHN a light blue disc; a cash machine a small yellow block; the chosen
## one larger and ringed white), a ring round the places a mission marked, the marker you
## set (a pink diamond) and the places of the followed quest (amber diamonds); beside it
## the chosen place, where you are and the legend. It shows what map_tab.gd hands it and
## says where the map was clicked; where things stand comes from map_tab_layout.gd.
##   const MapTabView = preload("res://scripts/ui/game_menu/map_tab_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const PlayerArrow = preload("res://scripts/ui/widgets/player_arrow.gd")
const QuestMarks = preload("res://scripts/ui/widgets/quest_marks.gd")
const MapLook = preload("res://scripts/ui/hud/map_look.gd")
const MenuParts = preload("res://scripts/ui/game_menu/menu_parts_view.gd")
const MenuBox = preload("res://scripts/ui/game_menu/menu_box.gd")
const Layout = preload("res://scripts/ui/game_menu/map_tab_layout.gd")
const KEYS := "[←↑↓→] PLEK KIEZEN   [ENTER] MARKER   [KLIK] KIEZEN   [RECHTSKLIK] MARKER   [Q/E] TAB   [TAB] SLUITEN"
## Places in a visited neighbourhood and the others, and the fog over the neighbourhoods
## not visited yet.
const PLACE_COLOUR := Color("#47D6C2")
const UNKNOWN_PLACE_COLOUR := Color("#5A6090")
const FOG := Color(20.0 / 255.0, 24.0 / 255.0, 58.0 / 255.0, 0.86)
## The supermarket chains: the colour of the chain and whether its mark is round (the
## shape of its emblem).
const SUPERMARKETS := {
	"derrek": {"colour": Color("#DE1828"), "round": false},
	"alfred_steyhn": {"colour": Color("#2CA8E4"), "round": true},
}
## The cash machines: the yellow of PINPUNT.
const CASH_MACHINE_COLOUR := Color("#F2B705")
## How see-through the names of the neighbourhoods are.
const AREA_NAME_ALPHA := 0.55
## The mouse buttons the map takes (choose; set the marker).
const MAP_BUTTONS := [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]

## The map was clicked at `point` (of its frame) with this mouse button (left or right),
## with Shift held or not.
signal map_pressed(point: Vector2, button: int, with_shift: bool)

var _fonts := {}
var _clip: Control
var _picture: TextureRect
var _fog: TextureRect
var _overlay: Control
var _arrow: PlayerArrow
var _waiting: Label
var _coordinates: Label
var _coordinates_box: MenuBox
var _north: MenuBox
var _legend_grid: GridContainer
var _place_box: MenuBox
var _place_kind: Label
var _place_name: Label
var _place_wijk: Label
var _place_distance: Label
var _place_state: Label
var _place_marker: Label
var _here_wijk: Label
var _here_street: Label

var _origin := Vector2.ZERO        # the world x, z of the top left of the picture
var _metres_per_pixel := 4.0
var _scale := 1.0
var _offset := Vector2.ZERO
var _player_at := Vector2.ZERO
var _player_rotation := 0.0
var _area_labels: Array = []       # {"text", "at"}
var _marks: Array = []             # {"at", "look", "chain", "chosen"}
var _rings: Array = []             # world x, z
var _targets: Array = []           # world x, z
var _has_waypoint := false
var _waypoint := Vector2.ZERO


func _init() -> void:
	name = "Beeld"
	_fonts = MenuParts.fonts()
	var content := MenuParts.fill_page(self, KEYS, _fonts.pixel)
	content.add_child(_map_frame())
	content.add_child(_side_column())


## The legend: a place, an unknown one, the supermarket chains (`chains`: [chain, name]
## each), a cash machine (`cash_machine_name`), your marker, the fog and you.
func show_legend(chains: Array, cash_machine_name: String) -> void:
	for entry in _legend_grid.get_children():
		entry.queue_free()
	_legend_grid.add_child(_legend_entry(_legend_square(PLACE_COLOUR, PLACE_COLOUR), "Plek"))
	_legend_grid.add_child(_legend_entry(_legend_square(UNKNOWN_PLACE_COLOUR, UNKNOWN_PLACE_COLOUR), "Nog onbekend"))
	for chain: Array in chains:
		_legend_grid.add_child(_legend_entry(_legend_chain(chain[0]), chain[1]))
	_legend_grid.add_child(_legend_entry(_legend_square(CASH_MACHINE_COLOUR, UiStyle.INK), cash_machine_name))
	_legend_grid.add_child(_legend_entry(_legend_square(MapLook.WAYPOINT_COLOUR, Color.WHITE), "Jouw marker"))
	_legend_grid.add_child(_legend_entry(_legend_square(Color(FOG, 1.0), UiStyle.BORDER), "Onontdekte wijk"))
	var arrow_holder := MenuParts.gap(Vector2(12, 12))
	var arrow := PlayerArrow.new()
	arrow.scale = Vector2(0.5, 0.5)
	arrow.position = Vector2(6, 6)
	arrow_holder.add_child(arrow)
	_legend_grid.add_child(_legend_entry(arrow_holder, "Jij"))


## The map picture (null: it is still being drawn), whose top left is `origin` (world x, z)
## and whose pixels are `metres_per_pixel` each.
func show_map(texture: Texture2D, origin: Vector2, metres_per_pixel: float) -> void:
	_picture.texture = texture
	_origin = origin
	_metres_per_pixel = metres_per_pixel
	_place_parts()


## The fog over the map: the `stretches` of the town painted in order (MapTabRules.fog_areas:
## "from", "to", "fogged") and over them what the story has not opened yet (`shroud`, a
## picture the size of the map; null none). No fog without a map picture.
func show_fog(stretches: Array, shroud: Image) -> void:
	var map_texture := _picture.texture
	if map_texture == null:
		_fog.texture = null
		return
	var pixels := Vector2i(map_texture.get_size())
	var image := Image.create(pixels.x, pixels.y, false, Image.FORMAT_RGBA8)
	image.fill(MenuParts.NOTHING)
	for stretch: Dictionary in stretches:
		var rect := Layout.pixel_rect(stretch.from, stretch.to, _origin, _metres_per_pixel, pixels)
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		image.fill_rect(rect, FOG if stretch.fogged else MenuParts.NOTHING)
	if shroud and Vector2i(shroud.get_size()) == pixels:
		image.blend_rect(shroud, Rect2i(Vector2i.ZERO, pixels), Vector2i.ZERO)
	_fog.texture = ImageTexture.create_from_image(image)


## No fog at all (there is no town to take the neighbourhoods from).
func show_no_fog() -> void:
	_fog.texture = null


## The player on the map: where it is (world x, z) and how far its arrow is turned
## (`turns`: false keeps the way it pointed).
func show_player(at: Vector2, turns: bool, rotation_now: float) -> void:
	_player_at = at
	if turns:
		_player_rotation = rotation_now
	_place_parts()


## The coordinates bottom left ("X 0100 · Y 0100").
func show_coordinates(text: String) -> void:
	_coordinates.text = text
	_place_parts()


## Where you are, beside the map: the neighbourhood and the street (`in_street`: false
## when `street` only says there is none).
func show_here(wijk: String, street: String, in_street: bool) -> void:
	_here_wijk.text = wijk
	_here_street.text = street
	_here_street.add_theme_color_override("font_color", UiStyle.TEXT if in_street else UiStyle.MUTED)


## The names of the neighbourhoods on the map (MapTabRules.area_labels: "text", "at").
func show_area_labels(labels: Array) -> void:
	_area_labels = labels
	_overlay.queue_redraw()


## The marks of the places, drawn in this order (MapTabRules.marks: "at", "look", "chain",
## "chosen").
func show_marks(marks: Array) -> void:
	_marks = marks
	_overlay.queue_redraw()


## What lies over the marks: a ring round each of `rings` (the places a mission marked),
## the marker you set (`has_waypoint`, at `waypoint`) and a diamond on each of `targets`
## (where the followed quest sends you); all world x, z.
func show_pointers(rings: Array, has_waypoint: bool, waypoint: Vector2, targets: Array) -> void:
	_rings = rings
	_has_waypoint = has_waypoint
	_waypoint = waypoint
	_targets = targets
	_overlay.queue_redraw()


## The chosen place beside the map (MapTabRules.place_panel).
func show_place(panel: Dictionary) -> void:
	var colour := _look_colour(panel.look, panel.chain)
	_place_box.visible = true
	_place_box.style = _place_style(colour)
	_place_kind.text = panel.kind_text
	_place_kind.add_theme_color_override("font_color", colour)
	_place_name.text = panel.name
	_place_wijk.text = panel.wijk_text
	_place_distance.text = panel.distance_text
	_place_state.text = panel.state_text
	_place_marker.text = panel.marker_text
	_place_marker.add_theme_color_override("font_color", MapLook.WAYPOINT_COLOUR if panel.marked else UiStyle.TEXT)


## No place is chosen: no panel.
func show_no_place() -> void:
	_place_box.visible = false


## The point of the map (in its frame) of a spot of the town (world x, z).
func world_to_map(world_position: Vector2) -> Vector2:
	return Layout.world_to_map(world_position, _origin, _metres_per_pixel, _scale, _offset)


## The spot of the town (world x, z) under a point of the map.
func map_to_world(map_point: Vector2) -> Vector2:
	return Layout.map_to_world(map_point, _origin, _metres_per_pixel, _scale, _offset)


## The map picture and the fog over it (null while there is none).
func map_texture() -> Texture2D:
	return _picture.texture


func fog_texture() -> Texture2D:
	return _fog.texture


## What the panel of the chosen place says now, for the tests: {"kind", "name", "wijk",
## "distance", "state", "marker"}; {} while there is no panel.
func place_texts() -> Dictionary:
	if not _place_box.visible:
		return {}
	return {"kind": _place_kind.text, "name": _place_name.text, "wijk": _place_wijk.text,
		"distance": _place_distance.text, "state": _place_state.text, "marker": _place_marker.text}


## What stands beside and on the map now, for the tests: {"wijk", "street", "coordinates",
## "waiting": the map is still being drawn}.
func here_texts() -> Dictionary:
	return {"wijk": _here_wijk.text, "street": _here_street.text, "coordinates": _coordinates.text,
		"waiting": _waiting.visible}


## The texts of the legend, in order.
func legend_texts() -> Array:
	var texts: Array = []
	for entry in _legend_grid.get_children():
		if not entry.is_queued_for_deletion():
			texts.append((entry.get_child(1) as Label).text)
	return texts


## What is drawn over the map now: {"labels", "marks", "rings", "targets", "has_waypoint",
## "waypoint"} as they were handed over.
func drawn() -> Dictionary:
	return {"labels": _area_labels, "marks": _marks, "rings": _rings, "targets": _targets,
		"has_waypoint": _has_waypoint, "waypoint": _waypoint}


## Where the arrow of the player stands on the map and how far it is turned.
func arrow_place() -> Vector3:
	return Vector3(_arrow.position.x, _arrow.position.y, _arrow.rotation)


## Fits the map picture into its frame (as large as fits, centred) and places the marks,
## the arrow, the coordinates and the north sign.
func _place_parts() -> void:
	var area := _clip.size
	_overlay.position = Vector2.ZERO
	_overlay.size = area
	_waiting.position = Vector2.ZERO
	_waiting.size = area
	_north.position = Layout.north_position(area)
	_north.size = Vector2(Layout.NORTH_SIZE, Layout.NORTH_SIZE)
	_coordinates_box.reset_size()
	_coordinates_box.position = Layout.coordinates_position(area, _coordinates_box.size.y)
	var texture := _picture.texture
	_waiting.visible = texture == null
	_arrow.visible = texture != null
	if texture == null:
		_overlay.queue_redraw()
		return
	var fitted := Layout.fit(area, texture.get_size())
	_scale = fitted.scale
	_offset = fitted.offset
	for picture: TextureRect in [_picture, _fog]:
		picture.position = _offset
		picture.size = texture.get_size() * _scale
	_arrow.position = world_to_map(_player_at)
	_arrow.rotation = _player_rotation
	_overlay.queue_redraw()


## The names of the visited neighbourhoods, the marks of the places (the chosen one larger,
## ringed white, on top) and what lies over them.
func _draw_overlay() -> void:
	if _picture.texture == null:
		return
	var font: Font = _fonts.pixel
	for label: Dictionary in _area_labels:
		var text_width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, Layout.AREA_FONT_SIZE).x
		var at := Layout.area_label_position(world_to_map(label.at), text_width)
		_overlay.draw_string(font, at + Vector2(1, 1), label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, Layout.AREA_FONT_SIZE, UiStyle.INK)
		_overlay.draw_string(font, at, label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, Layout.AREA_FONT_SIZE, Color(UiStyle.TEXT, AREA_NAME_ALPHA))
	for mark: Dictionary in _marks:
		_draw_mark(world_to_map(mark.at).round(), mark)
	# the places a mission marked for good (Story "markeringen"): a ring round them
	for at_world: Vector2 in _rings:
		var ring_at := world_to_map(at_world).round()
		_overlay.draw_arc(ring_at, Layout.STORY_RING_RADIUS, 0.0, TAU, 20, UiStyle.INK, 4.0)
		_overlay.draw_arc(ring_at, Layout.STORY_RING_RADIUS, 0.0, TAU, 20, UiStyle.ACCENT, 2.0)
	# the marker set on the map, a pink diamond
	if _has_waypoint:
		QuestMarks.draw_mark(_overlay, world_to_map(_waypoint).round(), Layout.WAYPOINT_HALF, 1.0, MapLook.WAYPOINT_COLOUR)
	# where the followed quest sends you, over everything
	for target: Vector2 in _targets:
		QuestMarks.draw_mark(_overlay, world_to_map(target).round(), Layout.TARGET_HALF)


func _draw_mark(at: Vector2, mark: Dictionary) -> void:
	if SUPERMARKETS.has(mark.chain):
		_draw_supermarket(at, mark.chain, mark.chosen)
	elif mark.look == "pinautomaat":
		_draw_cash_machine(at, mark.chosen)
	elif mark.chosen:
		_draw_square(at, Layout.CHOSEN_PLACE_RING_HALF, Color.WHITE)
		_draw_square(at, Layout.CHOSEN_PLACE_RIM_HALF, UiStyle.INK)
		_draw_square(at, Layout.CHOSEN_PLACE_HALF, _look_colour(mark.look, mark.chain))
	else:
		_draw_square(at, Layout.PLACE_RIM_HALF, UiStyle.INK)
		_draw_square(at, Layout.PLACE_HALF, _look_colour(mark.look, mark.chain))


## A square of `half` pixels round `at`.
func _draw_square(at: Vector2, half: float, colour: Color) -> void:
	_overlay.draw_rect(Rect2(at - Vector2.ONE * half, Vector2.ONE * half * 2.0), colour)


## The mark of a cash machine at `at`: a small upright yellow block (the machine) with a
## dark screen; `chosen`: larger, ringed white.
func _draw_cash_machine(at: Vector2, chosen: bool) -> void:
	var half := Layout.CASH_MACHINE_HALF * (Layout.CHOSEN_CASH_MACHINE_SCALE if chosen else 1.0)
	if chosen:
		_overlay.draw_rect(Rect2(at - half - Vector2.ONE * 4.0, (half + Vector2.ONE * 4.0) * 2.0), Color.WHITE)
	_overlay.draw_rect(Rect2(at - half - Vector2.ONE * 2.0, (half + Vector2.ONE * 2.0) * 2.0), UiStyle.INK)
	_overlay.draw_rect(Rect2(at - half, half * 2.0), CASH_MACHINE_COLOUR)
	var screen := Vector2(half.x * 0.6, half.y * 0.35)
	_overlay.draw_rect(Rect2(at - Vector2(screen.x, half.y * 0.7), screen * 2.0), UiStyle.INK)


## The mark of a supermarket at `at`: a square (DERREK) or a disc (ALFRED STEYHN) in the
## chain's colour with a white rim and a white dot; `chosen`: larger, ringed white.
func _draw_supermarket(at: Vector2, chain: String, chosen: bool) -> void:
	var colour: Color = SUPERMARKETS[chain].colour
	var half := Layout.CHOSEN_SUPERMARKET_HALF if chosen else Layout.SUPERMARKET_HALF
	if SUPERMARKETS[chain].round:
		if chosen:
			_overlay.draw_circle(at, half + 4.0, Color.WHITE)
		_overlay.draw_circle(at, half + 2.0, UiStyle.INK)
		_overlay.draw_circle(at, half + 1.0, Color.WHITE)
		_overlay.draw_circle(at, half, colour)
	else:
		if chosen:
			_draw_square(at, half + 4.0, Color.WHITE)
		_draw_square(at, half + 2.0, UiStyle.INK)
		_draw_square(at, half + 1.0, Color.WHITE)
		_draw_square(at, half, colour)
	_overlay.draw_rect(Rect2(at - Vector2(1.5, 1.5), Vector2(3, 3)), Color.WHITE)


## The colour of a place by its look ("plek", "onbekend", "supermarkt" with its chain,
## "pinautomaat").
static func _look_colour(look: String, chain: String) -> Color:
	if SUPERMARKETS.has(chain):
		return SUPERMARKETS[chain].colour
	match look:
		"pinautomaat":
			return CASH_MACHINE_COLOUR
		"onbekend":
			return UNKNOWN_PLACE_COLOUR
	return PLACE_COLOUR


static func _place_style(colour: Color) -> StyleBoxFlat:
	return MenuParts.style(UiStyle.PANEL, colour, 3, 18, 18)


func _on_overlay_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or not MAP_BUTTONS.has(click.button_index):
		return
	_overlay.accept_event()
	map_pressed.emit(click.position, click.button_index, click.shift_pressed)


func _layer_picture() -> TextureRect:
	var picture := TextureRect.new()
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


func _map_frame() -> Control:
	var frame := MenuParts.box(MenuParts.style(UiStyle.INK, UiStyle.BORDER, 3), Layout.FRAME_SHADOW)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = Layout.MAP_STRETCH
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_clip)
	_picture = _layer_picture()
	_clip.add_child(_picture)
	_fog = _layer_picture()
	_clip.add_child(_fog)
	_overlay = Control.new()
	_overlay.name = "Plekken"
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.draw.connect(_draw_overlay)
	_overlay.gui_input.connect(_on_overlay_input)
	_clip.add_child(_overlay)
	_arrow = PlayerArrow.new()
	_arrow.scale = Vector2(0.8, 0.8)
	_clip.add_child(_arrow)
	_waiting = UiStyle.label("DE KAART WORDT NOG GETEKEND…", _fonts.pixel, 12, UiStyle.MUTED)
	_waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waiting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clip.add_child(_waiting)
	_coordinates_box = MenuParts.box(MenuParts.style(UiStyle.TRANSLUCENT_INK, UiStyle.TRANSLUCENT_INK, 0, 8, 4))
	_coordinates = UiStyle.label("", _fonts.pixel, 11)
	_coordinates_box.add_child(_coordinates)
	_clip.add_child(_coordinates_box)
	_north = MenuParts.box(MenuParts.style(UiStyle.TRANSLUCENT_INK, UiStyle.BORDER, 2))
	_north.custom_minimum_size = Vector2(Layout.NORTH_SIZE, Layout.NORTH_SIZE)
	var north := UiStyle.label("N", _fonts.pixel_bold, 14)
	north.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	north.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_north.add_child(north)
	_clip.add_child(_north)
	_clip.resized.connect(_place_parts)
	return frame


func _side_column() -> Control:
	var column := MenuParts.vbox(14)
	column.custom_minimum_size = Vector2(Layout.SIDE_WIDTH, 0)
	_place_box = MenuParts.box(_place_style(PLACE_COLOUR), UiStyle.SHADOW_OFFSET)
	column.add_child(_place_box)
	var place_column := MenuParts.vbox(10)
	_place_box.add_child(place_column)
	_place_kind = UiStyle.label("", UiStyle.spaced(_fonts.pixel, 2), 11, PLACE_COLOUR)
	place_column.add_child(_place_kind)
	_place_name = UiStyle.label("", _fonts.title, 22)
	_place_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place_column.add_child(_place_name)
	_place_wijk = UiStyle.label("", _fonts.body, 13, MenuParts.SOFT_TEXT)
	_place_wijk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place_column.add_child(_place_wijk)
	var chips := MenuParts.hbox(8)
	place_column.add_child(chips)
	_place_distance = _chip(chips)
	_place_state = _chip(chips)
	_place_marker = UiStyle.label("", _fonts.pixel, 11, UiStyle.TEXT)
	place_column.add_child(_place_marker)
	var here := MenuParts.box(MenuParts.style(UiStyle.PANEL, UiStyle.BORDER, 2, 16, 14))
	column.add_child(here)
	var here_column := MenuParts.vbox(6)
	here.add_child(here_column)
	here_column.add_child(UiStyle.label("JE BENT HIER", UiStyle.spaced(_fonts.pixel, 2), 11, UiStyle.MUTED))
	_here_wijk = UiStyle.label("", _fonts.pixel, 12, UiStyle.SIDE_ACCENT)
	here_column.add_child(_here_wijk)
	_here_street = UiStyle.label("", _fonts.body, 13)
	_here_street.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	here_column.add_child(_here_street)
	var legend := MenuParts.box(MenuParts.style(UiStyle.PANEL, UiStyle.BORDER, 2, 16, 14))
	column.add_child(legend)
	var legend_column := MenuParts.vbox(10)
	legend.add_child(legend_column)
	legend_column.add_child(UiStyle.label("LEGENDA", UiStyle.spaced(_fonts.pixel, 2), 11, UiStyle.MUTED))
	_legend_grid = GridContainer.new()
	_legend_grid.columns = 2
	_legend_grid.add_theme_constant_override("h_separation", 12)
	_legend_grid.add_theme_constant_override("v_separation", 8)
	_legend_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend_column.add_child(_legend_grid)
	column.add_child(MenuParts.spacer())
	return column


## A small outlined chip in `row`; returns the label in it.
func _chip(row: HBoxContainer) -> Label:
	var chip := MenuParts.box(MenuParts.style(MenuParts.NOTHING, UiStyle.BORDER, 1, 6, 3))
	var chip_label := UiStyle.label("", _fonts.pixel, 11, UiStyle.MUTED)
	chip.add_child(chip_label)
	row.add_child(chip)
	return chip_label


func _legend_square(colour: Color, border: Color) -> Panel:
	var square := Panel.new()
	square.custom_minimum_size = Vector2(Layout.LEGEND_SQUARE, Layout.LEGEND_SQUARE)
	square.mouse_filter = Control.MOUSE_FILTER_IGNORE
	square.add_theme_stylebox_override("panel", UiStyle.box_style(colour, border, 1))
	return square


## The mark of a supermarket chain in the legend: a square, or a disc for a round one.
func _legend_chain(chain: String) -> Control:
	var look: Dictionary = SUPERMARKETS[chain]
	var marker := _legend_square(look.colour, Color.WHITE)
	if look.round:
		var round_style := UiStyle.box_style(look.colour, Color.WHITE, 1).duplicate() as StyleBoxFlat
		round_style.set_corner_radius_all(5)
		marker.add_theme_stylebox_override("panel", round_style)
	return marker


func _legend_entry(marker: Control, text: String) -> Control:
	var row := MenuParts.hbox(8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(marker)
	row.add_child(UiStyle.label(text, _fonts.body, 12))
	return row
