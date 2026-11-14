extends Node3D
## What Den Haag Centraal adds to its scene to look at and listen to (graphics;
## docs/CODE_LAGEN.md): the texts of the departure boards and the platform displays, the
## hands of the station clock, the boards over the stalls, the overhead lines with their
## masts, the can of the story in a bin, and the sounds of the trains at the platforms. It
## builds them where station.gd says (at the markers of scenes/binnen/centraal.tscn, or in
## the station itself) and shows what it is handed (show_boards, show_display, show_clock);
## it decides nothing. Where things stand: station_boards_layout.gd, station_wires_layout.gd.
##   const StationView = preload("res://scripts/world/station/station_view.gd")

const BoardsLayout = preload("res://scripts/world/station/station_boards_layout.gd")
const WiresLayout = preload("res://scripts/world/station/station_wires_layout.gd")
const OverheadLines = preload("res://scripts/world/town/overhead_lines.gd")
const MachineModels = preload("res://scripts/world/things/machine_models.gd")
const QuestOutline = preload("res://scripts/effects/quest_outline.gd")
const BOARD_WHITE := Color("#F2F4F8")
const BOARD_YELLOW := Color("#FFD23A")
const BOARD_RED := Color("#FF5A4A")
const BOARD_BLUE := Color("#0A2A6A")
## The colour of the remark of a row by what it is about (the timetable's "remark_kind").
const REMARK_COLOURS := {"rijdt_niet": BOARD_RED, "vertraging": BOARD_YELLOW}
const MAST_COLOUR := Color(0.6, 0.62, 0.64)
## The lines rising over the player: a fine or a reader saying no, and a reader saying yes.
const FINE_COLOUR := Color("#FF5A4A")
const REFUSED_COLOUR := Color("#FF5A4A")
const ACCEPTED_COLOUR := Color("#3CE06A")
const CLOCK_HAND_COLOUR := Color("#141414")
const CLOCK_SECONDS_COLOUR := Color("#D8231C")
const SHOP_PLATE_COLOUR := "#22304A"
const SHOP_TEXT_COLOUR := "#FFFFFF"
const HEADINGS := ["VERTREK", "NAAR", "SPOOR"]
## The sounds at a train: the whistle, the doors, the horn (name, dB).
const WHISTLE_SOUND := "conducteur_fluit"
const DOORS_SHUT_SOUND := "trein_deuren_dicht"
const HORN_SOUND := "trein_hoorn"
const FULL_PIXEL_SIZE_META := "full_pixel_size"

## Per departure board: its rows, each [time, destination, track, remark] (Label3D).
var boards: Array = []
## Per track: {"number", "time", "destination"} (Label3D) of the display at its head.
var displays := {}
## The pivots of the hands of the clock: "hour", "minute", "second" -> Node3D.
var hands := {}


func _init() -> void:
	name = "Beeld"


# ------------------------------------------------------------------ building

## The texts of a departure board on its `marker`: the headings and BOARD_ROWS empty rows.
func add_departure_board(marker: Node3D) -> void:
	var board := Node3D.new()
	board.name = "Tekst"
	marker.add_child(board)
	for column in HEADINGS.size():
		var header := make_label(HEADINGS[column], BoardsLayout.BOARD_HEADER_FONT_SIZE, BoardsLayout.BOARD_PIXEL_SIZE,
				BOARD_BLUE, BoardsLayout.board_column_is_left(column))
		header.position = BoardsLayout.board_header_position(column)
		board.add_child(header)
	var rows := []
	for row_index in BoardsLayout.BOARD_ROWS:
		var row := []
		for column in BoardsLayout.BOARD_COLUMNS.size():
			var colour := BOARD_YELLOW if column == BoardsLayout.REMARK else BOARD_WHITE
			var label := make_label("", BoardsLayout.BOARD_FONT_SIZE, BoardsLayout.BOARD_PIXEL_SIZE, colour,
					BoardsLayout.board_column_is_left(column))
			label.position = BoardsLayout.board_cell_position(row_index, column)
			board.add_child(label)
			row.append(label)
		rows.append(row)
	boards.append(rows)


## The texts of the display at the head of `track` on its `marker`: the number, and two
## empty lines.
func add_display(track: int, marker: Node3D) -> void:
	var number := make_label("", BoardsLayout.DISPLAY_NUMBER_FONT_SIZE, BoardsLayout.DISPLAY_NUMBER_PIXEL_SIZE, BOARD_BLUE)
	number.position = BoardsLayout.display_number_position()
	marker.add_child(number)
	fit_text(number, str(track), BoardsLayout.DISPLAY_NUMBER_WIDTH)
	var time := make_label("", BoardsLayout.DISPLAY_FONT_SIZE, BoardsLayout.BOARD_PIXEL_SIZE, BOARD_WHITE, true)
	time.position = BoardsLayout.display_time_position()
	marker.add_child(time)
	var destination := make_label("", BoardsLayout.DISPLAY_FONT_SIZE, BoardsLayout.BOARD_PIXEL_SIZE, BOARD_WHITE, true)
	destination.position = BoardsLayout.display_destination_position()
	marker.add_child(destination)
	displays[track] = {"number": number, "time": time, "destination": destination}


## The hands of the station clock on its `marker` (the red seconds hand with its disc, the
## Swiss railway clock).
func add_clock(marker: Node3D) -> void:
	var face := Node3D.new()
	face.name = "Wijzers"
	face.position = Vector3(0.0, 0.0, BoardsLayout.CLOCK_FACE_LIFT)
	marker.add_child(face)
	for hand_index in BoardsLayout.CLOCK_HANDS.size():
		var hand_name: String = BoardsLayout.CLOCK_HANDS[hand_index][0]
		var is_seconds := hand_name == "second"
		var pivot := Node3D.new()
		pivot.name = hand_name
		face.add_child(pivot)
		var piece := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = BoardsLayout.clock_hand_size(hand_index)
		piece.mesh = bar
		piece.position = BoardsLayout.clock_hand_position(hand_index)
		var material := StandardMaterial3D.new()
		material.albedo_color = CLOCK_SECONDS_COLOUR if is_seconds else CLOCK_HAND_COLOUR
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		piece.material_override = material
		pivot.add_child(piece)
		if is_seconds:
			var disc := MeshInstance3D.new()
			var round_end := CylinderMesh.new()
			round_end.top_radius = BoardsLayout.CLOCK_DISC_RADIUS
			round_end.bottom_radius = BoardsLayout.CLOCK_DISC_RADIUS
			round_end.height = BoardsLayout.CLOCK_HAND_THICKNESS
			disc.mesh = round_end
			disc.rotation.x = PI * 0.5
			disc.position = BoardsLayout.clock_disc_position(hand_index)
			disc.material_override = material
			pivot.add_child(disc)
		hands[hand_name] = pivot


## The overhead lines in `host` (the station): the wires and arms as one mesh
## ("Bovenleiding", hanging out of reach: no collider) and the masts at the walls
## ("Bovenleidingmast_<n>", each with a collider just as slim).
func add_overhead_lines(host: Node3D) -> void:
	var helper := OverheadLines.new()
	var wires := MeshInstance3D.new()
	wires.name = "Bovenleiding"
	wires.mesh = helper._wire_mesh(WiresLayout.pieces())
	wires.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	helper.free()
	host.add_child(wires)
	var feet := WiresLayout.wall_mast_feet()
	for mast_index in feet.size():
		host.add_child(_wall_mast(feet[mast_index], mast_index + 1))


## A slim galvanised mast at the wall (its foot at `foot`, on the platform).
func _wall_mast(foot: Vector3, number: int) -> StaticBody3D:
	var mast := StaticBody3D.new()
	mast.name = "Bovenleidingmast_%d" % number
	mast.collision_layer = 1
	mast.collision_mask = 0
	mast.position = WiresLayout.mast_middle(foot)
	var pole := MeshInstance3D.new()
	var pole_mesh := BoxMesh.new()
	pole_mesh.size = WiresLayout.mast_size()
	var material := StandardMaterial3D.new()
	material.albedo_color = MAST_COLOUR
	material.metallic = 0.5
	material.roughness = 0.5
	pole_mesh.material = material
	pole.mesh = pole_mesh
	mast.add_child(pole)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = WiresLayout.mast_size()
	shape.shape = box
	mast.add_child(shape)
	return mast


## The board over a stall (winkels.json "logo"): a plate in the shop's colour ("kleur"), on
## it the logo (the pixel icon "icoon" of the game's menus, GameMenu.ITEM_ICONS, in the text
## colour) and the shop's name ("tekst" colour); its front to the node's +z.
func make_shop_board(shop_name: String, logo: Dictionary) -> Node3D:
	var board := Node3D.new()
	board.name = "Uithangbord"
	var plate := MeshInstance3D.new()
	plate.name = "Bord"
	var box := BoxMesh.new()
	box.size = BoardsLayout.SHOP_BOARD_SIZE
	plate.mesh = box
	var plate_material := StandardMaterial3D.new()
	plate_material.albedo_color = Color(str(logo.get("kleur", SHOP_PLATE_COLOUR)))
	plate_material.roughness = 0.7
	plate.material_override = plate_material
	plate.position = BoardsLayout.shop_plate_position()
	board.add_child(plate)
	var text_colour := Color(str(logo.get("tekst", SHOP_TEXT_COLOUR)))
	var icon_name := str(logo.get("icoon", ""))
	var has_icon := GameMenu.ITEM_ICONS.has(icon_name)
	if has_icon:
		var sprite := Sprite3D.new()
		sprite.name = "Logo"
		sprite.texture = icon_texture(GameMenu.ITEM_ICONS[icon_name].rows, text_colour)
		sprite.pixel_size = BoardsLayout.SHOP_LOGO_HEIGHT / float(sprite.texture.get_height())
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.shaded = false
		sprite.position = BoardsLayout.shop_logo_position()
		board.add_child(sprite)
	var name_label := make_label("", BoardsLayout.SHOP_NAME_FONT_SIZE, BoardsLayout.SHOP_NAME_PIXEL_SIZE, text_colour)
	name_label.name = "Naam"
	fit_text(name_label, shop_name.to_upper(), BoardsLayout.shop_name_width(has_icon))
	name_label.position = BoardsLayout.shop_name_position(has_icon)
	board.add_child(name_label)
	return board


## A pixel icon ("#" coloured, anything else clear) as a small texture.
static func icon_texture(rows: Array, colour: Color) -> ImageTexture:
	var width := 0
	for row: String in rows:
		width = maxi(width, row.length())
	var image := Image.create(width + 2, rows.size() + 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for row_index in rows.size():
		var row: String = rows[row_index]
		for column in row.length():
			if row[column] == "#":
				image.set_pixel(column + 1, row_index + 1, colour)
	return ImageTexture.create_from_image(image)


## The can of the story sticking out of the bin at `spot`, glowing as the cans in the
## town's bins.
func add_mission_can(spot: Node3D) -> void:
	var can := MeshInstance3D.new()
	can.name = "Blikje"
	can.mesh = MachineModels.can_mesh()
	spot.add_child(can)
	can.position = BoardsLayout.CAN_POSITION
	can.rotation = BoardsLayout.CAN_ROTATION
	QuestOutline.add(can, 0.02)


## A text on a board: the pixel font, unshaded, one-sided; `left`: starting at its position.
func make_label(text: String, font_size: int, pixel_size: float, colour: Color, left := false) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = UiStyle.font(UiStyle.FONT_PIXEL_BOLD)
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = colour
	label.outline_size = 0
	label.shaded = false
	label.double_sided = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if left:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.set_meta(FULL_PIXEL_SIZE_META, pixel_size)
	return label


# ------------------------------------------------------------------ showing

## Puts `text` on `label`, made smaller (its pixel_size) when it would be wider than
## `max_width` metres, so it stays on its board.
func fit_text(label: Label3D, text: String, max_width: float) -> void:
	if label.text == text:
		return
	label.text = text
	var full_size := float(label.get_meta(FULL_PIXEL_SIZE_META, label.pixel_size))
	label.pixel_size = full_size
	if text.is_empty() or label.font == null:
		return
	var text_width := label.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x * full_size
	label.pixel_size = BoardsLayout.fitted_pixel_size(full_size, text_width, max_width)


## The rows of every departure board: `rows` from the top ({"time", "destination", "track",
## "remark", "remark_kind"} each); the rows of a board past them are empty.
func show_boards(rows: Array) -> void:
	for board_rows: Array in boards:
		for row_index in board_rows.size():
			var labels: Array = board_rows[row_index]
			if row_index >= rows.size():
				for label: Label3D in labels:
					label.text = ""
				continue
			var row: Dictionary = rows[row_index]
			fit_text(labels[BoardsLayout.TIME], String(row.time), BoardsLayout.board_column_width(BoardsLayout.TIME))
			fit_text(labels[BoardsLayout.DESTINATION], String(row.destination), BoardsLayout.board_column_width(BoardsLayout.DESTINATION))
			fit_text(labels[BoardsLayout.TRACK], String(row.track), BoardsLayout.board_column_width(BoardsLayout.TRACK))
			var remark := labels[BoardsLayout.REMARK] as Label3D
			fit_text(remark, String(row.remark), BoardsLayout.board_column_width(BoardsLayout.REMARK))
			if REMARK_COLOURS.has(row.remark_kind):
				remark.modulate = REMARK_COLOURS[row.remark_kind]


## The two lines of the display of `track` ({"time", "destination"}); {}: nothing runs there.
func show_display(track: int, lines: Dictionary) -> void:
	if not displays.has(track):
		return
	var labels: Dictionary = displays[track]
	if lines.is_empty():
		(labels.time as Label3D).text = ""
		(labels.destination as Label3D).text = ""
		return
	fit_text(labels.time, String(lines.time), BoardsLayout.display_text_width())
	fit_text(labels.destination, String(lines.destination), BoardsLayout.display_text_width())


## The hands of the clock: how far round each is (radians: "second", "minute", "hour").
func show_clock(turns: Dictionary) -> void:
	for hand_name: String in hands:
		(hands[hand_name] as Node3D).rotation.z = float(turns.get(hand_name, 0.0))


# ------------------------------------------------------------------ sounds

## The conductor's whistle at `at` (in the space of `host`, the station) when he is not at
## his door to blow it himself.
func play_whistle(host: Node3D, at: Vector3) -> void:
	StationAudio.play_at(host, WHISTLE_SOUND, at, -3.0)


## The doors of a train beeping shut, at the middle of the train.
func play_doors_shutting(host: Node3D, at: Vector3) -> void:
	StationAudio.play_at(host, DOORS_SHUT_SOUND, at, -3.0)


## The horn of a train pulling out, at its nose.
func play_horn(host: Node3D, at: Vector3) -> void:
	StationAudio.play_at(host, HORN_SOUND, at, -10.0)


## The beep of an OV post (`sound_name`: in, out or refused) at `at`.
func play_post(host: Node3D, sound_name: String, at: Vector3) -> void:
	StationAudio.play_at(host, sound_name, at, -6.0)
