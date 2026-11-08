extends SceneTree
## Makes the small 3D map behind the main menu (scripts/ui/main_menu.gd) in two steps:
## 1. scenes/menu_kaart_bron.tscn, the source you edit: a piece of scenes/stad.tscn round
##    the skyline of Centraal (the station, the ministry towers, the Hoftoren, the
##    Beatrixkwartier; cells MAP_FIRST..MAP_LAST) with the town's GridMaps, its light, the
##    Dagcyclus standing still at NIGHT_HOUR, a dark ground plane and the camera. Made only
##    when it does not exist yet (your edits stay), or anew with "overschrijf".
## 2. scenes/menu_kaart.scn, what the menu shows: a small derivative of the town, set up as
##    the town is: its four GridMaps (the ground with the grass field, buildings, details and
##    props, in the full tiles) on small libraries of their own (assets/libraries/menu/*.res:
##    only the tiles the map uses, copies) and the town's own helpers working live on them
##    (TintKaart, GrondKaart, Verkeerslichten, Rook, Bovenleiding, Tunnelverlichting), the
##    trams and the columns. Left out, to keep baking and loading short: the DetailNiveau
##    (its merging takes long) and the grass blades (they follow the iso camera).
##    So the menu shares nothing with the town and stays small (a baked map, every
##    triangle written out, was hundreds of MB and ran the memory out when the town
##    loaded). Made every time; after editing the source, run the tool again.
## usage: Godot --headless --script tools/build/build_menu_map.gd [-- overschrijf]

const Common = preload("res://tools/tool_common.gd")
const CITY := "res://scenes/stad.tscn"
const SOURCE := "res://scenes/menu_kaart_bron.tscn"
const MENU_MAP := "res://scenes/menu_kaart.scn"
## First and last cell (x, z) of the piece of town that is copied.
const MAP_FIRST := Vector2i(66, 56)
const MAP_LAST := Vector2i(130, 120)
## More of the town round the piece (first and last cell): the streets left of it, up to
## the landmarks put in view there (TRANSPLANTS, from row 98).
const MORE_AREAS := [[Vector2i(42, 56), Vector2i(65, 96)]]
## Landmarks beyond the piece that stand out over the skyline from the camera (first and
## last cell): the Strijkijzer, the apartment tower in Laak.
const LANDMARK_AREAS := [[Vector2i(100, 140), Vector2i(110, 152)], [Vector2i(99, 158), Vector2i(111, 167)]]
## The foreground: grass (natuur/gras) from the camera to the town over the whole strip
## (with the water in front), drawn with the coarse
## tiles of the ground (the *_lod2 library: from this low and far the fine ones are not to be
## seen, and they would make the map heavy).
const FIELD_TILE := "natuur/gras"
## The map repeats sideways (the menu lays copies left and right of it and lets the camera
## glide on and on): the strip of town cells from STRIP_FIRST_COLUMN to STRIP_LAST_COLUMN
## (the landmarks on the left, the piece of town on the right) is one period; its width in
## metres goes into the metadata "periode" of the map.
const STRIP_FIRST_COLUMN := 42
const STRIP_LAST_COLUMN := 130
## The water in front, along the whole strip: from the camera's row (counted from it) to
## the bank on the far side, the town's water tiles with their reflections; the grass
## begins behind it. (The near bank lies behind the camera.)
const DITCH_ROWS := [-3, 16]
## The water's shader (voxel_water.gdshader) in the menu: bigger, longer waves, much more
## glitter and light patches, a stronger reflection that reaches far enough to show the
## skyline a few hundred metres off (the town's reaches 12 m: steps x step_size).
const MENU_WATER := {"wave_height": 0.1, "wave_speed": 1.0, "wave_length": 9.0, "patches": 0.55, "glitter": 0.5,
	"reflection": 0.4, "sky_reflection": 0.18, "ripple": 0.55, "steps": 28, "step_size": 14.0, "thickness": 30.0}
## Plain water only (the lilies and reeds of the town's ponds float about in it).
const WATER_TILES := ["water/water"]
## The sun's shadows for this far, low view: as far as the skyline, the cascades spread over it.
const SHADOW_DISTANCE := 900.0
const SHADOW_SPLITS := Vector3(0.08, 0.25, 0.55)
## Landmarks of the town put in view anyway (not where they really are), in the empty part
## left of the skyline behind Centraal: name, first and last cell in the town, and the cell
## their first cell goes to. Their buildings, details and ground are copied as they stand.
const TRANSPLANTS := [
	["Malietoren", Vector2i(99, 20), Vector2i(105, 27), Vector2i(48, 98)],
	["Grote Kerk", Vector2i(10, 35), Vector2i(12, 38), Vector2i(60, 102)],
	["Paulussen-schoorsteen", Vector2i(164, 136), Vector2i(166, 138), Vector2i(42, 112)],
	["Huis ten Bosch", Vector2i(111, 3), Vector2i(121, 11), Vector2i(54, 116)],
]
## Buildings of the piece left out of the map (first and last cell; every storey, with
## their details): the wing of the Ministerie van VWS on thin pillars over the tram tracks
## beside Centraal, which from the menu's camera seemed to float.
const LEFT_OUT_AREAS := [[Vector2i(71, 86), Vector2i(74, 89)]]
## The hour the map shows (night: lit windows and signs).
const NIGHT_HOUR := 21.5   # a summer night (scripts/effects/day_cycle.gd: dark from about 23:30)
## The camera, as the skyline of the design: low and far off to the north, a narrow lens
## looking almost level over the town, so the towers stand flat against the sky low in the
## picture, on its right (the menu is on the left); the horizon lies about a quarter of the
## picture from the bottom. Where it stands and what it looks at (metres), and the lens.
const CAMERA_AT := Vector3(300.0, 4.5, -100.0)   # low: close to the grass and the columns
const CAMERA_LOOKS_AT := Vector3(330.0, 30.0, 300.0)
const CAMERA_FOV := 18.0
## A dark plane under it all (the land beyond the piece of town), its colour and size.
const GROUND_COLOUR := Color("#141A44")
const GROUND_SIZE := 6000.0
## Nodes of the town copied as they are.
const COPIED := ["Omgeving", "Zon", "Vullicht", "Dagcyclus", "TintKaart", "GrondKaart",
	"Verkeerslichten", "Rook", "Bovenleiding", "Tunnelverlichting"]
## The Bovenleiding hides its wires when the view is wide (overhead_lines.gd, by the iso
## camera's view size); the menu's camera looks level over the town, so always shown.
const WIRES_SHOWN_UNTIL := 100000.0
## The menu's own furniture on the grass, as the town's props: a tram on grass on each tram
## line (TRAM_TILE, along x), an overhead line mast (MAST_TILE, its arm towards the camera)
## every MAST_SPACING metres MAST_BEHIND metres beyond each track, and street lamps
## (LAMP_TILE) every LAMP_SPACING metres along the road of the columns, LAMP_AHEAD metres in
## front of the camera (just beyond the tractors' lane).
const TRAM_TILE := "tram/tram_gras_recht"
const MAST_TILE := "ov/tram_bovenleiding_mast"
const MAST_SPACING := 24.0
const MAST_BEHIND := 2.5
const LAMP_TILE := "verlichting/lantaarn_klassiek"
const LAMP_SPACING := 16.0
const LAMP_AHEAD := 84.0

const GRIDS := ["Grond", "Gebouwen", "Details", "Props"]
## A tram that now and then rides through the picture in front of the skyline (the menu
## moves it, scripts/ui/main_menu.gd): its cars (props items, front along +Z; the last one
## turned round), their length and gap, the metres in front of the camera of its track, and
## how far each way of the middle of the view the track runs.
const TRAM_CARS := ["voertuigen/randstadrail_kop", "voertuigen/randstadrail_midden", "voertuigen/randstadrail_kop"]
const TRAM_CAR_LENGTH := 11.0
const TRAM_CAR_GAP := 0.25
## Its tracks: metres ahead of the camera (one in the foreground, one just in front of the
## buildings at the back), along the whole strip.
const TRAM_TRACKS_AHEAD := [110.0, 318.0]
## Layers left out of the baked map (none: the props are the town's lamps, masts and lights).
const LEFT_OUT_OF_BAKE := []
## The source GridMaps that are baked (the grass field of the foreground too).


func _init() -> void:
	Common.watchdog(self, 900)
	if not ResourceLoader.exists(SOURCE) or Common.arg(0, "") == "overschrijf":
		_make_source()
	await _bake_source()
	quit()


# ------------------------------------------------------------------ 1. the source

func _make_source() -> void:
	var city: Node = load(CITY).instantiate()
	var root := Node3D.new()
	root.name = "Menukaart"
	for node_name: String in COPIED + GRIDS:
		var original := city.get_node_or_null(node_name)
		if original == null:
			push_warning("build_menu_map: no node %s in the town" % node_name)
			continue
		var copy := original.duplicate()
		root.add_child(copy)
		if copy is GridMap:
			_keep_piece(copy as GridMap)
	for transplant: Array in TRANSPLANTS:
		_transplant(city, root, transplant)
	for area: Array in LEFT_OUT_AREAS:
		_leave_out(root, area[0], area[1])
	var town_ground := root.get_node_or_null("Grond") as GridMap
	if town_ground:
		root.add_child(_grass_field(town_ground))
	_menu_props(root.get_node_or_null("Props") as GridMap)
	var overhead_lines := root.get_node_or_null("Bovenleiding")
	if overhead_lines:
		overhead_lines.set("shown_until", WIRES_SHOWN_UNTIL)
	var sun := root.get_node_or_null("Zon") as DirectionalLight3D
	if sun:
		# four cascades: the near ones sharp on the grass, the far one over the skyline
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = SHADOW_DISTANCE
		sun.directional_shadow_split_1 = SHADOW_SPLITS.x
		sun.directional_shadow_split_2 = SHADOW_SPLITS.y
		sun.directional_shadow_split_3 = SHADOW_SPLITS.z
	var day_cycle := root.get_node_or_null("Dagcyclus")
	if day_cycle:
		day_cycle.set("time_of_day", NIGHT_HOUR)
		day_cycle.set("speed", 0.0)
	var ground := MeshInstance3D.new()
	ground.name = "Grondvlak"
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = GROUND_COLOUR
	ground_material.roughness = 1.0
	plane.material = ground_material
	ground.mesh = plane
	ground.position = Vector3(CAMERA_LOOKS_AT.x, -0.05, CAMERA_LOOKS_AT.z)
	root.add_child(ground)
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.fov = CAMERA_FOV
	camera.near = 0.5
	camera.far = 4000.0
	root.add_child(camera)
	camera.transform = Transform3D.IDENTITY.looking_at(CAMERA_LOOKS_AT - CAMERA_AT, Vector3.UP)
	camera.position = CAMERA_AT
	camera.current = true
	for child in root.get_children():
		child.owner = root
	_save(root, SOURCE)
	city.free()
	root.free()


## Removes every cell outside the piece MAP_FIRST..MAP_LAST (in 4 m cells; the 0.5 m grids
## of details and props count by the 4 m cell they lie in).
func _keep_piece(grid: GridMap) -> void:
	var per_cell := 4.0 / grid.cell_size.x
	for cell in grid.get_used_cells():
		var town_cell := Vector2i(floori(cell.x / per_cell), floori(cell.z / per_cell))
		if not _kept(town_cell):
			grid.set_cell_item(cell, GridMap.INVALID_CELL_ITEM)
	print("%s: %d cells kept" % [grid.name, grid.get_used_cells().size()])


## Takes the buildings and details on these town cells out of the map.
func _leave_out(root: Node, first: Vector2i, last: Vector2i) -> void:
	for layer_name in ["Gebouwen", "Details"]:
		var grid := root.get_node_or_null(layer_name) as GridMap
		if grid == null:
			continue
		var per_cell := roundi(4.0 / grid.cell_size.x)
		for cell in grid.get_used_cells():
			var town_cell := Vector2i(floori(float(cell.x) / per_cell), floori(float(cell.z) / per_cell))
			if town_cell.x >= first.x and town_cell.x <= last.x and town_cell.y >= first.y and town_cell.y <= last.y:
				grid.set_cell_item(cell, GridMap.INVALID_CELL_ITEM)


## Copies the cells of a landmark (first..last town cell, every layer) from the town to the
## map, its first cell at `to`.
func _transplant(city: Node, root: Node, transplant: Array) -> void:
	var first: Vector2i = transplant[1]
	var last: Vector2i = transplant[2]
	var shift: Vector2i = transplant[3] - first
	var copied := 0
	for layer_name: String in GRIDS:
		var source := city.get_node_or_null(layer_name) as GridMap
		var target := root.get_node_or_null(layer_name) as GridMap
		if source == null or target == null:
			continue
		var per_cell := roundi(4.0 / source.cell_size.x)
		for cell in source.get_used_cells():
			var town_cell := Vector2i(floori(float(cell.x) / per_cell), floori(float(cell.z) / per_cell))
			if town_cell.x < first.x or town_cell.x > last.x or town_cell.y < first.y or town_cell.y > last.y:
				continue
			var moved := cell + Vector3i(shift.x * per_cell, 0, shift.y * per_cell)
			target.set_cell_item(moved, source.get_cell_item(cell), source.get_cell_item_orientation(cell))
			copied += 1
	print("%s in beeld gezet: %d cellen" % [transplant[0], copied])


## True if the town cell lies in the piece or in one of the landmark areas.
static func _kept(town_cell: Vector2i) -> bool:
	for area: Array in [[MAP_FIRST, MAP_LAST]] + MORE_AREAS + LANDMARK_AREAS:
		var first: Vector2i = area[0]
		var last: Vector2i = area[1]
		if town_cell.x >= first.x and town_cell.x <= last.x and town_cell.y >= first.y and town_cell.y <= last.y:
			return true
	return false


## The grass of the foreground: a GridMap "Grasveld" like the town's ground, with grass on
## every cell of the strip from the camera up to the piece of town (where the town has
## nothing), and the water in front with its far bank.
func _grass_field(town_ground: GridMap) -> GridMap:
	var field := GridMap.new()
	field.name = "Grasveld"
	field.mesh_library = town_ground.mesh_library
	field.cell_size = town_ground.cell_size
	field.cell_center_x = town_ground.cell_center_x
	field.cell_center_y = town_ground.cell_center_y
	field.cell_center_z = town_ground.cell_center_z
	field.transform = town_ground.transform
	var library := town_ground.mesh_library
	var grass := library.find_item_by_name(FIELD_TILE)
	var last_row := MAP_FIRST.y + 2
	var camera_row := floori(CAMERA_AT.z / 4.0)
	var ditch_first: int = camera_row + DITCH_ROWS[0]
	var ditch_last: int = camera_row + DITCH_ROWS[1]
	var tram := library.find_item_by_name(TRAM_TILE)
	var tram_rows := TRAM_TRACKS_AHEAD.map(func(ahead: float) -> int: return floori((CAMERA_AT.z + ahead) / 4.0))
	var count := 0
	for z in range(camera_row - 2, last_row + 1):
		for x in range(STRIP_FIRST_COLUMN, STRIP_LAST_COLUMN + 1):
			if town_ground.get_cell_item(Vector3i(x, 0, z)) >= 0:
				continue
			var cell := Vector3i(x, 0, z)
			if z == ditch_first:
				field.set_cell_item(cell, library.find_item_by_name("water/water_oever"), _orientation(field, "S"))
			elif z == ditch_last:
				field.set_cell_item(cell, library.find_item_by_name("water/water_oever"), _orientation(field, "N"))
			elif z > ditch_first and z < ditch_last:
				field.set_cell_item(cell, library.find_item_by_name(WATER_TILES[(x * 3 + z) % WATER_TILES.size()]))
			elif z in tram_rows and tram >= 0:
				field.set_cell_item(cell, tram, _orientation(field, "E"))   # the track along x
			else:
				field.set_cell_item(cell, grass)
			count += 1
	print("Grasveld: %d cellen (met de sloot)" % count)
	return field


## The GridMap orientation of a quarter turn named by the side it faces (as the town's
## builder does it: "S" = 0, then E, N, W).
static func _orientation(grid: GridMap, side: String) -> int:
	var turns: int = ["S", "E", "N", "W"].find(side)
	return grid.get_orthogonal_index_from_basis(Basis(Vector3.UP, turns * PI / 2.0))


## The menu's furniture in the town's Props layer (0.5 m cells): the masts along the tram
## tracks and the street lamps along the road of the columns, over the whole strip.
func _menu_props(props: GridMap) -> void:
	if props == null or props.mesh_library == null:
		return
	var library := props.mesh_library
	var per_metre := 1.0 / props.cell_size.x
	var strip_from := STRIP_FIRST_COLUMN * 4.0
	var strip_to := (STRIP_LAST_COLUMN + 1) * 4.0
	var placed := 0
	var mast := library.find_item_by_name(MAST_TILE)
	if mast >= 0:
		# the arm (the tile's +x) towards the camera (-z)
		var arm_to_camera := props.get_orthogonal_index_from_basis(Basis(Vector3.UP, PI / 2.0))
		for ahead: float in TRAM_TRACKS_AHEAD:
			var along := strip_from + MAST_SPACING * 0.5
			while along < strip_to:
				var at := Vector3(along, 0.0, CAMERA_AT.z + ahead + MAST_BEHIND)
				props.set_cell_item(Vector3i(floori(at.x * per_metre), 0, floori(at.z * per_metre)), mast, arm_to_camera)
				placed += 1
				along += MAST_SPACING
	var lamp := library.find_item_by_name(LAMP_TILE)
	if lamp >= 0:
		var along := strip_from + LAMP_SPACING * 0.5
		while along < strip_to:
			var at := Vector3(along, 0.0, CAMERA_AT.z + LAMP_AHEAD)
			props.set_cell_item(Vector3i(floori(at.x * per_metre), 0, floori(at.z * per_metre)), lamp)
			placed += 1
			along += LAMP_SPACING
	print("Props van het menu: %d (masten, lantaarns)" % placed)


# ------------------------------------------------------------------ 2. the baked map

func _bake_source() -> void:
	var source: Node3D = load(SOURCE).instantiate()
	get_root().add_child(source)
	await process_frame
	var output := Node3D.new()
	output.name = "Menukaart"
	# the ground of the town's piece and the grass field with the water as one GridMap (so the
	# GrondKaart sees both), every layer on a small library of its own
	var town_ground := source.get_node_or_null("Grond") as GridMap
	var field := source.get_node_or_null("Grasveld") as GridMap
	for child in source.get_children():
		if child is GridMap:
			var grid := child as GridMap
			if grid == field or grid.name in LEFT_OUT_OF_BAKE:
				continue
			var layers: Array = [[grid, LAYER_DETAIL.get(String(grid.name), "_lod")]]
			if grid == town_ground and field:
				layers.append([field, FIELD_DETAIL])
			output.add_child(_own_grid(String(grid.name), layers))
		else:
			# the town's helpers as they are saved: what they made while running here (not
			# owned: their wires, plumes, lamps) they make again in the menu
			var helper := child.duplicate()
			_drop_made(helper, child)
			output.add_child(helper)
	var props := source.get_node_or_null("Props") as GridMap
	if props:
		# the coarser version of the tram cars (from this far off the same), one copy of each
		# car for both lines
		var library := props.mesh_library
		var coarse := library.resource_path.replace(".res", "_lod.res")
		if ResourceLoader.exists(coarse):
			library = load(coarse)
		for track_index in TRAM_TRACKS_AHEAD.size():
			output.add_child(_make_tram(library, track_index))
		for holder in _make_columns(library):
			output.add_child(holder)
	print("materialen in de scène gezet: %d" % _own_materials(output))
	_set_owner(output, output)
	_save(output, MENU_MAP)
	source.queue_free()
	output.free()


## Which version of the town's tiles each layer uses in the menu (the suffix of its library:
## "_lod" = 25 cm .. the coarser "_lod2"; "" = the full tiles): from this far off the coarse
## ones look the same and weigh much less; the menu now shows the full tiles, as the town
## does up close.
const LAYER_DETAIL := {"Grond": "", "Gebouwen": "", "Details": "", "Props": ""}
const FIELD_DETAIL := ""


## Frees the children of `copy` whose originals (in `original`) are not saved with the scene.
static func _drop_made(copy: Node, original: Node) -> void:
	for original_child in original.get_children():
		if original_child.owner == null:
			var made := copy.get_node_or_null(NodePath(String(original_child.name)))
			if made:
				made.free()
## Where the small libraries of the menu's map go.
const MENU_LIBRARIES := "res://assets/libraries/menu/"


## A GridMap called `grid_name` with the cells of `layers` ([GridMap, library suffix] each),
## on a library of its own (MENU_LIBRARIES) with only the tiles those cells use, taken from
## the suffix's version of their library; the meshes and materials are copies, so the map
## shares nothing with the town (sharing the town's libraries crashed Godot).
func _own_grid(grid_name: String, layers: Array) -> GridMap:
	var first: GridMap = layers[0][0]
	var grid := GridMap.new()
	grid.name = grid_name
	grid.cell_size = first.cell_size
	grid.cell_center_x = first.cell_center_x
	grid.cell_center_y = first.cell_center_y
	grid.cell_center_z = first.cell_center_z
	grid.cell_octant_size = first.cell_octant_size
	grid.transform = first.transform
	grid.collision_layer = 0
	grid.collision_mask = 0
	var library := MeshLibrary.new()
	var new_ids := {}   # "suffix|old id" -> new id
	var materials := {}
	for layer: Array in layers:
		var source_grid: GridMap = layer[0]
		var suffix: String = layer[1]
		var source_library := source_grid.mesh_library
		if suffix != "":
			var coarse := source_library.resource_path.replace(".res", suffix + ".res")
			if ResourceLoader.exists(coarse):
				source_library = load(coarse)
		for cell in source_grid.get_used_cells():
			var old_id := source_grid.get_cell_item(cell)
			var key := "%s|%d" % [suffix, old_id]
			if not new_ids.has(key):
				var new_id := new_ids.size()
				new_ids[key] = new_id
				library.create_item(new_id)
				library.set_item_name(new_id, source_library.get_item_name(old_id) + suffix)
				var mesh := source_library.get_item_mesh(old_id)
				if mesh:
					var copy := mesh.duplicate() as Mesh
					# its shadow mesh is the library's too: a copy of its own (or none)
					if copy is ArrayMesh and (copy as ArrayMesh).shadow_mesh:
						(copy as ArrayMesh).shadow_mesh = (copy as ArrayMesh).shadow_mesh.duplicate()
					for surface in copy.get_surface_count():
						var material := copy.surface_get_material(surface)
						if material:
							if not materials.has(material):
								materials[material] = _menu_material(_own_material(material))
							copy.surface_set_material(surface, materials[material])
					library.set_item_mesh(new_id, copy)
				library.set_item_mesh_transform(new_id, source_library.get_item_mesh_transform(old_id))
				for meta_name in source_library.get_meta_list():
					library.set_meta(meta_name, source_library.get_meta(meta_name))
			grid.set_cell_item(cell, new_ids[key], source_grid.get_cell_item_orientation(cell))
	DirAccess.make_dir_recursive_absolute(MENU_LIBRARIES)
	var path := MENU_LIBRARIES + grid_name.to_lower() + ".res"
	ResourceSaver.save(library, path, ResourceSaver.FLAG_COMPRESS)
	grid.mesh_library = load(path)
	print("%s: %d tiles in %s" % [grid_name, new_ids.size(), path])
	return grid


## A copy of `material` whose textures are copies too, but shared: every material that uses
## the same texture of a library gets the same copy (a deep copy per material gave each its
## own copy of the big palette textures, megabytes each).
var _texture_copies := {}


func _own_material(material: Material) -> Material:
	var copy := material.duplicate()
	if copy is ShaderMaterial:
		var shader_material := copy as ShaderMaterial
		for uniform: Dictionary in shader_material.shader.get_shader_uniform_list() if shader_material.shader else []:
			var value: Variant = shader_material.get_shader_parameter(uniform.name)
			if value is Texture2D:
				shader_material.set_shader_parameter(uniform.name, _own_texture(value))
	elif copy is BaseMaterial3D:
		for property in ["albedo_texture", "emission_texture", "normal_texture", "roughness_texture", "metallic_texture"]:
			var texture: Variant = copy.get(property)
			if texture is Texture2D:
				copy.set(property, _own_texture(texture))
	return copy


func _own_texture(texture: Texture2D) -> Texture2D:
	if texture.resource_path != "" and not texture.resource_path.contains("::"):
		return texture   # a file of its own: referred to, not copied
	if not _texture_copies.has(texture):
		_texture_copies[texture] = texture.duplicate(true)
	return _texture_copies[texture]


## The menu's own settings on a copied material: the water waves, glitters and reflects more
## (MENU_WATER).
func _menu_material(material: Material) -> Material:
	var shader_material := material as ShaderMaterial
	if shader_material and shader_material.shader and shader_material.shader.resource_path.ends_with("voxel_water.gdshader"):
		for parameter: String in MENU_WATER:
			shader_material.set_shader_parameter(parameter, MENU_WATER[parameter])
	return material


## A tram and its track (TRAM_TRACKS_AHEAD[track_index] metres ahead of the camera): a
## Node3D "Tramlijn<n>" with the tram "Tram" (the cars: copies of the library meshes, so the
## map needs no library; metadata "z": the line it rides along, east-west) and the two
## rails along the whole strip.
var _car_meshes := {}   # props item -> its mesh copy, shared by the trams and the columns

## Columns that come by now and then on the grass behind the water (the menu drives them,
## scripts/ui/main_menu.gd): holders with vehicles to copy from (body, wheels, blue lights;
## hidden) and metadata "z" (the line they drive along, COLUMN_TRACK_AHEAD metres ahead of
## the camera): "Trekkers", angry farmers with their tractors on the way to the Malieveld,
## "Politie", a police car and the ME's vans, and "Hulpdiensten", ambulances and fire
## engines. Per vehicle: [name, props item, lift,
## wheels ([props item, position] each), blue lights (positions)], after the vehicle scripts.
const COLUMN_TRACK_AHEAD := 76.0
const TRACTOR_WHEELS := [
	["voertuigen/auto_wiel", Vector3(-0.5625, 0.375, 1.25)], ["voertuigen/auto_wiel", Vector3(0.5625, 0.375, 1.25)],
	["voertuigen/tractor_wiel", Vector3(-0.75, 0.625, -0.875)], ["voertuigen/tractor_wiel", Vector3(0.75, 0.625, -0.875)]]
const CAR_WHEELS := [
	["voertuigen/auto_wiel", Vector3(-0.75, 0.375, 1.3125)], ["voertuigen/auto_wiel", Vector3(0.75, 0.375, 1.3125)],
	["voertuigen/auto_wiel", Vector3(-0.75, 0.375, -1.25)], ["voertuigen/auto_wiel", Vector3(0.75, 0.375, -1.25)]]
const VAN_WHEELS := [
	["voertuigen/auto_wiel", Vector3(-0.875, 0.375, 1.5)], ["voertuigen/auto_wiel", Vector3(0.875, 0.375, 1.5)],
	["voertuigen/auto_wiel", Vector3(-0.875, 0.375, -1.375)], ["voertuigen/auto_wiel", Vector3(0.875, 0.375, -1.375)]]
const TRUCK_WHEELS := [
	["voertuigen/auto_wiel_groot", Vector3(-0.9375, 0.5, 2.375)], ["voertuigen/auto_wiel_groot", Vector3(0.9375, 0.5, 2.375)],
	["voertuigen/auto_wiel_groot", Vector3(-0.9375, 0.5, -2.0)], ["voertuigen/auto_wiel_groot", Vector3(0.9375, 0.5, -2.0)]]
const COLUMNS := {
	"Trekkers": [
		["trekker", "voertuigen/trekker", 0.25, TRACTOR_WHEELS, []],
		["trekker_rood", "voertuigen/trekker_rood", 0.25, TRACTOR_WHEELS, []]],
	"Politie": [
		["politie", "voertuigen/auto_politie", 0.125, CAR_WHEELS, [Vector3(-0.375, 1.4375, 0.0), Vector3(0.375, 1.4375, 0.0)]],
		["me_busje", "voertuigen/auto_politie_busje", 0.125, VAN_WHEELS, [Vector3(-0.4375, 2.1875, 1.3125), Vector3(0.4375, 2.1875, 1.3125)]]],
	"Hulpdiensten": [
		["ambulance", "voertuigen/auto_ambulance", 0.125, VAN_WHEELS, [Vector3(-0.4375, 2.1875, 1.3125), Vector3(0.4375, 2.1875, 1.3125)]],
		["brandweer", "voertuigen/auto_brandweer", 0.25, TRUCK_WHEELS, [Vector3(-0.4375, 2.8125, 2.9375), Vector3(0.4375, 2.8125, 2.9375)]]],
}
const BEACON_SIZE := Vector3(0.5, 0.15, 0.3)
const BEACON_COLOUR := Color(0.15, 0.4, 1.0)


func _make_columns(library: MeshLibrary) -> Array[Node3D]:
	var holders: Array[Node3D] = []
	for holder_name: String in COLUMNS:
		var holder := Node3D.new()
		holder.name = holder_name
		holder.set_meta("z", CAMERA_AT.z + COLUMN_TRACK_AHEAD)
		for vehicle: Array in COLUMNS[holder_name]:
			var made := _make_vehicle(library, vehicle)
			if made:
				holder.add_child(made)
		holders.append(holder)
	return holders


## One vehicle to copy from: its body lifted, its wheels, and its blue lights (boxes named
## "Zwaailicht", glowing blue; the menu flashes them), hidden.
func _make_vehicle(library: MeshLibrary, vehicle: Array) -> Node3D:
	var item := library.find_item_by_name(vehicle[1])
	if item < 0:
		push_warning("build_menu_map: no %s in the props library" % vehicle[1])
		return null
	var holder := Node3D.new()
	holder.name = vehicle[0]
	holder.visible = false
	var body := MeshInstance3D.new()
	body.name = "Carrosserie"
	body.mesh = _shared_mesh(library, item)
	body.transform = Transform3D(Basis.IDENTITY, Vector3(0, vehicle[2], 0)) * library.get_item_mesh_transform(item)
	holder.add_child(body)
	for wheel: Array in vehicle[3]:
		var wheel_item := library.find_item_by_name(wheel[0])
		if wheel_item < 0:
			continue
		var mesh_transform := library.get_item_mesh_transform(wheel_item)
		var middle := (mesh_transform * library.get_item_mesh(wheel_item).get_aabb()).get_center()
		var wheel_instance := MeshInstance3D.new()
		wheel_instance.name = "Wiel"
		wheel_instance.mesh = _shared_mesh(library, wheel_item)
		wheel_instance.transform = Transform3D(mesh_transform.basis, mesh_transform.origin - middle + wheel[1])
		holder.add_child(wheel_instance)
	for beacon_at: Vector3 in vehicle[4]:
		var beacon := MeshInstance3D.new()
		beacon.name = "Zwaailicht"
		var box := BoxMesh.new()
		box.size = BEACON_SIZE * Vector3(0.5, 1, 1)
		var glow := StandardMaterial3D.new()
		glow.albedo_color = BEACON_COLOUR
		glow.emission_enabled = true
		glow.emission = BEACON_COLOUR
		glow.emission_energy_multiplier = 4.0
		box.material = glow
		beacon.mesh = box
		beacon.position = beacon_at
		holder.add_child(beacon)
		# its blue light on the surroundings, as the town's emergency vehicles have
		var glow_light := OmniLight3D.new()
		glow_light.name = "Zwaailichtgloed"
		glow_light.light_color = BEACON_COLOUR
		glow_light.light_energy = 3.0
		glow_light.omni_range = 14.0
		glow_light.position = beacon_at + Vector3(0, 0.3, 0)
		holder.add_child(glow_light)
	return holder


func _shared_mesh(library: MeshLibrary, item: int) -> Mesh:
	if not _car_meshes.has(item):
		_car_meshes[item] = library.get_item_mesh(item).duplicate()
	return _car_meshes[item]


func _make_tram(library: MeshLibrary, track_index: int) -> Node3D:
	var strip_width := (STRIP_LAST_COLUMN - STRIP_FIRST_COLUMN + 1) * 4.0
	var middle := Vector3(STRIP_FIRST_COLUMN * 4.0 + strip_width * 0.5, 0.0, CAMERA_AT.z + TRAM_TRACKS_AHEAD[track_index])
	var holder := Node3D.new()
	holder.name = "Tramlijn%d" % (track_index + 1)
	var tram := Node3D.new()
	tram.name = "Tram"
	tram.set_meta("z", middle.z)
	tram.visible = false
	holder.add_child(tram)
	var count := TRAM_CARS.size()
	for car_index in count:
		var item := library.find_item_by_name(TRAM_CARS[car_index])
		if item < 0:
			push_warning("build_menu_map: no %s in the props library" % TRAM_CARS[car_index])
			continue
		var car := MeshInstance3D.new()
		car.name = "Wagen%d" % (car_index + 1)
		if not _car_meshes.has(item):
			_car_meshes[item] = library.get_item_mesh(item).duplicate()
		car.mesh = _car_meshes[item]
		# the train along its +Z: the first car in front, the last turned round
		var along := (float(count - 1) * 0.5 - car_index) * (TRAM_CAR_LENGTH + TRAM_CAR_GAP)
		var turn := Basis.IDENTITY if car_index < count - 1 else Basis(Vector3.UP, PI)
		car.transform = Transform3D(turn, Vector3(0.0, 0.0, along)) * library.get_item_mesh_transform(item)
		tram.add_child(car)
	# its track: the town's tram tiles in the grass field (_grass_field), wired by the Bovenleiding
	return holder


## Puts a copy of every material that lives in a tile library into the scene itself, so
## loading the map does not load the libraries. Returns how many it copied.
func _own_materials(node: Node) -> int:
	var copies := {}
	for instance: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := instance.mesh as ArrayMesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface)
			if material == null or not material.resource_path.contains("::"):
				continue
			if not copies.has(material):
				copies[material] = _own_material(material)
			mesh.surface_set_material(surface, copies[material])
		var override := instance.material_override
		if override and override.resource_path.contains("::"):
			if not copies.has(override):
				copies[override] = _own_material(override)
			instance.material_override = copies[override]
	return copies.size()


func _set_owner(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_set_owner(child, owner_node)


func _save(root: Node, path: String) -> void:
	var packed := PackedScene.new()
	packed.pack(root)
	var flags := ResourceSaver.FLAG_COMPRESS if path.ends_with(".scn") else 0
	print("saved: %s (%d)" % [path, ResourceSaver.save(packed, path, flags)])
