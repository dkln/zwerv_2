extends SceneTree
## Builds the interiors (scenes/binnen/) from the tiles of the library binnen
## (tools/voxgen/tiles/interior.py), as a starting point: after that they are edited by hand
## in Godot, so a scene that is there already is left alone (unless "opnieuw" is given).
##   tools/godot.sh --headless --script tools/build/build_interiors.gd [-- opnieuw]
## The snack bar (scenes/binnen/snackbar.tscn, script scripts/world/interior.gd): 12 x 8 m,
## the floor in the GridMap Vloer (its top at y = 0), walls and furniture in Inrichting: high
## walls at the back (+z, the counter, the fryer and the menu board against it) and the left
## (-x, the fridge), low walls at the front (-z, with the door in the middle) and the right,
## where the camera looks in from (Iso.DIRECTION). Markers (Marker3D, moved about freely in
## the editor): Deur (where you come in and go out, facing into the room), Snackbarhouder
## (behind the counter, facing the room), Plek* (the chairs: who sits there faces the way the
## marker does). Two warm lamps (OmniLight3D). All tiles in the variant "zwartwit"; the other
## variants are swapped in per snack bar (Interior.dress).

## Den Haag Centraal (scenes/binnen/centraal.tscn, script scripts/world/station.gd): the plan
## of StationLayout (scripts/world/station_layout.gd): the hall with its stone floor (Vloer),
## walls, shops, ticket machines, boards, clock, columns and glass fences (Inrichting), the
## platforms and tracks from the town's ground tiles (Sporen, PLATFORM_DROP down), benches,
## bins and OV posts from the props (Props), lamps, and markers: Deur1..3 (the entrances),
## Dienstdeur (where the staff come and go), Poortjes_<n> (the gates before platform n: the
## game puts the cabinets and paddles there), Vertrekbord_<n>, Perronscherm_<track>, Klok,
## Winkel_<n> and Verkoper_<n> (the front of a shop and who works in it; metadata "kind" and
## "shop_name"), Automaat_<n> (before a ticket machine).
##   tools/godot.sh --headless --script tools/build/build_interiors.gd [-- opnieuw] [-- centraal]
## The supermarket (scenes/binnen/supermarkt.tscn, script scripts/world/supermarket.gd): only
## its root: every branch lays itself out as you walk in (scripts/world/supermarket_layout.gd).
## The city hall (scenes/binnen/stadhuis.tscn, script scripts/world/city_hall.gd): the five
## floors of CityHallLayout (scripts/world/city_hall_layout.gd) side by side, Etage0..Etage4
## (each its GridMaps Vloer and Inrichting, its lamps and markers: Lift (where you call it,
## facing out of it), Liftdeur (the middle of its doors), Persoon_<n> (metadata "role",
## "sit", "seat"), Bord_<n> (metadata "text": a sign), Loket_<n> (the number board of a
## counter), Nummerautomaat), and Deur (the entrance, on floor 0).
## Names after "--" pick the scenes (snackbar, centraal, supermarkt, stadhuis; none = all).

const Common = preload("res://tools/tool_common.gd")
const SCENE := "res://scenes/binnen/snackbar.tscn"
const STATION_SCENE := "res://scenes/binnen/centraal.tscn"
const SUPERMARKET_SCENE := "res://scenes/binnen/supermarkt.tscn"
const CITY_HALL_SCENE := "res://scenes/binnen/stadhuis.tscn"
const CityHallLayout = preload("res://scripts/world/city_hall_layout.gd")
const SCENES := {"snackbar": SCENE, "centraal": STATION_SCENE, "supermarkt": SUPERMARKET_SCENE, "stadhuis": CITY_HALL_SCENE}
const LIBRARY := "res://assets/libraries/binnen.res"
const GROUND_LIBRARY := "res://assets/libraries/grond.res"
const PROPS_LIBRARY := "res://assets/libraries/props.res"
const VARIANT := "zwartwit"
const PREFIX := "snackbar/"
const STATION_PREFIX := "station/"
const Layout = preload("res://scripts/world/station_layout.gd")
## The shops of the hall: [kind (tile winkel_<kind>), name on the sign], in the order they
## are put down (the left wall first, then the block in the middle).
const SHOPS := [
	["koffie", "Duwus Bertus"], ["broodjes", "Broodje Seinstoring"], ["kiosk", "Kiosk Centraal"],
	["bloemen", "Bloemen van de Hofvijver"], ["boeken", "Boek & Spoor"],
	["smikkels", "Smikkels"], ["koffie", "Duwus Bertus"], ["stroopwafels", "Stroopwafel Express"], ["snoep", "De Zoete Inval"],
	["broodjes", "Broodje Seinstoring"], ["smikkels", "Smikkels"], ["kiosk", "Kiosk Perron 12"], ["bloemen", "Tulp & Tak"],
]

var _failed := false


func _init() -> void:
	Common.watchdog(self, 180)
	var rebuild := false
	var wanted: Array[String] = []
	for index in Common.arg_count():
		var word := Common.arg(index, "")
		if word == "opnieuw":
			rebuild = true
		elif word != "":
			wanted.append(word)
	if wanted.is_empty():
		wanted.assign(SCENES.keys())
	var library: MeshLibrary = load(LIBRARY)
	for scene_name in wanted:
		var path: String = SCENES.get(scene_name, "")
		if path != "" and ResourceLoader.exists(path) and not rebuild:
			print("interiors: %s is er al (handwerk blijft staan; -- opnieuw bouwt hem over)" % path)
			continue
		if scene_name == "snackbar":
			_build_snack_bar(library)
		elif scene_name == "centraal":
			_build_station(library)
		elif scene_name == "supermarkt":
			_build_supermarket()
		elif scene_name == "stadhuis":
			_build_city_hall(library)
		else:
			push_error("interiors: onbekende binnenruimte %s" % scene_name)
			_failed = true
	quit(1 if _failed else 0)


func _build_snack_bar(library: MeshLibrary) -> void:
	var root := Node3D.new()
	root.name = "Snackbar"
	root.set_script(load("res://scripts/world/interior.gd"))
	var floor_map := _grid("Vloer", library, Vector3(0.0, -0.125, 0.0))
	var furniture := _grid("Inrichting", library, Vector3.ZERO)
	root.add_child(floor_map)
	root.add_child(furniture)
	# the floor: 3 x 2 tiles of 4 m
	for x in [-4.0, 0.0, 4.0]:
		for z in [-2.0, 2.0]:
			_put(floor_map, library, "vloer_" + VARIANT, Vector3(x, 0.0, z), 0.0)
	# high walls at the back and the left, facing into the room
	for x in [-4.0, 0.0, 4.0]:
		_put(furniture, library, "muur_" + VARIANT, Vector3(x, 0.0, 4.0), PI)
	for z in [-2.0, 2.0]:
		_put(furniture, library, "muur_" + VARIANT, Vector3(-6.0, 0.0, z), PI * 0.5)
	# low walls at the front (the door in the middle) and the right
	for x in [-4.0, 4.0]:
		_put(furniture, library, "muur_laag_" + VARIANT, Vector3(x, 0.0, -4.0), 0.0)
	for x in [-1.5, 1.5]:
		_put(furniture, library, "muur_laag_half_" + VARIANT, Vector3(x, 0.0, -4.0), 0.0)
	for z in [-2.0, 2.0]:
		_put(furniture, library, "muur_laag_" + VARIANT, Vector3(6.0, 0.0, z), -PI * 0.5)
	# the counter, the fryer and the menu board behind it, the fridge on the left
	_put(furniture, library, "toonbank_" + VARIANT, Vector3(0.0, 0.0, 1.5), PI)
	_put(furniture, library, "frituur", Vector3(1.5, 0.0, 3.5), PI)
	_put(furniture, library, "menubord", Vector3(-1.5, 1.0, 3.5), PI)
	_put(furniture, library, "koelkast", Vector3(-5.5, 0.0, 2.5), PI * 0.5)
	_put(furniture, library, "deurmat", Vector3(0.0, 0.0, -3.5), 0.0)
	# two tables with a chair on each side
	var seats := 0
	for table_x in [-3.5, 3.5]:
		_put(furniture, library, "tafel", Vector3(table_x, 0.0, -1.5), 0.0)
		for side in [-1.0, 1.0]:
			var at := Vector3(table_x, 0.0, -1.5 + side)
			var facing := PI if side > 0.0 else 0.0   # towards the table
			_put(furniture, library, "stoel", at, facing)
			seats += 1
			_marker(root, "Plek%d" % seats, at, facing)
	_marker(root, "Deur", Vector3(0.0, 0.0, -3.2), 0.0)
	_marker(root, "Snackbarhouder", Vector3(-0.5, 0.0, 2.5), PI)
	for lamp_x in [-3.0, 3.0]:
		var lamp := OmniLight3D.new()
		lamp.name = "Lamp" if lamp_x < 0.0 else "Lamp2"
		lamp.position = Vector3(lamp_x, 2.7, 0.0)
		lamp.light_color = Color("#FFE2B0")
		lamp.light_energy = 1.4
		lamp.omni_range = 8.0
		root.add_child(lamp)
	for child in root.get_children():
		child.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE.get_base_dir()))
	var error := ResourceSaver.save(packed, SCENE)
	print("interiors: %s %s (%d plekken)" % [SCENE, "bewaard" if error == OK else "FOUT %d" % error, seats])
	root.free()
	if error != OK:
		_failed = true


func _grid(grid_name: String, library: MeshLibrary, at: Vector3) -> GridMap:
	var grid := GridMap.new()
	grid.name = grid_name
	grid.mesh_library = library
	grid.cell_size = Vector3(0.5, 0.5, 0.5)
	grid.cell_center_x = false
	grid.cell_center_y = false
	grid.cell_center_z = false
	grid.position = at
	return grid


## A tile at `at` (metres, on the 0.5 m grid), turned `turn` radians (its front, +z, then
## faces (sin turn, 0, cos turn)).
func _put(grid: GridMap, library: MeshLibrary, tile_name: String, at: Vector3, turn: float) -> void:
	var item := library.find_item_by_name(PREFIX + tile_name)
	if item < 0:
		push_error("interiors: no tile %s%s" % [PREFIX, tile_name])
		return
	var cell := Vector3i(roundi(at.x * 2.0), roundi(at.y * 2.0), roundi(at.z * 2.0))
	grid.set_cell_item(cell, item, grid.get_orthogonal_index_from_basis(Basis(Vector3.UP, turn)))


func _marker(root: Node3D, marker_name: String, at: Vector3, turn: float) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = at
	marker.rotation.y = turn
	root.add_child(marker)


# ------------------------------------------------------------------ Den Haag Centraal

func _build_station(library: MeshLibrary) -> void:
	var ground_library: MeshLibrary = load(GROUND_LIBRARY)
	var props_library: MeshLibrary = load(PROPS_LIBRARY)
	var root := Node3D.new()
	root.name = "Centraal"
	root.set_script(load("res://scripts/world/station.gd"))
	var floor_map := _grid("Vloer", library, Vector3(0.0, -0.125, 0.0))
	var furniture := _grid("Inrichting", library, Vector3.ZERO)
	var props := _grid("Props", props_library, Vector3.ZERO)
	var tracks := GridMap.new()
	tracks.name = "Sporen"
	tracks.mesh_library = ground_library
	tracks.cell_size = Vector3(Layout.CELL, 1.0, Layout.CELL)
	tracks.cell_center_y = false
	tracks.position = Vector3(Layout.HALL_LEFT, -Layout.PLATFORM_DROP, 0.0)
	for grid in [floor_map, furniture, tracks, props]:
		root.add_child(grid)
	var missing := []
	_station_floor_and_tracks(library, ground_library, floor_map, tracks, missing)
	_station_walls(library, furniture, missing)
	_station_shops(root, library, furniture, missing)
	_station_furniture(root, library, furniture, props_library, props, missing)
	_station_markers(root)
	_station_lamps(root)
	for child in root.get_children():
		child.owner = root
	if not missing.is_empty():
		push_error("interiors: tiles ontbreken in de bibliotheken (eerst importeren en build_libraries): %s" % ", ".join(missing))
		root.free()
		_failed = true
		return
	var packed := PackedScene.new()
	packed.pack(root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STATION_SCENE.get_base_dir()))
	var error := ResourceSaver.save(packed, STATION_SCENE)
	print("interiors: %s %s (%d sporen, %d perrons, %d winkels)" % [STATION_SCENE, "bewaard" if error == OK else "FOUT %d" % error,
		Layout.TRACK_COUNT, Layout.platforms().size(), SHOPS.size()])
	root.free()
	if error != OK:
		_failed = true


## The stone floor of the hall, and the platforms and tracks (the town's tiles) behind it.
func _station_floor_and_tracks(library: MeshLibrary, ground_library: MeshLibrary, floor_map: GridMap, tracks: GridMap, missing: Array) -> void:
	for column in Layout.COLUMN_COUNT:
		var x := Layout.column_x(column)
		for z in range(int(Layout.HALL_FRONT) + 2, 0, 4):
			_put_item(floor_map, library, STATION_PREFIX + "vloer", Vector3(x, 0.0, z), 0.0, missing)
		var platform := Layout.column_kind(column) == "P"
		var track_side := 1 if column + 1 < Layout.COLUMN_COUNT and Layout.column_kind(column + 1) == "T" else -1
		for row in Layout.PLATFORM_ROWS:
			var cell := Vector3i(column, 0, row)
			if platform:
				# the yellow edge (the tile's front, +z) towards the track beside it
				_put_cell(tracks, ground_library, "spoor/perron", cell, PI * 0.5 * track_side, missing)
			else:
				_put_cell(tracks, ground_library, "spoor/trein_stootblok" if row == 0 else "spoor/trein_recht", cell, 0.0, missing)


## The walls: high at the left and the back (openings for the tracks, dark behind them), low at
## the front (the entrances open) and the right.
func _station_walls(library: MeshLibrary, furniture: GridMap, missing: Array) -> void:
	for z in range(int(Layout.HALL_FRONT) + 2, int(Layout.BACK_WALL), 4):
		_put_item(furniture, library, STATION_PREFIX + "wand", Vector3(Layout.HALL_LEFT, 0.0, z), PI * 0.5, missing)
		_put_item(furniture, library, STATION_PREFIX + "wand_laag", Vector3(Layout.HALL_RIGHT, 0.0, z), -PI * 0.5, missing)
	for column in Layout.COLUMN_COUNT:
		var x := Layout.column_x(column)
		var track := Layout.column_kind(column) == "T"
		_put_item(furniture, library, STATION_PREFIX + ("wand_spoor" if track else "wand"), Vector3(x, 0.0, Layout.BACK_WALL), PI, missing)
		if track:
			_put_item(furniture, library, STATION_PREFIX + "tunnel", Vector3(x, -Layout.PLATFORM_DROP + 0.375, Layout.BACK_WALL + 0.5), PI, missing)
	# the front: 4 m pieces between the entrances, 2 m at both ends
	var x := Layout.HALL_LEFT + 1.0
	_put_item(furniture, library, STATION_PREFIX + "wand_laag_half", Vector3(x, 0.0, Layout.HALL_FRONT), 0.0, missing)
	_put_item(furniture, library, STATION_PREFIX + "wand_laag_half", Vector3(Layout.HALL_RIGHT - 1.0, 0.0, Layout.HALL_FRONT), 0.0, missing)
	var middle := Layout.HALL_LEFT + 4.0
	while middle < Layout.HALL_RIGHT - 2.0:
		var at_entrance := false
		for entrance_x: float in Layout.ENTRANCE_X:
			if absf(middle - entrance_x) < Layout.ENTRANCE_WIDTH * 0.5:
				at_entrance = true
		if not at_entrance:
			_put_item(furniture, library, STATION_PREFIX + "wand_laag", Vector3(middle, 0.0, Layout.HALL_FRONT), 0.0, missing)
		middle += 4.0


## The shops: five along the left wall (facing into the hall), a block of eight in the middle
## (four facing the entrances, four the platforms). Markers before each (Winkel_<n>) and in it
## (Verkoper_<n>), with what it is and its name.
func _station_shops(root: Node3D, library: MeshLibrary, furniture: GridMap, missing: Array) -> void:
	var spots := []   # [middle, turn]
	for z in [-28.0, -24.0, -20.0, -16.0, -12.0]:
		spots.append([Vector3(Layout.LEFT_SHOPS_X, 0.0, z), PI * 0.5])
	var block := Layout.SHOP_BLOCK
	for x in [-6.0, -2.0, 2.0, 6.0]:
		spots.append([Vector3(x, 0.0, block.position.y + 1.5), PI])
	for x in [-6.0, -2.0, 2.0, 6.0]:
		spots.append([Vector3(x, 0.0, block.end.y - 1.5), 0.0])
	for index in spots.size():
		var shop: Array = SHOPS[index % SHOPS.size()]
		var middle: Vector3 = spots[index][0]
		var turn: float = spots[index][1]
		_put_item(furniture, library, STATION_PREFIX + "winkel_" + shop[0], middle, turn, missing)
		var facing := Basis(Vector3.UP, turn)
		var front := _marker_at(root, "Winkel_%d" % (index + 1), middle + facing * Vector3(0.0, 0.0, 2.6), turn + PI)
		front.set_meta("kind", shop[0])
		front.set_meta("shop_name", shop[1])
		var keeper := _marker_at(root, "Verkoper_%d" % (index + 1), middle + facing * Vector3(0.0, 0.0, -0.2), turn)
		keeper.set_meta("kind", shop[0])
		keeper.set_meta("shop_name", shop[1])
		# where its name hangs: the sign band over the front, a little before it
		_marker_at(root, "Uithangbord_%d" % (index + 1), middle + facing * Vector3(0.0, 3.05, 1.58), turn)


## Ticket machines, the boards, the clock, columns, the fences before the tracks; benches,
## bins, plants and OV posts.
func _station_furniture(root: Node3D, library: MeshLibrary, furniture: GridMap, props_library: MeshLibrary, props: GridMap, missing: Array) -> void:
	var machine_count := 0
	for z in [-25.0, -24.0, -23.0, -22.0, -14.0, -13.0, -12.0]:
		machine_count += 1
		var at := Vector3(Layout.TICKET_MACHINES_X - 0.5, 0.0, z)
		_put_item(furniture, library, STATION_PREFIX + "kaartautomaat", at, -PI * 0.5, missing)
		_marker_at(root, "Automaat_%d" % machine_count, at + Vector3(-0.9, 0.0, 0.0), PI * 0.5)
	for x in [-37.0, -36.0, 36.0, 37.0]:
		machine_count += 1
		var at := Vector3(x, 0.0, -6.0)
		_put_item(furniture, library, STATION_PREFIX + "kaartautomaat", at, PI, missing)
		_marker_at(root, "Automaat_%d" % machine_count, at + Vector3(0.0, 0.0, -0.9), 0.0)
	# the departure boards over the hall, facing the entrances
	for index in 3:
		var x: float = [-24.0, 0.0, 24.0][index]
		_put_item(furniture, library, STATION_PREFIX + "vertrekbord", Vector3(x, 3.5, -8.0), PI, missing)
		_marker_at(root, "Vertrekbord_%d" % (index + 1), Vector3(x, 3.5 + 0.875, -8.16), PI)
	# the displays at the heads of the tracks, over the walking line beside each track
	for track in range(1, Layout.TRACK_COUNT + 1):
		var x := Layout.platform_walk_x(track)
		x = roundf(x * 2.0) * 0.5
		_put_item(furniture, library, STATION_PREFIX + "perronscherm", Vector3(x, 3.0, 3.0), PI, missing)
		_marker_at(root, "Perronscherm_%d" % track, Vector3(x, 3.0 + 0.375, 2.84), PI)
	_put_item(furniture, library, STATION_PREFIX + "klok", Vector3(0.0, 4.5, -12.0), PI, missing)
	_marker_at(root, "Klok", Vector3(0.0, 4.5 + 0.5625, -12.16), PI)
	# columns down the middle of every island, and a few in the hall
	for platform: Array in Layout.platforms():
		if int(platform[1]) == int(platform[0]):
			continue
		var middle := (Layout.platform_span(platform).x + Layout.platform_span(platform).y) * 0.5
		for z in [8.0, 20.0, 32.0, 44.0]:
			_put_item(furniture, library, STATION_PREFIX + "pilaar", Vector3(middle, 0.0, z), 0.0, missing)
		for z in [14.0, 26.0, 38.0]:
			_put_cell_props(props, props_library, "straat/bank_modern", Vector3(middle, 0.0, z), PI * 0.5, missing)
		for z in [16.0, 34.0]:
			_put_cell_props(props, props_library, "straat/prullenbak_paal", Vector3(middle, 0.0, z), 0.0, missing)
		# an OV post at the head of the island, for those changing trains
		_put_cell_props(props, props_library, "ov/ov_incheckpaal", Vector3(middle, 0.0, 1.5), PI, missing)
	for x in [-40.0, -16.0, 16.0, 40.0]:
		for z in [-24.0, -12.0]:
			_put_item(furniture, library, STATION_PREFIX + "pilaar", Vector3(x, 0.0, z), 0.0, missing)
	# glass fences before the tracks, in the gate line
	for column in Layout.COLUMN_COUNT:
		if Layout.column_kind(column) == "T":
			_put_item(furniture, library, STATION_PREFIX + "hek", Vector3(Layout.column_x(column), 0.0, Layout.GATE_Z), 0.0, missing)
	# benches, plants and bins in the hall
	for x in [-30.0, -20.0, 20.0, 30.0]:
		_put_cell_props(props, props_library, "straat/bank_modern", Vector3(x, 0.0, -26.0), 0.0, missing)
		_put_cell_props(props, props_library, "planten/plantenbak_beton", Vector3(x + 3.0, 0.0, -26.0), 0.0, missing)
	for x in [-12.0, 12.0]:
		_put_cell_props(props, props_library, "straat/prullenbak_paal", Vector3(x, 0.0, -12.0), 0.0, missing)
	# OV posts by the entrances (for the RandstadRail and the trams outside)
	for entrance_x: float in Layout.ENTRANCE_X:
		_put_cell_props(props, props_library, "ov/ov_incheckpaal", Vector3(entrance_x + 3.0, 0.0, -29.0), 0.0, missing)


func _station_markers(root: Node3D) -> void:
	for index in Layout.ENTRANCE_X.size():
		_marker_at(root, "Deur%d" % (index + 1), Vector3(Layout.ENTRANCE_X[index], 0.0, Layout.HALL_FRONT + 1.0), 0.0)
	_marker_at(root, "Dienstdeur", Vector3(Layout.HALL_LEFT + 0.8, 0.0, -8.0), PI * 0.5)
	var platforms := Layout.platforms()
	for index in platforms.size():
		var span := Layout.platform_span(platforms[index])
		_marker_at(root, "Poortjes_%d" % (index + 1), Vector3((span.x + span.y) * 0.5, 0.0, Layout.GATE_Z), 0.0)


func _station_lamps(root: Node3D) -> void:
	var spots: Array[Vector3] = []
	for x in [-32.0, 0.0, 32.0]:
		for z in [-24.0, -8.0]:
			spots.append(Vector3(x, 6.0, z))
	for platform: Array in Layout.platforms():
		var span := Layout.platform_span(platform)
		for z in [12.0, 36.0]:
			spots.append(Vector3((span.x + span.y) * 0.5, 6.0, z))
	for index in spots.size():
		var lamp := OmniLight3D.new()
		lamp.name = "Lamp%d" % (index + 1)
		lamp.position = spots[index]
		lamp.light_color = Color("#FFF1DC")
		lamp.light_energy = 1.3
		lamp.omni_range = 20.0
		lamp.shadow_enabled = false
		root.add_child(lamp)


## A tile of any library by its full name (as the library has it) at `at` on the 0.5 m grid.
func _put_item(grid: GridMap, library: MeshLibrary, tile_name: String, at: Vector3, turn: float, missing: Array) -> void:
	var item := library.find_item_by_name(tile_name)
	if item < 0:
		if not missing.has(tile_name):
			missing.append(tile_name)
		return
	var cell := Vector3i(roundi(at.x * 2.0), roundi(at.y * 2.0), roundi(at.z * 2.0))
	grid.set_cell_item(cell, item, grid.get_orthogonal_index_from_basis(Basis(Vector3.UP, turn)))


func _put_cell_props(grid: GridMap, library: MeshLibrary, tile_name: String, at: Vector3, turn: float, missing: Array) -> void:
	_put_item(grid, library, tile_name, at, turn, missing)


## A ground tile in a cell of the 4 m map.
func _put_cell(grid: GridMap, library: MeshLibrary, tile_name: String, cell: Vector3i, turn: float, missing: Array) -> void:
	var item := library.find_item_by_name(tile_name)
	if item < 0:
		if not missing.has(tile_name):
			missing.append(tile_name)
		return
	grid.set_cell_item(cell, item, grid.get_orthogonal_index_from_basis(Basis(Vector3.UP, turn)))


func _marker_at(root: Node3D, marker_name: String, at: Vector3, turn: float) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = at
	marker.rotation.y = turn
	root.add_child(marker)
	return marker


# ------------------------------------------------------------------ the supermarket

func _build_supermarket() -> void:
	var root := Node3D.new()
	root.name = "Supermarkt"
	root.set_script(load("res://scripts/world/supermarket.gd"))
	_save(root, SUPERMARKET_SCENE, "elk filiaal deelt zich zelf in")


# ------------------------------------------------------------------ the city hall

func _build_city_hall(library: MeshLibrary) -> void:
	var root := Node3D.new()
	root.name = "Stadhuis"
	root.set_script(load("res://scripts/world/city_hall.gd"))
	var missing := []
	var people := 0
	for plan: Dictionary in CityHallLayout.floors():
		var number := int(plan.number)
		var floor_node := Node3D.new()
		floor_node.name = "Etage%d" % number
		floor_node.position = Vector3(number * CityHallLayout.FLOOR_SPACING, 0.0, 0.0)
		root.add_child(floor_node)
		var floor_map := _grid("Vloer", library, Vector3(0.0, -0.125, 0.0))
		var furniture := _grid("Inrichting", library, Vector3.ZERO)
		floor_node.add_child(floor_map)
		floor_node.add_child(furniture)
		var width := float(plan.width)
		var depth := float(plan.depth)
		for column in int(width / 4.0):
			for row in int(depth / 4.0):
				_put_item(floor_map, library, "stadhuis/" + String(plan.floor),
					Vector3(-width * 0.5 + 2.0 + column * 4.0, 0.0, -depth * 0.5 + 2.0 + row * 4.0), 0.0, missing)
		for entry: Array in plan.tiles:
			_put_item(furniture, library, "stadhuis/" + String(entry[0]), entry[1], float(entry[2]), missing)
		_marker_at(floor_node, "Lift", plan.lift_spot, PI)
		_marker_at(floor_node, "Liftdeur", (plan.lift as Vector3) + Vector3(0.0, 0.0, -CityHallLayout.LIFT_DEPTH * 0.5 + 0.06), PI)
		for index in plan.people.size():
			var person: Dictionary = plan.people[index]
			var marker := _marker_at(floor_node, "Persoon_%d" % (index + 1), person.at, float(person.turn))
			marker.set_meta("role", person.role)
			marker.set_meta("sit", person.sit)
			marker.set_meta("seat", person.seat)
			people += 1
		for index in plan.signs.size():
			var sign: Dictionary = plan.signs[index]
			var marker := _marker_at(floor_node, "Bord_%d" % (index + 1), sign.at, float(sign.turn))
			marker.set_meta("text", sign.text)
		for counter: Dictionary in plan.counters:
			_marker_at(floor_node, "Loket_%d" % int(counter.number), counter.board_at, PI)
		if plan.has("dispenser"):
			_marker_at(floor_node, "Nummerautomaat", plan.dispenser, PI)
		if plan.has("door"):
			_marker_at(root, "Deur", (plan.door as Vector3) + floor_node.position, 0.0)
		for index in plan.lamps.size():
			var lamp := OmniLight3D.new()
			lamp.name = "Lamp%d" % (index + 1)
			lamp.position = plan.lamps[index]
			lamp.light_color = Color("#FFF6E8")
			lamp.light_energy = 1.2
			lamp.omni_range = 10.0
			floor_node.add_child(lamp)
	if not missing.is_empty():
		push_error("interiors: tiles ontbreken in de bibliotheek binnen (eerst importeren en build_libraries): %s" % ", ".join(missing))
		root.free()
		_failed = true
		return
	_save(root, CITY_HALL_SCENE, "%d etages, %d mensen" % [CityHallLayout.FLOORS, people])


## Every node owned by `root` (so it is saved), the scene packed and saved at `path`.
func _save(root: Node3D, path: String, what: String) -> void:
	for child in root.find_children("*", "", true, false):
		child.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var error := ResourceSaver.save(packed, path)
	print("interiors: %s %s (%s)" % [path, "bewaard" if error == OK else "FOUT %d" % error, what])
	root.free()
	if error != OK:
		_failed = true
