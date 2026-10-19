extends SceneTree
## Builds scenes/wereld.tscn: a small Dutch town showcasing all tiles,
## and scenes/nieuwe_kaart.tscn: an empty map with the same setup.
## usage: Godot --headless --script tools/build_example_city.gd
##
## HOW IT WORKS
## Both scenes get the same root setup (_make_scene): environment, sun and fill light,
## camera, helper nodes (DetailNiveau, Dagcyclus, Rook, TintKaart) and four GridMaps,
## one per tile library. The town is then written cell by cell into those GridMaps and
## the scene is packed and saved. Placement is fully deterministic (no RNG; variation
## comes from the hash _r and round-robin counters), so the output is reproducible.
##
## COORDINATES AND ORIENTATION
## x = east, z = south, in ground tiles of 4 m unless a parameter says metres.
## Directions S/E/N/W name the side the front (facade, kerb, ...) of a tile faces;
## rotation 0 = "S", then E, N, W in quarter turns (DIR). Corner tiles take a two-letter
## key (front, right) from CORNER, e.g. "SE" = front south, right side east. Rotations
## may also be passed as an int (quarter turns).
##
## LAYERS (GridMap node, library, cell size, origin height, placement helper)
##   Grond     grond     4 x 1 x 4 m, centred, y 0      G(x, z, tile, rot, level)
##             ground tiles; level = height in 1 m steps (water -2, quay walls -1,
##             tunnels down to -6, ramps and bridge decks above 0)
##   Gebouwen  gebouwen  4 x 3 x 4 m, centred, y 0.375  B(x, storey, z, tile, rot)
##             building blocks; one cell per storey of 3 m
##   Details   details   0.5 m, corner-aligned, y 0.375 D(wx, wz, wy, tile, rot)
##             facade/roof details at a position in metres (wy above building base)
##   Props     props     0.5 m, corner-aligned, y 0.25  Pr(wx, wz, tile, rot, wy)
##             street furniture, trees, vehicles at a position in metres
## A ground cell (x, z) spans metres x*4 .. x*4+4; its centre is x*4 + 2.
##
## MAP LAYOUT (W = 96 tiles wide)
##   z  0..29  old town (x 0..35): canal x 8-9, Main Street z 12..17, Cross Street
##             x 28-29, railway viaduct x 33-34, park, city block, square (_build_town)
##   z  0..39  expansion x 36..95: churches, museums, 1930s district, high-rise, pools
##   z 40..98  full width: South Road, river z 49..53, 1960s district, farm, southeast,
##             motorway z 72..79 with tunnels and a junction (x 34..58), campus and
##             shopping street z 80..98
##   z 99..    demo districts (_demo_districts): every tile in context, as city blocks
##             on a street grid joined to the campus road by two streets
## Cells not filled by z < H become grass (_fill_grass); around everything lies a polder
## POLDER tiles wide (_polder).
##
## DEMO DISTRICTS
## _district claims rectangles left to right in rows (wrapping at the map width), each
## with a kerb, and records {name, x, z, w, d} (in tiles) in the "districts" metadata of
## the Wereld root. When a row is complete (_finish_row) it gets 2-lane streets around
## and between its districts (shared with the neighbours), city blocks (_filler_block)
## fill the space under shallower districts and at the end of the row, and buildings
## line the streets wherever a district leaves its edge free (_line_streets). The streets
## are dressed with every road marking (_dress_streets: stop lines, give-way teeth, zebra
## crossings, arrows, cycle lanes, one-way streets with parking, a tram street, two
## signalised intersections), divided avenues with roundabouts join the campus road
## (_connect_to_town) and every pavement takes the kerb shape of its corner (_auto_kerbs).
## There is one district per building style found in the buildings library
## ("stijl:<style>", the second row of buildings along a woonerf), one per roof material
## ("dak:<kind>"), and fixed situations (sports complex, residential loops, tint street,
## canal ring, river dike, tunnels, flyovers, nature park, ...). Every tile of the
## libraries must stand somewhere in the town: the build warns about any that doesn't.
## The "catalog_start_m" metadata is the z in metres just below the demo districts.

const Common = preload("res://tools/tool_common.gd")
const LIB := "res://assets/libraries/%s.res"
const SlopesLib = preload("res://addons/vox_tiles/slopes.gd")
const VoxLib = preload("res://addons/vox_tiles/vox_parser.gd")
## direction the front of a tile faces -> quarter turns
const DIR := {"S": 0, "E": 1, "N": 2, "W": 3}
## (front, right) -> rotation, for corner pieces with something on the front and right side
const CORNER := {"SE": 0, "EN": 1, "NW": 2, "WS": 3}

# the four layers of the scene being built (see header)
var ground: GridMap
var buildings: GridMap
var details: GridMap
var props: GridMap
var orient := []    # quarter turns 0..3 -> GridMap orthogonal index
var occupied := {}  # ground cells (x,z) at level 0 that are already filled
var missing := {}   # tile names that are not in their library (reported at the end)
var tint_map: Node3D  # TintKaart node of the scene being built
var catalog_start := 0.0  # metres, see _expansion
var _taken := {}    # cells (x,z) holding something other than plain grass or pavement (any layer)


## Entry point: builds and saves both scenes, then quits. Prints tiles that are
## referenced but missing from the libraries.
func _init() -> void:
	Common.watchdog(self)
	var world := _make_scene("Wereld")
	_build_town()
	_own_tints(world)
	world.set_meta("catalog_start_m", catalog_start)
	world.set_meta("districts", districts)
	world.set_meta("places", places)
	_save(world, "res://scenes/wereld.tscn")
	var empty := _make_scene("NieuweKaart")
	_own_tints(empty)
	_save(empty, "res://scenes/nieuwe_kaart.tscn")
	if missing.size() > 0:
		print("MISSING TILES: ", missing.keys())
	quit()


# ------------------------------------------------------------------ scene

## Creates a GridMap for one tile library. cell = cell size in metres; center_xz =
## centre tiles in their cell on x/z (ground and buildings) or align them to the cell
## corner (0.5 m detail/prop grids); y = height offset of the whole layer in metres.
func _gridmap(node_name: String, lib: String, cell: Vector3, center_xz: bool, y: float) -> GridMap:
	var gm := GridMap.new()
	gm.name = node_name
	gm.mesh_library = load(LIB % lib)
	gm.cell_size = cell
	gm.cell_center_x = center_xz
	gm.cell_center_z = center_xz
	gm.cell_center_y = false
	gm.position.y = y
	gm.cell_octant_size = 4
	return gm


## Creates the scene root with environment, lights, camera, helper nodes and the four
## GridMap layers (stored in ground/buildings/details/props), and resets the per-scene
## state (orientation table, occupied cells). "Wereld" also gets the tour and tint examples.
func _make_scene(node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	var env := WorldEnvironment.new()
	env.name = "Omgeving"
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.3, 0.5, 0.85)
	sm.sky_horizon_color = Color(0.7, 0.8, 0.92)
	# the camera looks down: outside the map you see the "ground" of the sky,
	# so it gets sky colours
	sm.ground_horizon_color = Color(0.7, 0.8, 0.92)
	sm.ground_bottom_color = Color(0.55, 0.66, 0.82)
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.8
	e.ambient_light_sky_contribution = 0.9
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.05
	e.tonemap_white = 6.0
	e.ssao_enabled = true
	e.ssao_radius = 1.6
	e.ssao_intensity = 2.2
	e.ssao_power = 1.6
	e.ssao_detail = 0.8
	e.ssao_light_affect = 0.15
	e.ssil_enabled = false
	e.ssil_radius = 6.0
	e.ssil_intensity = 0.9
	# soft glow around lamps (emit material, energy 6) and bright highlights;
	# Godot's default glow levels
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.glow_hdr_threshold = 1.2
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.12
	e.adjustment_contrast = 1.1
	e.fog_enabled = false
	e.fog_light_color = Color(0.7, 0.78, 0.88)
	e.fog_density = 0.0005
	env.environment = e
	# motion blur when the camera moves
	var comp := Compositor.new()
	comp.compositor_effects = [load("res://scripts/effects/motion_blur.gd").new()]
	env.compositor = comp
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "Zon"
	# sun from south-southeast: in the isometric view (looking northwest)
	# both the south and east facades get light, with clear shadows.
	sun.rotation_degrees = Vector3(-62, 27, 0)
	sun.light_energy = 1.55
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.82
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 0.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 500.0
	root.add_child(sun)
	# soft fill light from the other side (without shadows), so shadow sides don't turn black
	var fill := DirectionalLight3D.new()
	fill.name = "Vullicht"
	fill.rotation_degrees = Vector3(-35, 200, 0)
	fill.light_energy = 0.22
	fill.light_color = Color(0.62, 0.74, 1.0)
	fill.shadow_enabled = false
	root.add_child(fill)
	ground = _gridmap("Grond", "grond", Vector3(4, 1, 4), true, 0.0)
	buildings = _gridmap("Gebouwen", "gebouwen", Vector3(4, 3, 4), true, 0.375)
	details = _gridmap("Details", "details", Vector3(0.5, 0.5, 0.5), false, 0.375)
	props = _gridmap("Props", "props", Vector3(0.5, 0.5, 0.5), false, 0.25)
	for gm in [ground, buildings, details, props]:
		root.add_child(gm)
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.set_script(load("res://scripts/free_camera.gd"))
	# isometric camera, aimed at the centre of the old town
	var focus := Vector3(72, 0, 60)
	var Iso = load("res://scripts/iso_camera.gd")
	cam.position = Iso.position(focus, 140.0)
	cam.rotation_degrees = Iso.ROTATION
	cam.fov = Iso.FOV
	cam.near = 2.0
	cam.far = 6000.0
	# depth of field (tilt-shift): sharp around the focus point, blurred in front and behind;
	# DetailNiveau scales the distances along with the zoom
	var attr := CameraAttributesPractical.new()
	attr.dof_blur_far_enabled = true
	attr.dof_blur_far_distance = 330.0
	attr.dof_blur_far_transition = 140.0
	attr.dof_blur_near_enabled = true
	attr.dof_blur_near_distance = 250.0
	attr.dof_blur_near_transition = 110.0
	attr.dof_blur_amount = 0.1
	cam.attributes = attr
	root.add_child(cam)
	if node_name == "Wereld":
		var rl := Node.new()
		rl.name = "Rondleiding"
		rl.set_script(load("res://scripts/tour.gd"))
		root.add_child(rl)
	var dn := Node.new()
	dn.name = "DetailNiveau"
	dn.set_script(load("res://scripts/level_of_detail.gd"))
	root.add_child(dn)
	var dc := Node.new()
	dc.name = "Dagcyclus"
	dc.set_script(load("res://scripts/day_cycle.gd"))
	root.add_child(dc)
	var smoke := Node3D.new()
	smoke.name = "Rook"
	smoke.set_script(load("res://scripts/smoke.gd"))
	root.add_child(smoke)
	var tk := Node3D.new()
	tk.name = "TintKaart"
	tk.set_script(load("res://scripts/tint_map.gd"))
	root.add_child(tk)
	tint_map = tk
	if node_name == "Wereld":
		# example: give two buildings in the city block a different tint
		for v in [[Vector3(18 * 4 + 2, 0, 11 * 4 + 2), Color(1.0, 0.8, 0.65), Vector2i(2, 1)],
				[Vector3(24 * 4 + 2, 0, 2 * 4 + 2), Color(0.8, 0.85, 1.0), Vector2i(1, 1)],
				[Vector3(37 * 4 + 2, 0, 31 * 4 + 2), Color(1.1, 1.0, 0.8), Vector2i(3, 2)]]:
			var tv := Node3D.new()
			tv.name = "TintVlak"
			tv.set_script(load("res://scripts/tint_area.gd"))
			tv.position = v[0]
			tv.set("color", v[1])
			tv.set("size", v[2])
			tk.add_child(tv)
	for n in root.get_children():
		n.owner = root
	orient.clear()
	for k in 4:
		orient.append(ground.get_orthogonal_index_from_basis(Basis(Vector3.UP, k * PI / 2.0)))
	occupied.clear()
	return root


## Sets the owner of all tint areas (added after _make_scene) so they are saved.
func _own_tints(root: Node3D) -> void:
	for tv in tint_map.get_children():
		tv.owner = root


## Packs root into a PackedScene, saves it to scene_path and frees the tree.
func _save(root: Node3D, scene_path: String) -> void:
	var ps := PackedScene.new()
	ps.pack(root)
	var err := ResourceSaver.save(ps, scene_path)
	print("saved: ", scene_path, " (", err, ")")
	root.free()


## Library item id of tile_name in gm, or -1 (then recorded in `missing`).
func _id(gm: GridMap, tile_name: String) -> int:
	var id: int = gm.mesh_library.find_item_by_name(tile_name)
	if id < 0:
		missing[tile_name] = true
	return id


## GridMap orthogonal index for a rotation: a direction ("S", "E", "N", "W"), a
## corner key ("SE", "EN", "NW", "WS") or a number of quarter turns.
func _rot(r) -> int:
	if r is String:
		if DIR.has(r):
			return orient[DIR[r]]
		return orient[CORNER[r]]
	return orient[int(r) % 4]


## Ground tile at tile (x, z) on level y (1 m steps; 0 = street level).
## Marks (x, z) as occupied when placed on level 0.
func G(x: int, z: int, tile_name: String, r = "S", y := 0) -> void:
	var id := _id(ground, tile_name)
	if id >= 0:
		ground.set_cell_item(Vector3i(x, y, z), id, _rot(r))
	if y == 0:
		occupied[Vector2i(x, z)] = true
	if tile_name != "natuur/gras" and not tile_name.begins_with("stoep/"):
		_taken[Vector2i(x, z)] = true


## Building block at tile (x, z) on storey y (3 m per storey). Marks (x, z) as occupied.
func B(x: int, y: int, z: int, tile_name: String, r = "S") -> void:
	var id := _id(buildings, tile_name)
	if id >= 0:
		buildings.set_cell_item(Vector3i(x, y, z), id, _rot(r))
	occupied[Vector2i(x, z)] = true
	_taken[Vector2i(x, z)] = true


## Prop at world position (wx, wz) in metres; wy = height in metres above street level.
## Snapped to the 0.5 m prop grid.
func Pr(wx: float, wz: float, tile_name: String, r = "S", wy := 0.0) -> void:
	var id := _id(props, tile_name)
	if id >= 0:
		props.set_cell_item(Vector3i(roundi(wx * 2), roundi(wy * 2), roundi(wz * 2)), id, _rot(r))
	_taken[Vector2i(floori(wx / 4.0), floori(wz / 4.0))] = true


## Detail at world position (wx, wz) in metres; wy = height in metres above the building
## base. Snapped to the 0.5 m detail grid.
func D(wx: float, wz: float, wy: float, tile_name: String, r = "S") -> void:
	var id := _id(details, tile_name)
	if id >= 0:
		details.set_cell_item(Vector3i(roundi(wx * 2), roundi(wy * 2), roundi(wz * 2)), id, _rot(r))
	_taken[Vector2i(floori(wx / 4.0), floori(wz / 4.0))] = true


## Ground tiles along x from x0 to x1 (inclusive) at row z.
func row(x0: int, x1: int, z: int, tile_name: String, r = "S", y := 0) -> void:
	for x in range(x0, x1 + 1):
		G(x, z, tile_name, r, y)


## Ground tiles along z from z0 to z1 (inclusive) at column x.
func column(x: int, z0: int, z1: int, tile_name: String, r = "S", y := 0) -> void:
	for z in range(z0, z1 + 1):
		G(x, z, tile_name, r, y)


# ------------------------------------------------------------------ the town

const W := 96  # map width in tiles
const H := 80  # depth of the main map in tiles (filled with grass by _fill_grass)
const OLD_H := 30  # the original town


## Builds the whole map: the old town (z 0..29), the expansion and demo districts
## (via _expansion) and finally grass on every cell that is still empty.
func _build_town() -> void:
	_canal()
	_main_street()
	_north_street_and_cross_street()
	_canal_houses()
	_city_block()
	_square()
	_modern_block()
	_office()
	_modern_east()
	_railway()
	_park()
	_expansion()
	_fill_grass()


## Canal x 8-9 from z 0 to 48: water and quay walls below street level, quays,
## quay streets and pavements, a flat bridge in North Street, a brick arch bridge in
## Main Street, trees, lanterns, bollards and boats.
func _canal() -> void:
	# canal: water at level -2, quay walls at -2 and -1 below the quays
	for z in range(0, 49):
		occupied[Vector2i(8, z)] = true
		occupied[Vector2i(9, z)] = true
		for x in [8, 9]:
			if z >= 12 and z <= 17:
				continue
			if z == 0:
				continue
			G(x, z, "water/water_gracht", "S", -2)
		for x in [7, 10]:
			G(x, z, "water/kademuur_alg", "S", -2)
			G(x, z, "water/kademuur", "S", -1)
	# bridge in North Street: concrete bridge deck with parapets on both sides
	G(8, 0, "water/water_gracht", "S", -2)
	G(9, 0, "water/water_gracht", "S", -2)
	G(8, 0, "brug/brug_dek_weg_beide", "E")
	G(9, 0, "brug/brug_dek_weg_beide", "E")
	# brick arch bridge in Main Street (placed at water level)
	for x in [8, 9]:
		G(x, 12, "brug/brug_boog_gracht_rand", 3, -2)
		for z in range(13, 17):
			G(x, z, "brug/brug_boog_gracht_midden", 1, -2)
		G(x, 17, "brug/brug_boog_gracht_rand", 1, -2)
		for z in range(12, 18):
			occupied[Vector2i(x, z)] = true
	# quays
	for z in range(1, 49):
		if z >= 12 and z <= 17:
			continue
		G(7, z, "stoep/stoep_kade_klinker" if z % 5 == 0 else "stoep/stoep_kade", "E")
		G(10, z, "stoep/stoep_kade_klinker" if z % 5 == 0 else "stoep/stoep_kade", "W")
	# quay streets (clinkers) and pavements along the buildings
	for z in range(1, 49):
		if z >= 12 and z <= 17:
			continue
		G(6, z, "weg/straat_klinkers")
		G(11, z, "weg/straat_klinkers")
		G(5, z, "stoep/stoep_rand", "E")
		G(12, z, "stoep/stoep_rand", "W")
	# trees, lanterns, bollards and bicycles along the canal
	for z in range(1, 49):
		if (z >= 11 and z <= 18) or (z >= 39 and z <= 47):
			continue
		var wz := z * 4.0 + 2.0
		if z % 2 == 0:
			Pr(7 * 4 + 1.5, wz, "bomen/linde")
			Pr(10 * 4 + 2.5, wz, "bomen/linde" if z % 4 else "bomen/plataan")
		else:
			Pr(7 * 4 + 1.0, wz, "verlichting/lantaarn_klassiek")
			Pr(10 * 4 + 3.0, wz, "verlichting/lantaarn_klassiek")
		Pr(7 * 4 + 3.5, wz - 1.0, "paaltjes/bolder")
		Pr(10 * 4 + 0.5, wz + 1.0, "paaltjes/bolder")
		if z % 3 == 0:
			Pr(5 * 4 + 0.5, wz, "paaltjes/amsterdammertje")
			Pr(5 * 4 + 0.5, wz + 1, "paaltjes/amsterdammertje")
			Pr(12 * 4 + 3.5, wz, "paaltjes/amsterdammertje")
		if z % 4 == 1:
			Pr(7 * 4 + 2.5, wz + 0.5, "fietsen/fiets_zwart", "E")
			Pr(7 * 4 + 2.5, wz + 1.0, "fietsen/fiets_rood", "E")
	# boats
	Pr(36.0, 14.0, "water/woonboot", "S", -2.0)
	Pr(36.0, 30.0, "water/sloep", "N", -2.0)
	Pr(35.0, 40.0, "water/roeiboot", "S", -2.0)
	Pr(36.0, 96.0, "water/woonboot", "N", -2.0)
	Pr(36.5, 108.0, "water/roeiboot", "E", -2.0)
	Pr(34.0, 84.0, "water/steiger", "S", -2.0)


## Main Street along x at z 12..17 (pavement, cycle path, two lanes, cycle path,
## pavement) with a tram section, the intersection with Cross Street, a tram/bus stop,
## lanterns, signs and traffic lights.
func _main_street() -> void:
	# profile (z): 12 pavement, 13 cycle path, 14-15 lanes, 16 cycle path, 17 pavement
	for x in range(0, W):
		if x == 8 or x == 9:
			continue
		if x == 28 or x == 29 or x == 60 or x == 61:
			continue # intersections with Cross Street and Cross Street 2
		if x == 6 or x == 11:
			G(x, 12, "weg/weg_vlak")
			G(x, 17, "weg/weg_vlak")
		elif x == 5 or x == 12:
			G(x, 12, "stoep/stoep_hoek_buiten", "SE" if x == 5 else "WS")
			G(x, 17, "stoep/stoep_hoek_buiten", "EN" if x == 5 else "NW")
		elif x == 27 or x == 59:
			G(x, 12, "stoep/stoep_hoek_buiten", "SE")
			G(x, 17, "stoep/stoep_hoek_buiten", "EN")
		elif x == 30 or x == 62:
			G(x, 12, "stoep/stoep_hoek_buiten", "WS")
			G(x, 17, "stoep/stoep_hoek_buiten", "NW")
		else:
			# a gully every 7 tiles
			var pavement := "stoep/stoep_goot_rand" if x % 7 != 3 else "stoep/stoep_goot_kolk"
			G(x, 12, pavement, "S")
			G(x, 17, pavement, "N")
		G(x, 13, "fietspad/fietspad_recht", "E")
		G(x, 16, "fietspad/fietspad_recht", "E")
		var tram := x >= 12 and x <= 35
		if tram and x >= 62:
			G(x, 14, "tram/tram_rijstrook_onderbroken_kant", "E")
			G(x, 15, "tram/tram_rijstrook_geen_kant", "W")
		elif tram:
			G(x, 14, "tram/tram_recht", "E")
			G(x, 15, "tram/tram_recht", "E")
		else:
			G(x, 14, "weg/rijstrook_onderbroken_kant", "E")
			G(x, 15, "weg/rijstrook_geen_kant", "W")
	# intersection with Cross Street
	for x in [28, 29]:
		G(x, 12, "weg/zebrapad", "S")
		G(x, 13, "weg/fietsoversteek", "S")
		G(x, 14, "weg/weg_vlak")
		G(x, 15, "weg/weg_vlak")
		G(x, 16, "weg/fietsoversteek", "S")
		G(x, 17, "weg/zebrapad", "S")
	# tram stop and street furniture
	Pr(20 * 4 + 2, 12 * 4 + 1.5, "ov/abri", "S")
	Pr(23 * 4, 12 * 4 + 1.0, "ov/tramhalte_paal", "S")
	Pr(18 * 4, 17 * 4 + 3.0, "ov/bushokje", "N")
	Pr(16 * 4, 17 * 4 + 3.5, "ov/bushalte_paal", "N")
	for x in range(0, W, 3):
		if x >= 7 and x <= 10:
			continue
		Pr(x * 4 + 2, 12 * 4 + 0.5, "verlichting/lantaarn_dubbel", "E")
		Pr(x * 4 + 2, 17 * 4 + 3.5, "verlichting/lantaarn_modern", "N")
	for x in [14, 24, 33]:
		Pr(x * 4 + 1, 12 * 4 + 3.0, "straat/prullenbak_paal")
		Pr(x * 4 + 3, 17 * 4 + 1.0, "fietsen/fietsenrek_vol", "N")
	Pr(13 * 4 + 1, 17 * 4 + 2, "borden/bord_max_50", "N")
	Pr(1 * 4, 12 * 4 + 2, "borden/bord_bebouwde_kom", "E")
	# traffic lights
	Pr(27 * 4 + 3, 12 * 4 + 3.5, "verkeer/verkeerslicht", "N")
	Pr(30 * 4 + 1, 17 * 4 + 0.5, "verkeer/verkeerslicht", "S")
	Pr(27 * 4 + 3.5, 17 * 4 + 0.5, "verkeer/verkeerslicht_fiets", "E")
	Pr(30 * 4 + 0.5, 12 * 4 + 3.5, "verkeer/verkeerslicht_voetganger", "W")
	Pr(30 * 4 + 2, 12 * 4 + 1, "verkeer/verkeerslicht_mast", "W")
	# signpost
	Pr(26 * 4 + 2, 17 * 4 + 2, "borden/wegwijzer", "N")


## North Street along the top edge (z 0, pavement z 1) and Cross Street (x 28-29,
## pavements x 27 and 30) from z 1 to 39, with zebra crossings, tree grates and signs.
func _north_street_and_cross_street() -> void:
	# North Street (z=0), pavement z=1
	for x in range(0, 33):
		if x == 8 or x == 9:
			continue
		if x == 28 or x == 29:
			G(x, 0, "weg/weg_vlak")
			continue
		G(x, 0, "weg/straat_klinkers" if x < 12 else "weg/weg_vlak", "E")
	G(30, 0, "weg/weg_vlak")
	G(31, 0, "weg/weg_vlak")
	G(32, 0, "weg/zebrapad", "E")
	for x in range(13, 28):
		if x == 27:
			G(x, 1, "stoep/stoep_hoek_buiten", "EN")
		elif x == 13:
			G(x, 1, "stoep/stoep_hoek_buiten", "NW")
		else:
			G(x, 1, "stoep/stoep_rand", "N")
	for x in range(0, 5):
		G(x, 1, "stoep/stoep_rand", "N")
	G(5, 1, "stoep/stoep_hoek_buiten", "EN")
	G(12, 1, "stoep/stoep_hoek_buiten", "NW")
	G(7, 0, "weg/straat_klinkers", "E")
	G(10, 0, "weg/straat_klinkers", "E")
	Pr(15 * 4, 1 * 4 + 1, "borden/bord_max_30", "N")
	Pr(25 * 4, 1 * 4 + 1, "borden/bord_woonerf", "N")
	Pr(4 * 4, 1 * 4 + 1, "borden/bord_eenrichtingsweg", "N")
	# Cross Street (x=28,29), pavements x=27 and x=30
	for z in range(1, 40):
		if z >= 12 and z <= 17:
			continue
		if z == 10 or z == 19:
			G(28, z, "weg/zebrapad")
			G(29, z, "weg/zebrapad")
		elif z == 11:
			G(28, z, "weg/rijstrook_haaientanden", "N")
			G(29, z, "weg/rijstrook_pijl_rechtdoor", "S")
		else:
			G(28, z, "weg/rijstrook_geen_kant", "N")
			G(29, z, "weg/rijstrook_onderbroken_kant", "S")
		if z == 1:
			G(30, z, "stoep/stoep_hoek_buiten", "NW")
		elif z == 10 or z == 19:
			G(27, z, "stoep/stoep_ribbel", "E")
			G(30, z, "stoep/stoep_ribbel", "W")
		elif z % 4 == 2:
			G(27, z, "stoep/stoep_boomrooster", "E")
			G(30, z, "stoep/stoep_boomrooster", "W")
			Pr(27 * 4 + 2, z * 4 + 2, "bomen/linde" if z < 12 else "bomen/kastanje")
			Pr(30 * 4 + 2, z * 4 + 2, "bomen/linde")
		else:
			if z != 1:
				G(27, z, "stoep/stoep_rand", "E")
			G(30, z, "stoep/stoep_rand", "W")
	Pr(30 * 4 + 1, 10 * 4 + 1, "borden/bord_zebrapad", "W")
	Pr(27 * 4 + 3, 19 * 4 + 3, "borden/bord_zebrapad", "E")
	Pr(27 * 4 + 3, 11 * 4, "borden/bord_voorrang_verlenen", "N")
	Pr(30 * 4 + 1, 22 * 4, "borden/bord_parkeren", "W")
	Pr(30 * 4 + 1, 26 * 4, "paaltjes/laadpaal", "W")
	Pr(27 * 4 + 3, 7 * 4, "straat/brievenbus", "E")


# ------------------------------------------------------------------ canal houses

## One narrow canal house at tile (x, z) facing front: a ground floor picked by rnd,
## floors - 1 upper storeys from facades and a gable top ("gevel_" + gable_top) on storey floors.
func _house(x: int, z: int, front: String, style: String, floors: int, facades: Array, gable_top: String, rnd: int) -> void:
	var p := style + "/" + style + "_"
	var gf: String = ["bg_deur", "bg_deur", "bg_winkel_luifel", "bg_raam", "bg_winkel"][rnd % 5]
	B(x, 0, z, p + gf, front)
	for v in range(1, floors):
		B(x, v, z, p + facades[(rnd + v) % facades.size()], front)
	B(x, floors, z, p + "gevel_" + gable_top, front)


## Rows of canal houses on both quays (front houses with rear houses behind them),
## back gardens on the west side and facade details.
func _canal_houses() -> void:
	var styles := ["klassiek_rood", "klassiek_donker", "klassiek_geel"]
	var tops := ["trap", "klok", "hals", "tuit"]
	var upper := ["verd_raam", "verd_drie_ramen", "verd_luiken", "verd_balkon", "verd_raam", "verd_erker"]
	# west: front facade facing east (x=4), rear house x=3
	for z in range(2, 12):
		var r := z * 7 + 3
		var style: String = styles[r % 3]
		var n := 3 + (r % 2)
		_house(4, z, "E", style, n, upper, tops[(z * 3) % 4], r)
		var p := style + "/" + style + "_"
		for v in range(0, n):
			B(3, v, z, p + ("verd_raam" if v > 0 else "bg_raam"), "W")
		B(3, n, z, p + ("dak_zadel_schoorsteen" if z % 3 == 0 else "dak_zadel"), "S")
		# small back gardens
		G(2, z, "natuur/gras_bloemen" if z % 2 else "natuur/gras")
		G(1, z, "natuur/moestuin" if z % 3 == 0 else "natuur/gras")
		G(0, z, "plein/plein_vlonder" if z % 4 == 0 else "natuur/gras")
		Pr(2 * 4 + 0.5, z * 4 + 2, "hekken/schutting_hout", "E")
		if z % 3 == 1:
			Pr(1 * 4 + 2, z * 4 + 2, "bomen/fruitboom")
	# east: front facade facing west (x=13), rear house x=14
	for zz in range(2, 12) + range(18, 29):
		var r: int = zz * 5 + 1
		var style: String = styles[(r + 1) % 3]
		var n := 3 + (1 if r % 3 == 0 else 0)
		_house(13, zz, "W", style, n, upper, tops[(zz * 5) % 4], r)
		var p := style + "/" + style + "_"
		for v in range(0, n):
			B(14, v, zz, p + ("verd_luiken" if v > 0 else "bg_raam"), "E")
		B(14, n, zz, p + "dak_zadel", "S")
		G(15, zz, "stoep/stoep_vol")
	# facade details: flower boxes, awnings, flags, ivy
	for z in range(2, 12):
		var wz := z * 4.0 + 1.0
		if z % 2 == 0:
			D(20.0, wz + 1.0, 3.5, "ramen/bloembak", "E")
		if z % 4 == 1:
			D(20.0, wz + 2.0, 6.0, "gevel/vlag", "E")
		if z % 5 == 3:
			D(52.0, z * 4.0 + 2.0, 0.0, "gevel/klimop", "W")
	D(52.0, 22.0, 3.0, "gevel/uithangbord", "W")
	D(20.0, 30.0, 2.5, "gevel/buitenlamp", "E")


# ------------------------------------------------------------------ city block with sloped roofs

## Closed city block x 16..26, z 2..11: a ring two cells deep with sloped roofs that
## wrap around the corners, shops on the south side, a gateway, and a courtyard garden.
func _city_block() -> void:
	# ring 2 deep: x 16..26, z 2..11; courtyard x 18..24, z 4..9
	var s := "klassiek_rood"
	var p := s + "/" + s + "_"
	var x0 := 16
	var x1 := 26
	var z0 := 2
	var z1 := 11
	var roof_variants := ["dak_schuin", "dak_schuin", "dak_schuin_dakkapel", "dak_schuin", "dak_schuin_schoorsteen", "dak_schuin_dakraam", "dak_schuin_zonnepanelen"]
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			var outer_ring := x == x0 or x == x1 or z == z0 or z == z1
			var inner_ring := x == x0 + 1 or x == x1 - 1 or z == z0 + 1 or z == z1 - 1
			if not outer_ring and not inner_ring:
				continue
			var k := (x * 13 + z * 7) % 7
			var front := ""
			var roof: String = roof_variants[k]
			var gf_tile := "bg_deur" if k % 2 == 0 else "bg_raam"
			var upper_tile: String = ["verd_raam", "verd_drie_ramen", "verd_luiken", "verd_balkon"][k % 4]
			if outer_ring:
				var corner := _corner_of(x, z, x0, z0, x1 - x0 + 1, z1 - z0 + 1)
				if corner != "":
					B(x, 0, z, p + ("bg_winkel_hoek" if z == z1 else "bg_raam_hoek"), corner)
					B(x, 1, z, p + "verd_raam_hoek", corner)
					B(x, 2, z, p + "dak_schuin_hoek_buiten", corner)
					continue
				if z == z0: front = "N"
				elif z == z1: front = "S"
				elif x == x0: front = "W"
				else: front = "E"
				if z == z1:
					gf_tile = "bg_winkel_luifel" if k % 3 != 1 else "bg_winkel"
				if z == z1 and x == 21:
					gf_tile = "bg_poort"
			else:
				# inner ring: facades face the courtyard
				var corner := ""
				if x == x0 + 1 and z == z0 + 1: corner = "SE"
				elif x == x1 - 1 and z == z0 + 1: corner = "WS"
				elif x == x0 + 1 and z == z1 - 1: corner = "EN"
				elif x == x1 - 1 and z == z1 - 1: corner = "NW"
				if corner != "":
					B(x, 0, z, p + "blok_dicht", "S")
					B(x, 1, z, p + "blok_dicht", "S")
					B(x, 2, z, p + "dak_schuin_hoek_binnen", corner)
					continue
				if z == z0 + 1: front = "S"
				elif z == z1 - 1: front = "N"
				elif x == x0 + 1: front = "E"
				else: front = "W"
				gf_tile = "bg_raam" if k % 2 else "bg_deur"
				if z == z1 - 1 and x == 21:
					gf_tile = "bg_poort"
				if roof == "dak_schuin_zonnepanelen" or roof == "dak_schuin_dakraam":
					roof = "dak_schuin_dakterras" if k % 2 else "dak_schuin_half_plat"
			B(x, 0, z, p + gf_tile, front)
			B(x, 1, z, p + upper_tile, front)
			B(x, 2, z, p + roof, front)
	# courtyard
	for x in range(x0 + 2, x1 - 1):
		for z in range(z0 + 2, z1 - 1):
			var t := "natuur/gras"
			if z == z0 + 2 or z == z1 - 2:
				t = "plein/plein_tegels"
			elif x == 21:
				t = "natuur/pad_grind"
			elif (x + z) % 5 == 0:
				t = "natuur/gras_bloemen"
			G(x, z, t)
	G(21, z1 - 2, "natuur/pad_grind")
	Pr(19 * 4 + 2, 6 * 4 + 2, "bomen/bloesemboom")
	Pr(24 * 4 + 2, 7 * 4 + 2, "bomen/linde")
	Pr(19 * 4 + 2, 8 * 4 + 2, "straat/picknicktafel", "E")
	Pr(23 * 4, 5 * 4 + 2, "planten/hortensia")
	Pr(20 * 4, 5 * 4 + 2, "hekken/haag", "S")
	Pr(22 * 4 + 2, 9 * 4, "hekken/haag", "S")
	Pr(18 * 4 + 2, 4 * 4 + 2, "fietsen/fietsenrek_vol", "E")
	Pr(24 * 4, 9 * 4, "straat/rolcontainer_groen")
	Pr(24.5 * 4, 9 * 4, "straat/rolcontainer_grijs")
	Pr(20 * 4, 7 * 4 + 2, "planten/plantenbak_hout")
	# awnings and details on the outside
	D(17 * 4 + 2.0, 12 * 4.0, 2.0, "luifels/luifel_groen_smal", "S")
	D(26 * 4 + 4.0, 6 * 4 + 2.0, 0.0, "gevel/klimop", "E")
	D(16 * 4.0, 7 * 4 + 2.0, 1.0, "gevel/regenpijp", "W")


# ------------------------------------------------------------------ square

## Town square x 16..26, z 18..25 with a natural-stone centre, fountain, kiosk, trees,
## benches and lanterns.
func _square() -> void:
	for x in range(16, 27):
		for z in range(18, 26):
			var t := "plein/plein_klinkers"
			if x >= 19 and x <= 23 and z >= 19 and z <= 23:
				t = "plein/plein_patroon" if (x == 21 and z == 21) else "plein/plein_natuursteen"
			elif (x == 17 or x == 25) and (z == 19 or z == 24):
				t = "stoep/stoep_boomrooster"
			G(x, z, t)
	G(16, 18, "plein/plein_dambord")
	Pr(21 * 4 + 2, 21 * 4 + 2, "straat/fontein")
	Pr(24 * 4 + 2, 21 * 4 + 2, "straat/kiosk")
	for pos in [Vector2(17, 19), Vector2(25, 19), Vector2(17, 24), Vector2(25, 24)]:
		Pr(pos.x * 4 + 2, pos.y * 4 + 2, "bomen/linde")
	for x in [19, 23]:
		Pr(x * 4 + 2, 19 * 4, "straat/bank_hout", "S")
		Pr(x * 4 + 2, 24 * 4 + 3, "straat/bank_hout", "N")
	Pr(19 * 4, 21 * 4 + 2, "straat/bank_beton", "E")
	Pr(18 * 4 + 2, 22 * 4, "verlichting/lantaarn_klassiek")
	Pr(24 * 4 + 2, 19 * 4, "verlichting/lantaarn_klassiek")
	Pr(20 * 4, 24 * 4, "verlichting/lantaarn_klassiek")
	Pr(22 * 4 + 2, 18 * 4 + 1, "straat/prullenbak_rond")
	Pr(16 * 4 + 2, 21 * 4, "ov/reclamezuil")
	Pr(26 * 4 + 1, 22 * 4, "straat/vlaggenmast")
	Pr(18 * 4, 25 * 4, "planten/plantenbak_beton")
	Pr(24 * 4, 25 * 4, "planten/plantenbak_beton")
	Pr(21 * 4 + 2, 25 * 4 + 1, "planten/pot_terracotta")
	Pr(17 * 4, 21 * 4, "straat/afvalcontainer_ondergronds")


# ------------------------------------------------------------------ modern blocks

## Modern terraced block south of the square (x 16..26, z 26..27, 3 storeys, flat roofs)
## with back gardens and roof equipment.
func _modern_block() -> void:
	# south side of the square: x 16..26, z 26..27
	var styles := ["modern_wit", "modern_hout", "modern_donker"]
	for x in range(16, 27):
		var s: String = styles[((x - 16) / 4) % 3]
		var p := s + "/" + s + "_"
		var k := x % 4
		for z in [26, 27]:
			var front := "N" if z == 26 else "S"
			var corner := _corner_of(x, z, 16, 26, 11, 2)
			for v in range(0, 3):
				var tile_name := ""
				if corner != "":
					tile_name = ["bg_raam_hoek", "verd_raam_hoek", "verd_balkon_hoek"][v]
					B(x, v, z, p + tile_name, corner)
				else:
					if v == 0:
						tile_name = ["bg_deur", "bg_raam", "bg_winkel", "bg_garage"][k] if z == 26 else ["bg_deur", "bg_raam", "bg_raam", "bg_garage"][k]
					else:
						tile_name = ["verd_raam", "verd_balkon", "verd_raam_breed", "verd_frans", "verd_dicht"][(k + v) % 5]
					B(x, v, z, p + tile_name, front)
			if corner != "":
				B(x, 3, z, p + "dak_plat_hoek", corner)
			else:
				var roof := "dak_plat_rand"
				if z == 27 and k == 1:
					roof = "dak_terras_rand"
				B(x, 3, z, p + roof, front)
	# back gardens
	for x in range(16, 27):
		G(x, 28, "natuur/gras" if x % 3 else "plein/plein_vlonder")
		G(x, 29, "natuur/gras")
		Pr(x * 4 + 2, 29 * 4 + 3.5, "hekken/schutting_hout", "S")
	for x in [17, 21, 25]:
		Pr(x * 4 + 2, 28 * 4 + 2, "planten/struik_bloei")
	# solar panels and dishes on the roofs (details layer, height = top of 3rd storey)
	for x in [18, 22, 24]:
		D(x * 4 + 2.0, 27 * 4 + 2.0, 9.0, "dak/zonnepanelen", "S")
	D(19 * 4 + 2.0, 26 * 4.0, 7.0, "gevel/airco", "N")
	D(23 * 4 + 2.0, 26 * 4.0, 4.0, "dak/schotel", "N")


## Glass office tower (x 31..32, z 18..20, 6 storeys) and a lower concrete office
## (z 22..23), with the pavements around them.
func _office() -> void:
	# office tower x 31..32, z 18..20, 6 storeys, front west
	var s := "kantoor_glas"
	var p := s + "/" + s + "_"
	var height := 6
	for x in [31, 32]:
		for z in [18, 19, 20]:
			var corner := _corner_of(x, z, 31, 18, 2, 3)
			var front := "W" if x == 31 else "E"
			for v in range(0, height):
				if corner != "":
					var n := "bg_glas_hoek" if v == 0 else ("verd_vliesgevel_hoek" if v % 2 else "verd_band_hoek")
					B(x, v, z, p + n, corner)
				else:
					var n := ("bg_entree" if x == 31 else "bg_glas") if v == 0 else ("verd_vliesgevel" if v % 2 else "verd_band")
					B(x, v, z, p + n, front)
			if corner != "":
				B(x, height, z, p + "dak_plat_hoek", corner)
			else:
				B(x, height, z, p + "dak_installatie_rand", front)
	# lower office (concrete) next to it
	var s2 := "kantoor_beton"
	var p2 := s2 + "/" + s2 + "_"
	for x in [31, 32]:
		for z in [22, 23]:
			# 2x2: every cell is a corner
			var corner := _corner_of(x, z, 31, 22, 2, 2)
			for v in range(0, 3):
				B(x, v, z, p2 + ("bg_glas_hoek" if v == 0 else "verd_band_hoek"), corner)
			B(x, 3, z, p2 + "dak_plat_hoek", corner)
	for z in [21, 24, 25]:
		G(31, z, "stoep/stoep_vol")
		G(32, z, "stoep/stoep_vol")
	Pr(31 * 4 + 2, 21 * 4 + 2, "planten/boombak")
	Pr(31 * 4 + 1, 24 * 4 + 2, "fietsen/fietsenrek_vol", "E")
	Pr(31 * 4 + 1, 19 * 4 + 2, "paaltjes/paal_rvs")
	Pr(30 * 4 + 3, 18 * 4 + 1, "paaltjes/paal_rvs")


## Modern terraced houses x 31..32, z 2..10 (3 storeys, flat roofs), fronts facing west and east.
func _modern_east() -> void:
	# modern terraced houses x 31..32, z 2..10, front west
	var s := "modern_donker"
	var p := s + "/" + s + "_"
	for z in range(2, 11):
		for x in [31, 32]:
			var corner := _corner_of(x, z, 31, 2, 2, 9)
			var front := "W" if x == 31 else "E"
			for v in range(0, 3):
				if corner != "":
					B(x, v, z, p + ["bg_deur_hoek", "verd_raam_hoek", "verd_raam_breed_hoek"][v], corner)
				else:
					var n: String = ["bg_deur", "bg_garage", "bg_deur", "bg_raam"][z % 4] if v == 0 else ["verd_raam", "verd_balkon", "verd_frans", "verd_raam_breed"][(z + v) % 4]
					B(x, v, z, p + n, front)
			if corner != "":
				B(x, 3, z, p + "dak_plat_hoek", corner)
			else:
				B(x, 3, z, p + "dak_plat_rand", front)
	G(31, 11, "natuur/gras")
	G(32, 11, "natuur/gras")
	Pr(31 * 4 + 2, 11 * 4 + 2, "planten/struik")
	Pr(32 * 4 + 2, 11 * 4 + 2, "hekken/haag_laag", "S")


# ------------------------------------------------------------------ railway with viaduct

## Railway x 33-34: level crossing at z 0, ramps up to a viaduct deck on level 5 over
## Main Street and down again, piers, overhead line masts and a platform at z 26..29.
func _railway() -> void:
	var tracks := [33, 34]
	for x in tracks:
		# flat track at the ends (level crossing in North Street)
		G(x, 0, "spoor/trein_overweg", "E")
		for z in [1, 2, 3, 26, 27, 28, 29]:
			G(x, z, "spoor/trein_recht")
		# ramp up (north -> south) to level 5
		for i in range(5):
			var z := 4 + i
			var tile_name := "helling/helling_brug_trein_recht_rand" if x == 34 else "helling/helling_brug_trein_recht"
			G(x, z, tile_name, "N", i)
		# bridge deck at level 5
		for z in range(9, 21):
			G(x, z, "brug/brug_dek_trein_rand", "S" if x == 33 else "N", 5)
		# ramp down
		for i in range(5):
			var z := 21 + i
			var tile_name := "helling/helling_brug_trein_recht_rand" if x == 33 else "helling/helling_brug_trein_recht"
			G(x, z, tile_name, "S", 4 - i)
		# piers: on grass, and on the Main Street pavements
		for z in [10, 19]:
			_pier(x, z, "brug/brug_pijler_gras", 0, 4)
		for z in [12, 17]:
			_pier(x, z, "brug/brug_pijler_stoep", 0, 4)
		for z in [9, 11, 18, 20]:
			G(x, z, "brug/brug_ligger", "S", 4)
	# under the viaduct: grass, and Main Street passes through (see _main_street)
	for x in tracks:
		for z in range(4, 26):
			if z >= 12 and z <= 17:
				continue
			if not occupied.has(Vector2i(x, z)):
				G(x, z, "natuur/gras_hoog")
	# overhead line
	for z in range(0, OLD_H, 3):
		var wy := 0.5
		if z >= 9 and z <= 20:
			wy = 5.0
		elif (z >= 4 and z < 9) or (z > 20 and z <= 25):
			continue
		Pr(33 * 4 - 0.5, z * 4 + 2, "spoor/bovenleidingmast", "S", wy)
	# level crossing in North Street
	Pr(32 * 4 + 1, 0 * 4 + 3.5, "spoor/spoorboom", "S")
	Pr(35 * 4 + 3, 0 * 4 + 0.5, "spoor/andreaskruis", "N")
	Pr(32 * 4 + 1, 2 * 4, "spoor/seinpaal", "N")
	G(35, 0, "weg/weg_vlak")
	# platform
	for z in range(26, 30):
		G(32, z, "spoor/perron", "E")
		G(31, z, "spoor/perron_midden")
	G(31, 26, "spoor/perron_trap", "N")
	Pr(31 * 4 + 2, 28 * 4, "ov/abri", "E", 1.0)
	Pr(32 * 4 + 1, 27 * 4, "straat/bank_modern", "E", 1.0)
	Pr(31 * 4 + 3, 29 * 4 + 2, "verlichting/lantaarn_modern", "S", 1.0)
	G(30, 26, "stoep/stoep_vol")
	for z in range(4, 12):
		G(35, z, "natuur/gras")


# ------------------------------------------------------------------ park with pond

## Park x 0..5, z 18..29 with a pond, gravel and sand paths, flower beds, trees and benches.
func _park() -> void:
	for x in range(0, 5):
		for z in range(18, OLD_H):
			var t := "natuur/gras"
			if (x + z) % 6 == 0:
				t = "natuur/gras_bloemen"
			G(x, z, t)
	# pond x 1..4, z 20..25
	for x in [2, 3]:
		G(x, 20, "water/water_oever", "S")
		G(x, 25, "water/water_oever", "N")
		for z in range(21, 25):
			G(x, z, "water/water" if (x + z) % 3 else "water/water_lelies")
	for z in range(21, 25):
		G(1, z, "water/water_oever", "E")
		G(4, z, "water/water_oever", "W")
	G(1, 20, "water/water_oever_hoek_buiten", "SE")
	G(4, 20, "water/water_oever_hoek_buiten", "WS")
	G(1, 25, "water/water_oever_hoek_buiten", "EN")
	G(4, 25, "water/water_oever_hoek_buiten", "NW")
	G(3, 22, "water/water_riet")
	# paths
	for z in range(18, OLD_H):
		if z < 20 or z > 25:
			G(0, z, "natuur/pad_grind")
	column(5, 18, 29, "natuur/pad_grind")
	row(0, 4, 27, "natuur/pad_grind", "E")
	G(5, 27, "natuur/pad_grind")
	G(0, 27, "natuur/pad_grind")
	row(0, 4, 18, "natuur/pad_zand", "E")
	G(1, 28, "natuur/bloemperk_tulpen")
	G(2, 28, "natuur/bloemperk_tulpen", "E")
	G(3, 28, "natuur/bloemperk_tulpen")
	# quay pavement on the park side
	column(6, 18, 29, "weg/straat_klinkers")
	Pr(0 * 4 + 2, 23 * 4, "bomen/treurwilg")
	Pr(4 * 4 + 3, 19 * 4, "bomen/eik")
	Pr(1 * 4, 29 * 4, "bomen/den")
	Pr(4 * 4 + 2, 29 * 4 + 1, "bomen/populier")
	Pr(3 * 4 + 2, 29 * 4 + 2, "bomen/populier")
	Pr(2 * 4, 19 * 4, "bomen/berk")
	Pr(1 * 4, 19 * 4 + 2, "bomen/berk")
	Pr(4 * 4 + 2, 26 * 4 + 2, "bomen/herfstboom")
	Pr(5 * 4 + 2, 21 * 4, "bomen/conifeer")
	Pr(5 * 4 + 2, 24 * 4, "bomen/conifeer")
	Pr(0 * 4 + 2, 26 * 4 + 2, "straat/bank_hout", "E")
	Pr(2 * 4 + 2, 26 * 4 + 3, "straat/bank_hout", "N")
	Pr(1 * 4 + 1, 26 * 4, "verlichting/lantaarn_park")
	Pr(4 * 4 + 2, 18 * 4 + 2, "verlichting/lantaarn_park")
	Pr(0 * 4 + 2, 21 * 4, "straat/prullenbak_rond")
	Pr(3 * 4, 25 * 4 + 1, "water/steiger", "N", -0.0)
	Pr(2 * 4, 20 * 4 + 2, "planten/riet")
	Pr(4 * 4 + 1, 23 * 4, "planten/riet")
	Pr(3 * 4 + 2, 27 * 4 + 2, "planten/struik_bloei")
	Pr(5 * 4 + 2, 26 * 4 + 2, "water/reddingsboei")
	Pr(0 * 4 + 2, 28 * 4 + 2, "planten/graspol")
	Pr(2 * 4 + 2, 27 * 4 + 1, "planten/varen")


## Grass on every ground cell of the main map (x < W, z < H) that is still empty.
func _fill_grass() -> void:
	for x in range(0, W):
		for z in range(0, H):
			if not occupied.has(Vector2i(x, z)):
				G(x, z, "natuur/gras")


# ==================================================================
# EXPANSION: reusable build helpers + new districts (x 36..95, z 30..79)
# ==================================================================

const ORDER := ["S", "E", "N", "W"]  # directions in rotation order


## Deterministic hash of (a, b) mapped to 0 .. n-1; used for repeatable variation.
func _r(a: int, b: int, n: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663) ^ 0x5bd1e995) % maxi(n, 1)


## True if tile_name exists in the library of gm (default: the buildings layer).
func _has(tile_name: String, gm: GridMap = null) -> bool:
	var g := gm if gm else buildings
	return g.mesh_library.find_item_by_name(tile_name) >= 0


## Open sides of cell (x, z) within the rectangle (x0, z0, w, d): the edges of the
## rectangle the cell lies on, in the order N, S, W, E.
func _sides(x: int, z: int, x0: int, z0: int, w: int, d: int) -> Array:
	var s := []
	if z == z0: s.append("N")
	if z == z0 + d - 1: s.append("S")
	if x == x0: s.append("W")
	if x == x0 + w - 1: s.append("E")
	return s


## Corner key (from CORNER) formed by two of the given sides, or "" if none. When
## several fit (narrow shapes), the one whose front letter equals front is preferred.
func _corner_pair(sides: Array, front: String) -> String:
	var candidates := []
	for key in ["SE", "EN", "NW", "WS"]:
		if sides.has(key[0]) and sides.has(key[1]):
			candidates.append(key)
	for key in candidates:
		if key[0] == front:
			return key
	return candidates[0] if candidates.size() > 0 else ""


## Corner key of a cell that is a corner of the rectangle (x0, z0, w, d), else "".
## Only for rectangles at least 2 cells wide and deep.
func _corner_of(x: int, z: int, x0: int, z0: int, w: int, d: int) -> String:
	var sides := _sides(x, z, x0, z0, w, d)
	return _corner_pair(sides, "") if sides.size() == 2 else ""


## Flat roof tile on one cell at storey y, chosen by its open sides (p = style prefix).
## A free-standing cell falls back to the end piece if the style has no "los" tile.
func _flat_roof(x: int, y: int, z: int, p: String, sides: Array) -> void:
	var e := _edge(sides)
	var kind: String = e[0]
	if kind == "los" and not _has(p + "dak_plat_los"):
		kind = "eind"
	B(x, y, z, p + "dak_plat_" + kind, e[1])


## Rectangular building at tile (x0, z0), w x d tiles, `floors` storeys of the given style.
## Facade tiles are chosen per cell from its open sides (corner pieces on corners).
## opts: front, gf (ground floor, Array), gf_side, gf_corner, upper (upper floors, Array), upper_corner,
## roof ("flat"/"sloped"/"gable"/"cornice"/"battlements"/"none"), roof_extra (Array of sloped-roof
## variants), top (tile on the front edge instead of a roof), y0 (first storey),
## gap (Array of Vector2i cells without roof).
func block(x0: int, z0: int, w: int, d: int, style: String, floors: int, opts := {}) -> void:
	var p := style + "/" + style + "_"
	var front: String = opts.get("front", "S")
	var gf: Array = opts.get("gf", ["bg_raam"])
	var gf_side: String = opts.get("gf_side", gf[0])
	var gf_corner: String = opts.get("gf_corner", "bg_raam_hoek")
	var upper: Array = opts.get("upper", ["verd_raam"])
	var upper_corner: String = opts.get("upper_corner", "verd_raam_hoek")
	var roof: String = opts.get("roof", "flat")
	var roof_extra: Array = opts.get("roof_extra", [])
	var top: String = opts.get("top", "")
	var y0: int = opts.get("y0", 0)
	var gap: Array = opts.get("gap", [])
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d):
			var sides := _sides(x, z, x0, z0, w, d)
			for v in range(floors):
				var tile_name := "blok_dicht"
				var rot = "S"
				if sides.size() == 0:
					pass
				elif sides.size() == 1 or (sides.size() == 2 and _corner_pair(sides, front) == ""):
					var s: String = front if sides.has(front) else sides[0]
					if v == 0:
						tile_name = gf[_r(x, z, gf.size())] if s == front else gf_side
					else:
						tile_name = upper[_r(x * 7 + v, z, upper.size())]
					rot = s
				else:
					var key := _corner_pair(sides, front)
					tile_name = gf_corner if v == 0 else upper_corner
					rot = CORNER[key]
				B(x, y0 + v, z, p + tile_name, rot)
			var yd := y0 + floors
			if gap.has(Vector2i(x, z)):
				continue
			if top != "" and sides.has(front):
				B(x, yd, z, p + top, front)
				continue
			match roof:
				"flat":
					_flat_roof(x, yd, z, p, sides)
				"cornice", "battlements":
					var base_tile := "dak_plat_kroonlijst_" if roof == "cornice" else "dak_kantelen_"
					if not _has(p + base_tile + "rand"):
						base_tile = "dak_kroonlijst_"
					if sides.size() == 1:
						B(x, yd, z, p + base_tile + "rand", sides[0])
					elif sides.size() >= 2 and _corner_pair(sides, front) != "":
						B(x, yd, z, p + base_tile + "hoek", CORNER[_corner_pair(sides, front)])
					else:
						B(x, yd, z, p + "dak_plat_midden", "S")
				"sloped":
					if sides.size() == 1:
						var nm := "dak_schuin"
						# roughly one in three edge cells gets a variant (dormer, chimney, ...)
						if roof_extra.size() > 0 and _r(x, z * 3, 3) == 0:
							nm = roof_extra[_r(x, z, roof_extra.size())]
						B(x, yd, z, p + nm, sides[0])
					elif _corner_pair(sides, front) != "":
						B(x, yd, z, p + "dak_schuin_hoek_buiten", CORNER[_corner_pair(sides, front)])
					else:
						B(x, yd, z, p + "dak_plat_midden", "S")
				"gable":
					var along_x := front == "N" or front == "S"
					var end_a := (x == x0) if along_x else (z == z0)
					var end_b := (x == x0 + w - 1) if along_x else (z == z0 + d - 1)
					if along_x:
						if end_b: B(x, yd, z, p + "dak_zadel_schild", "S")
						elif end_a: B(x, yd, z, p + "dak_zadel_schild", "N")
						else: B(x, yd, z, p + "dak_zadel", "S")
					else:
						if end_a: B(x, yd, z, p + "dak_zadel_schild", "E")
						elif end_b: B(x, yd, z, p + "dak_zadel_schild", "W")
						else: B(x, yd, z, p + "dak_zadel", "E")


## Closed city block (ring 2 deep) at tile (x0, z0), w x d tiles, with sloped roofs that
## wrap around the corners. The outer ring faces the street, the inner ring the courtyard.
## opts: gf, upper (street facades), back (courtyard facades), roof_extra (roof variants).
func ring(x0: int, z0: int, w: int, d: int, style: String, floors: int, opts := {}) -> void:
	var p := style + "/" + style + "_"
	var gf: Array = opts.get("gf", ["bg_raam"])
	var upper: Array = opts.get("upper", ["verd_raam"])
	var back: Array = opts.get("back", ["verd_raam"])
	var roof_variants: Array = opts.get("roof_extra", [])
	var x1 := x0 + w - 1
	var z1 := z0 + d - 1
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			var outer := x == x0 or x == x1 or z == z0 or z == z1
			var inner := not outer and (x == x0 + 1 or x == x1 - 1 or z == z0 + 1 or z == z1 - 1)
			if not outer and not inner:
				continue
			if outer:
				var sides := _sides(x, z, x0, z0, w, d)
				var key := _corner_pair(sides, "") if sides.size() == 2 else ""
				for v in range(floors):
					if key != "":
						B(x, v, z, p + ("bg_raam_hoek" if v == 0 else "verd_raam_hoek"), CORNER[key])
					else:
						var nm: String = gf[_r(x, z, gf.size())] if v == 0 else upper[_r(x + v, z, upper.size())]
						B(x, v, z, p + nm, sides[0])
				if key != "":
					B(x, floors, z, p + "dak_schuin_hoek_buiten", CORNER[key])
				else:
					var dn := "dak_schuin"
					if roof_variants.size() > 0 and _r(x, z, 3) == 0:
						dn = roof_variants[_r(z, x, roof_variants.size())]
					B(x, floors, z, p + dn, sides[0])
			else:
				var court := []
				if z == z0 + 1 and x > x0 + 1 and x < x1 - 1: court.append("S")
				if z == z1 - 1 and x > x0 + 1 and x < x1 - 1: court.append("N")
				if x == x0 + 1 and z > z0 + 1 and z < z1 - 1: court.append("E")
				if x == x1 - 1 and z > z0 + 1 and z < z1 - 1: court.append("W")
				if court.size() == 0:
					var dk := ""
					if x == x0 + 1 and z == z0 + 1: dk = "SE"
					elif x == x1 - 1 and z == z0 + 1: dk = "WS"
					elif x == x0 + 1 and z == z1 - 1: dk = "EN"
					else: dk = "NW"
					for v in range(floors):
						B(x, v, z, p + "blok_dicht", "S")
					B(x, floors, z, p + "dak_schuin_hoek_binnen", dk)
				else:
					for v in range(floors):
						B(x, v, z, p + back[_r(x + v, z, back.size())], court[0])
					B(x, floors, z, p + "dak_schuin", court[0])


## Tower of stacked parts at tile (x, z) (list of names without style prefix, bottom
## first), starting at storey y0.
func tower(x: int, z: int, style: String, parts: Array, rot = "S", y0 := 0) -> void:
	var p := style + "/" + style + "_"
	for i in parts.size():
		B(x, y0 + i, z, p + parts[i], rot)


## Street profile along x from x0 to x1: rows = Array of [z, tile, rot] from north to
## south; x values in skip are left out (e.g. intersections).
func profile_x(x0: int, x1: int, rows: Array, skip := []) -> void:
	for x in range(x0, x1 + 1):
		if skip.has(x):
			continue
		for r in rows:
			G(x, r[0], r[1], r[2])


## Street profile along z from z0 to z1: columns = Array of [x, tile, rot] from west to
## east; z values in skip are left out.
func profile_z(z0: int, z1: int, columns: Array, skip := []) -> void:
	for z in range(z0, z1 + 1):
		if skip.has(z):
			continue
		for c in columns:
			G(c[0], z, c[1], c[2])


## Fills the rectangle x0..x1, z0..z1 (inclusive, tiles) with one ground tile on level y.
func fill_rect(x0: int, z0: int, x1: int, z1: int, tile_name: String, rot = "S", y := 0) -> void:
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			G(x, z, tile_name, rot, y)


## Classifies a cell by its open sides (see _sides / _open_sides) into the suffixes
## used by roof, deck and pool tiles. Returns [kind, rotation]:
##   "midden" no open side; "rand" one open side (rotated towards it);
##   "hoek" two adjacent open sides; "tegenover" two opposite open sides;
##   "eind" three open sides; "los" all four sides open (free-standing cell).
func _edge(sides: Array) -> Array:
	match sides.size():
		0:
			return ["midden", "S"]
		1:
			return ["rand", sides[0]]
		2:
			var key := _corner_pair(sides, "")
			if key != "":
				return ["hoek", CORNER[key]]
			return ["tegenover", "S" if sides.has("N") else "E"]
		3:
			# rotate so that the closed end faces the single closed side
			var absent := ""
			for d in ORDER:
				if not sides.has(d):
					absent = d
			return ["eind", (ORDER.find(absent) + 1) % 4]
	return ["los", "S"]


## Open sides of cell c within an arbitrary set of cells (Array or Dictionary keyed
## by Vector2i), in the order N, S, W, E (same order as _sides).
func _open_sides(c: Vector2i, cells) -> Array:
	var sides := []
	for d in ["N", "S", "W", "E"]:
		if not cells.has(c + DIR_OFFSET[d]):
			sides.append(d)
	return sides


## Round-robin pick: returns list[counter[key]] (wrapping) and advances that counter.
## The counter always advances; returns "" for an empty list.
func _next(list: Array, counter: Dictionary, key: String) -> String:
	var i: int = counter.get(key, 0)
	counter[key] = i + 1
	return "" if list.is_empty() else list[i % list.size()]


## Bridge pier on the ground layer: foot tile at level y0, plain shaft segments
## in between and a pier head at level y_top (the deck goes on y_top + 1).
func _pier(x: int, z: int, foot: String, y0: int, y_top: int) -> void:
	G(x, z, foot, "S", y0)
	for y in range(y0 + 1, y_top):
		G(x, z, "brug/brug_pijler", "S", y)
	G(x, z, "brug/brug_pijler_kop", "S", y_top)


## Stacked mast on the buildings layer (radio tower, factory chimney): prefix + "_voet"
## at storey 0, "_segment" up to height - 1 and "_top" at storey height.
func _mast(x: int, z: int, prefix: String, height: int) -> void:
	B(x, 0, z, prefix + "_voet", "S")
	for v in range(1, height):
		B(x, v, z, prefix + "_segment", "S")
	B(x, height, z, prefix + "_top", "S")


## Hollow hall of w x d cells (one storey, roof included) from the "hallen" group.
## door = the edge cell that gets the wall with a door; column_x = x of the interior
## cells that get a roof with a column (-1 = none).
func _hall(x0: int, z0: int, w: int, d: int, hall: String, door: Vector2i, column_x := -1) -> void:
	var st := "hallen/" + hall + "_"
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d):
			var sides := _sides(x, z, x0, z0, w, d)
			if sides.size() == 0:
				B(x, 0, z, st + ("dak_kolom" if x == column_x else "dak"), "S")
			elif sides.size() == 1:
				B(x, 0, z, st + ("wand_deur_dak" if Vector2i(x, z) == door else "wand_dak"), sides[0])
			else:
				B(x, 0, z, st + "hoek_dak", CORNER[_corner_pair(sides, "")])


## Parking garage of w x d cells with the given number of levels: parking decks
## ("dek") with a roof deck ("dak") on top, edges and corners chosen per cell.
func _parking_decks(x0: int, z0: int, w: int, d: int, levels: int) -> void:
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d):
			var e := _edge(_sides(x, z, x0, z0, w, d))
			for v in range(levels):
				var kind := "dak" if v == levels - 1 else "dek"
				B(x, v, z, "parkeergarage/parkeergarage_%s_%s" % [kind, e[0]], e[1])


## Swimming pool basin of w x d cells on ground level -1. stairs: the north edge
## cell at x0 + 2 gets the edge with a ladder. clear_top: also empty level 0
## above the basin (otherwise the surrounding tiles stay there, as in a covered pool).
func _pool_basin(x0: int, z0: int, w: int, d: int, stairs: bool, clear_top: bool) -> void:
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d):
			var es := _sides(x, z, x0, z0, w, d)
			var e := _edge(es)
			var nm: String = "zwembad/zwembad_" + e[0]
			if stairs and es.size() == 1 and x == x0 + 2 and es[0] == "N":
				nm = "zwembad/zwembad_rand_trap"
			if clear_top:
				_trench(x, z, nm, 1, e[1])
			else:
				G(x, z, nm, e[1], -1)
				occupied[Vector2i(x, z)] = true


## Small 3x3 hill of the given material ("gras", "zand", "grind"); (hx, hz) is the
## north-west cell. Block with a top in the centre, slopes on the sides, outer corners.
func _hill(hx: int, hz: int, mat: String) -> void:
	var p: String = "heuvel/heuvel_" + mat + "_"
	G(hx + 1, hz + 1, p + "blok")
	G(hx + 1, hz + 1, p + "top", "S", 1)
	G(hx + 1, hz, p + "helling", "S")
	G(hx + 1, hz + 2, p + "helling", "N")
	G(hx, hz + 1, p + "helling", "E")
	G(hx + 2, hz + 1, p + "helling", "W")
	G(hx, hz, p + "hoek_buiten", "SE")
	G(hx + 2, hz, p + "hoek_buiten", "WS")
	G(hx, hz + 2, p + "hoek_buiten", "EN")
	G(hx + 2, hz + 2, p + "hoek_buiten", "NW")


# ------------------------------------------------------------------ the new districts

## Everything outside the old town: the new districts east and south of it, the
## campus, the demo districts below the map and a few 1.80 m scale figures. Also sets
## catalog_start and the size of the tint map.
func _expansion() -> void:
	_church_street_and_cross_street2()
	_south_road()
	_churches_and_school()
	_museum_and_town_hall()
	_district_1930s()
	_mansions()
	_small_churches()
	_high_rise()
	_swimming_and_halls()
	_river_and_bridges()
	_district_1960s()
	_farm_and_businesses()
	_southeast()
	_motorway_and_tunnel()
	_rail_end()
	_pedestrian_bridge()
	_decoration()
	_campus()
	var z_end := _demo_districts(99)
	_polder(z_end)
	catalog_start = (z_end + 4) * 4.0
	tint_map.set("area_cells", Vector2i(W, z_end + 4))
	# scale model: a 1.80 m person in a few places
	for pos in [Vector2(70.5, 17.5), Vector2(28.5, 12.5), Vector2(61.0, 47.5), Vector2(87.0, 33.0)]:
		Pr(pos.x * 4, pos.y * 4, "overig/persoon_1m80", "S")


## Polder around the whole town (POLDER tiles wide), so it doesn't end in the void:
## meadows in parcels between ditches, now and then a pollard willow by a ditch.
const POLDER := 10


func _polder(z_end: int) -> void:
	for x in range(-POLDER, W + POLDER):
		for z in range(-POLDER, z_end + POLDER):
			if x >= 0 and x < W and z >= 0 and z < z_end:
				continue
			var px := posmod(x, 9)
			var pz := posmod(z, 12)
			if px == 0:
				G(x, z, "water/sloot")
				if pz == 6 and _r(x, z, 3) == 0:
					Pr(x * 4 + 3.5, z * 4 + 2.0, "bomen/treurwilg")
			elif pz == 0:
				G(x, z, "water/sloot", "E")
			else:
				G(x, z, "natuur/gras_hoog" if _r(x / 9, z / 12, 4) == 0 else "natuur/gras")


## Church Street (z 0, pavement z 1, x 36..95) and Cross Street 2 (x 60-61, pavements
## x 59 and 62, z 2..39) with its signalised intersection with Main Street.
func _church_street_and_cross_street2() -> void:
	# Church Street (z=0) and pavement (z=1) from x 36 to 95
	for x in range(36, W):
		if x == 60 or x == 61:
			G(x, 0, "weg/kruising_stop")
			continue
		G(x, 0, "weg/rijstrook_onderbroken_geen" if x % 2 else "weg/weg_vlak", "E")
		if x == 59:
			G(x, 1, "stoep/stoep_hoek_buiten", "EN")
		elif x == 62:
			G(x, 1, "stoep/stoep_hoek_buiten", "NW")
		else:
			G(x, 1, "stoep/stoep_rand", "N")
	Pr(45 * 4, 1 * 4 + 1, "borden/bord_max_30", "N")
	Pr(70 * 4, 1 * 4 + 1, "borden/bord_drempel", "N")
	G(72, 0, "weg/drempel_plateau", "E")
	G(48, 0, "weg/drempel_punaise", "E")
	# Cross Street 2 (x 60,61) with pavements 59 and 62, from z 2 to 39
	for z in range(2, 40):
		if z >= 12 and z <= 17:
			continue
		if z == 10 or z == 20:
			G(60, z, "weg/zebrapad")
			G(61, z, "weg/zebrapad")
			G(59, z, "stoep/stoep_ribbel", "E")
			G(62, z, "stoep/stoep_ribbel", "W")
			continue
		if z == 11:
			G(60, z, "weg/rijstrook_stop_tekst", "N")
			G(61, z, "weg/rijstrook_pijl_rechtdoor_rechts", "S")
		elif z == 18:
			G(60, z, "weg/rijstrook_pijl_links", "N")
			G(61, z, "weg/rijstrook_stopstreep", "S")
		elif z % 7 == 3:
			G(60, z, "weg/drempel_bus", "N")
			G(61, z, "weg/drempel_bus", "S")
		else:
			G(60, z, "weg/rijstrook_geen_kant", "N")
			G(61, z, "weg/rijstrook_doorgetrokken_dubbel" if z > 30 else "weg/rijstrook_onderbroken_kant", "S")
		G(59, z, "stoep/stoep_goot_kolk" if z % 9 == 4 else "stoep/stoep_goot_rand", "E")
		G(62, z, "stoep/stoep_goot_rand", "W")
		if z % 4 == 2:
			Pr(59 * 4 + 1, z * 4 + 2, "verlichting/lantaarn_modern", "W")
			Pr(62 * 4 + 3, z * 4 + 2, "bomen/linde")
	# intersection with Main Street: traffic lights for cars, bicycles, buses and pedestrians
	for x in [60, 61]:
		G(x, 12, "weg/zebrapad")
		G(x, 13, "weg/fietsoversteek")
		G(x, 14, "weg/kruis_markering")
		G(x, 15, "weg/weg_vlak")
		G(x, 16, "weg/fietsoversteek")
		G(x, 17, "weg/zebrapad")
	Pr(59 * 4 + 3, 12 * 4 + 3.5, "verkeer/verkeerslicht_set", "N")
	Pr(62 * 4 + 1, 17 * 4 + 0.5, "verkeer/verkeerslicht_set", "S")
	Pr(62 * 4 + 0.5, 12 * 4 + 3.5, "verkeer/verkeerslicht_bus", "W")
	Pr(59 * 4 + 3.5, 17 * 4 + 0.5, "verkeer/verkeerslicht_bus", "E")
	Pr(59 * 4 + 2, 13 * 4 + 1, "verkeer/drukknop_fiets", "E")
	Pr(62 * 4 + 2, 16 * 4 + 3, "verkeer/drukknop_fiets", "W")
	Pr(59 * 4 + 1, 12 * 4 + 1, "verkeer/drukknop_voetganger", "N")
	Pr(62 * 4 + 3, 17 * 4 + 3, "verkeer/drukknop_voetganger", "S")
	Pr(59 * 4 + 1, 11 * 4, "borden/bord_voorrangskruispunt", "N")
	Pr(62 * 4 + 3, 19 * 4, "borden/bord_verplicht_rechtsaf", "S")
	# tram overhead line along Main Street
	for x in range(40, W, 6):
		Pr(x * 4, 12 * 4 + 3.5, "ov/tram_bovenleiding_mast", "N")


## South Road along x at z 40..46 (pavement, cycle path, two lanes, bus lane, cycle path,
## pavement) with a bridge over the canal, bus stops and signs.
func _south_road() -> void:
	# profile z: 40 pavement, 41 cycle path, 42 lane west, 43 lane east, 44 bus lane east, 45 cycle path, 46 pavement
	for x in range(0, W):
		if x == 8 or x == 9:
			G(x, 40, "brug/brug_dek_weg_rand", "W")
			for z in range(41, 46):
				G(x, z, "brug/brug_dek_weg_midden", "E")
			G(x, 46, "brug/brug_dek_weg_rand", "E")
			continue
		if x == 28 or x == 29 or x == 60 or x == 61:
			G(x, 40, "weg/zebrapad")
			G(x, 41, "weg/fietsoversteek")
			G(x, 42, "weg/weg_vlak")
			G(x, 43, "weg/weg_vlak")
			G(x, 44, "weg/weg_vlak")
			G(x, 45, "weg/fietsoversteek")
			G(x, 46, "stoep/stoep_goot_rand", "N")
			continue
		# north pavement: corners at the side streets, road at the quay streets
		if x == 27 or x == 59:
			G(x, 40, "stoep/stoep_hoek_buiten", "SE")
		elif x == 30 or x == 62:
			G(x, 40, "stoep/stoep_hoek_buiten", "WS")
		elif x == 6 or x == 11:
			G(x, 40, "weg/weg_vlak")
		else:
			G(x, 40, "stoep/stoep_goot_rand", "S")
		G(x, 41, "fietspad/fietspad_recht", "E")
		G(x, 42, "weg/rijstrook_onderbroken_kant", "E")
		G(x, 43, "weg/rijstrook_geen_geen", "W")
		var bus := "weg/rijstrook_bus_leeg"
		if x % 16 == 3:
			bus = "weg/rijstrook_bus"
		elif x == 20 or x == 50:
			bus = "weg/busstrook_halte"
		G(x, 44, bus, "W")
		G(x, 45, "fietspad/fietspad_recht", "E")
		G(x, 46, "stoep/stoep_goot_rand", "N")
	# median lanterns, bus stops, signs
	for x in range(2, W, 8):
		Pr(x * 4 + 2, 43 * 4, "verlichting/lantaarn_middenberm", "E")
	Pr(20 * 4, 46 * 4 + 2, "ov/abri", "N")
	Pr(50 * 4, 46 * 4 + 2, "ov/bushokje", "N")
	Pr(22 * 4, 46 * 4 + 3, "ov/bushalte_paal", "N")
	Pr(52 * 4, 46 * 4 + 3, "ov/bushalte_paal", "N")
	Pr(14 * 4, 46 * 4 + 3, "borden/bord_busbaan", "W")
	Pr(70 * 4, 40 * 4 + 1, "borden/bord_max_50", "E")
	Pr(80 * 4, 46 * 4 + 3, "borden/bord_informatie", "W")
	Pr(90 * 4, 40 * 4 + 1, "borden/bord_ziekenhuis", "E")
	Pr(66 * 4, 40 * 4 + 1, "verkeer/wegafzetting_paal_flitser", "E")
	# traffic bollards on the traffic island at the intersection
	for x in [27, 30, 59, 62]:
		Pr(x * 4 + 2, 43 * 4, "verkeer/verkeerszuil", "E")


## Gothic cathedral x 36..45, z 2..11 (nave, aisles with flying buttresses, west towers)
## and a school with playground x 47..57.
func _churches_and_school() -> void:
	# cathedral (kerk_steen) x 36..45, z 3..10, front facade facing west
	var k := "kerk_steen"
	var p := k + "/" + k + "_"
	fill_rect(36, 2, 45, 11, "plein/plein_natuursteen")
	# nave (2 deep) x 38..45, z 5..6, three storeys high
	for x in range(38, 46):
		for z in [5, 6]:
			var facing := "N" if z == 5 else "S"
			B(x, 0, z, p + "blok_dicht", "S")
			B(x, 1, z, p + "verd_spitsraam", facing)
			B(x, 2, z, p + "verd_spitsraam", facing)
			B(x, 3, z, p + ("dak_schuin_hoek_buiten" if x == 45 else "dak_schuin"), (("EN" if z == 5 else "SE") if x == 45 else facing))
	# side aisles (1 storey) with buttresses and flying buttresses
	for x in range(38, 46):
		for z in [4, 7]:
			var facing := "N" if z == 4 else "S"
			B(x, 0, z, p + ("verd_steunbeer" if x % 2 else "bg_spitsraam"), facing)
			if x % 2:
				B(x, 1, z, p + "luchtboog", facing)
			else:
				B(x, 1, z, p + "dak_schuin", facing)
	# west front with two towers and rose window
	for z in [5, 6]:
		B(37, 0, z, p + "bg_portaal", "W")
		B(37, 1, z, p + "verd_roosvenster" if z == 5 else p + "verd_spitsraam", "W")
		B(37, 2, z, p + "verd_spitsraam", "W")
		B(37, 3, z, p + "gevel_spits" if z == 5 else p + "dak_plat_midden", "W")
	for z in [4, 7]:
		tower(37, z, k, ["toren_portaal", "toren_raam", "toren_raam", "toren_galmgat", "toren_klok", "toren_pinakels"], "W")
	tower(44, 3, k, ["toren_raam", "toren_raam", "toren_galmgat", "toren_spits_onder", "toren_spits_boven"], "N")
	for z in [3, 8]:
		Pr(36 * 4 + 2, z * 4 + 2, "bomen/linde")
	Pr(41 * 4, 9 * 4 + 2, "straat/bank_hout", "N")
	Pr(43 * 4, 9 * 4 + 2, "straat/bank_hout", "N")
	# school with playground x 47..57
	block(48, 2, 8, 2, "school", 3, {"front": "S", "gf": ["bg_raam", "bg_entree", "bg_raam"], "gf_side": "bg_raam",
		"upper": ["verd_raam"], "roof": "flat"})
	B(52, 3, 2, "school/school_dak_zonnepanelen", "S")
	fill_rect(47, 4, 57, 10, "natuur/speeltuin_rubber")
	fill_rect(55, 7, 57, 10, "natuur/speeltuin_zand")
	fill_rect(47, 2, 47, 3, "stoep/stoep_vol")
	fill_rect(56, 2, 57, 3, "stoep/stoep_vol")
	Pr(49 * 4, 6 * 4, "speeltuin/klimrek")
	Pr(51 * 4 + 2, 8 * 4, "speeltuin/schommel", "E")
	Pr(53 * 4 + 2, 6 * 4, "speeltuin/glijbaan", "E")
	Pr(56 * 4, 8 * 4 + 2, "speeltuin/zandbak")
	Pr(49 * 4, 9 * 4 + 2, "speeltuin/wipwap")
	Pr(54 * 4, 9 * 4 + 2, "speeltuin/draaimolen")
	Pr(57 * 4, 5 * 4, "speeltuin/speelhuisje")
	Pr(51 * 4, 4 * 4 + 1, "speeltuin/basketbalpaal", "S")
	Pr(47 * 4 + 2, 7 * 4 + 2, "speeltuin/voetbaldoel", "E")
	Pr(55 * 4, 4 * 4 + 2, "speeltuin/pingpongtafel")
	for x in range(47, 58, 2):
		Pr(x * 4 + 2, 11 * 4 + 3.5, "hekken/schoolhek", "S")
	Pr(47 * 4 + 1, 11 * 4, "fietsen/fietsenrek_vol", "E")
	Pr(58 * 4 - 1, 9 * 4, "borden/bord_let_op_kinderen", "E")


## Square x 63..95, z 2..11 with a classical museum with dome, the town hall with clock
## tower and flags, and a modern museum.
func _museum_and_town_hall() -> void:
	fill_rect(63, 2, 95, 11, "plein/plein_tegels")
	# classical museum with dome (x 64..70, z 4..10)
	var gap := []
	for x in range(66, 69):
		for z in range(6, 9):
			gap.append(Vector2i(x, z))
	block(64, 4, 7, 7, "museum_klassiek", 2, {"front": "S", "gf": ["bg_raam_boog", "bg_zuilen", "bg_raam_boog"],
		"gf_side": "bg_raam_boog", "gf_corner": "bg_raam_boog_hoek", "upper": ["verd_raam_boog", "verd_relief"],
		"upper_corner": "verd_raam_boog_hoek", "roof": "cornice", "gap": gap})
	B(67, 2, 7, "museum_klassiek/museum_klassiek_dak_koepel_3x3", "S")
	B(67, 2, 10, "museum_klassiek/museum_klassiek_top_fronton", "S")
	Pr(66 * 4, 11 * 4 + 1, "planten/plantenbak_beton")
	Pr(69 * 4, 11 * 4 + 1, "planten/plantenbak_beton")
	# town hall (government) x 73..79, z 6..10 + clock tower
	block(73, 6, 7, 5, "overheid", 3, {"front": "S", "gf": ["bg_raam", "bg_entree", "bg_raam"], "gf_side": "bg_raam",
		"upper": ["verd_raam_hoog", "verd_balkon"], "upper_corner": "verd_raam_hoog_hoek", "roof": "battlements"})
	B(76, 3, 10, "overheid/overheid_top_fronton", "S")
	B(75, 3, 10, "overheid/overheid_top_naambord", "S")
	tower(76, 7, "overheid", ["blok_dicht", "blok_dicht", "blok_dicht", "blok_dicht", "toren_klok", "toren_spits_onder", "toren_spits_boven"])
	for i in 3:
		Pr(74 * 4 + i * 8, 11 * 4 + 2, ["straat/vlaggenmast_nl", "straat/vlaggenmast_regenboog", "straat/vlaggenmast_denhaag"][i], "S")
	D(73 * 4.0, 8 * 4.0, 4.0, "gevel/vlag_regenboog", "W")
	D(80 * 4.0, 8 * 4.0, 4.0, "gevel/vlag_denhaag", "E")
	# modern museum x 83..93, z 4..10
	block(83, 4, 11, 6, "museum_modern", 2, {"front": "S", "gf": ["bg_dicht", "bg_entree", "bg_dicht"], "gf_side": "bg_dicht",
		"gf_corner": "bg_entree_hoek", "upper": ["verd_lichtstrook", "verd_dicht"], "upper_corner": "verd_lichtstrook_hoek", "roof": "flat"})
	for x in range(84, 93):
		B(x, 2, 10, "museum_modern/museum_modern_dak_overstek", "S")
	Pr(88 * 4, 11 * 4 + 2, "planten/boombak")
	Pr(92 * 4, 11 * 4 + 2, "planten/boombak")


## 1930s district x 36..48, z 18..39: a closed block of 4 storeys with shops and
## terraces on Main Street, porch flats along an E-W street and a one-way street.
func _district_1930s() -> void:
	# streets: N-S residential street x=47 (pavements 46 and 48), E-W street z=29 (pavements 28 and 30)
	profile_z(18, 39, [[46, "stoep/stoep_rand", "E"], [47, "weg/straat_eenrichting", "S"], [48, "stoep/stoep_rand", "W"]], [28, 29, 30])
	profile_x(36, 58, [[28, "stoep/stoep_rand", "S"], [29, "weg/weg_vlak", "E"], [30, "stoep/stoep_rand", "N"]], [46, 47, 48])
	G(46, 29, "weg/weg_vlak")
	G(47, 29, "weg/kruising_haaientanden")
	G(48, 29, "weg/weg_vlak")
	for c in [[46, 28, "SE"], [48, 28, "WS"], [46, 30, "EN"], [48, 30, "NW"]]:
		G(c[0], c[1], "stoep/stoep_hoek_buiten", c[2])
	Pr(46 * 4 + 1, 20 * 4, "borden/bord_eenrichtingsweg", "E")
	Pr(48 * 4 + 3, 38 * 4, "borden/bord_verboden_in_te_rijden", "W")
	Pr(48 * 4 + 3, 37 * 4, "borden/bord_onderbord_uitgezonderd", "W")
	for z in [21, 33]:
		G(47, z, "weg/drempel_asfalt")
	# tall upstairs flats (4 storeys) as a closed city block with shops/restaurants on Main Street
	ring(36, 18, 10, 10, "jaren30", 4, {"gf": ["bg_portiek", "bg_raam", "bg_erker"], "upper": ["verd_raam", "verd_erker", "verd_balkon", "verd_trappenhuis"],
		"back": ["verd_raam", "verd_balkon"], "roof_extra": ["dak_schuin_dakkapel", "dak_schuin_schoorsteen"]})
	var shops := ["bg_kleding", "bg_restaurant", "bg_cafe", "bg_bar", "bg_telefoon", "bg_winkel_luifel", "bg_cafe", "bg_restaurant"]
	for i in range(1, 9):
		B(36 + i, 0, 18, "jaren30/jaren30_" + shops[i - 1], "N")
	fill_rect(38, 20, 43, 25, "natuur/gras")
	Pr(40 * 4 + 2, 22 * 4 + 2, "bomen/bloesemboom")
	Pr(42 * 4, 24 * 4, "speeltuin/zandbak")
	# terraces on the Main Street pavement
	for i in range(1, 9):
		var wx := (36 + i) * 4 + 2.0
		if shops[i - 1] in ["bg_restaurant", "bg_cafe"]:
			Pr(wx, 17 * 4 + 1.5, "terras/terras_set_parasol" if i % 2 else "terras/terras_set_parasol_groen")
			Pr(wx - 1.5, 17 * 4 + 3.5, "terras/terras_scherm", "S")
		elif shops[i - 1] == "bg_bar":
			Pr(wx, 17 * 4 + 2, "terras/statafel")
		if i % 3 == 0:
			Pr(wx + 1.5, 17 * 4 + 0.5, "terras/stoepbord", "S")
	# medium-height upstairs flats (3 storeys), porch dwellings on street z=30
	block(36, 31, 10, 2, "jaren30", 3, {"front": "N", "gf": ["bg_portiek", "bg_raam", "bg_erker"], "gf_side": "bg_raam",
		"upper": ["verd_raam", "verd_erker", "verd_balkon"], "roof": "sloped", "roof_extra": ["dak_schuin_dakkapel"]})
	block(36, 35, 10, 2, "jaren30", 3, {"front": "S", "gf": ["bg_portiek", "bg_raam"], "gf_side": "bg_raam",
		"upper": ["verd_raam", "verd_trappenhuis"], "roof": "flat"})
	fill_rect(36, 33, 45, 34, "natuur/gras")
	for x in range(36, 46, 2):
		Pr(x * 4 + 2, 34 * 4 + 0.5, "muurtjes/tuinmuur_middel" if x % 4 else "muurtjes/tuinmuur_poort", "S")
	fill_rect(36, 37, 45, 39, "stoep/stoep_vol")
	for x in range(36, 46, 3):
		Pr(x * 4 + 2, 38 * 4 + 2, "bomen/linde")


## Mansions (1600 and 1900 styles) on Main Street x 49..58 with front steps and gardens.
func _mansions() -> void:
	# mansions 1600 (x 49..53) and 1900 (x 54..58) on Main Street (front north)
	block(49, 18, 5, 2, "herenhuis_1600", 3, {"front": "N", "gf": ["bg_deur", "bg_raam"], "gf_side": "bg_raam",
		"upper": ["verd_raam", "verd_balkon"], "roof": "sloped", "top": "top_lijstgevel_fronton"})
	B(51, 3, 18, "herenhuis_1600/herenhuis_1600_gevel_klok", "N")
	block(54, 18, 5, 2, "herenhuis_1900", 3, {"front": "N", "gf": ["bg_deur", "bg_raam_boog"], "gf_side": "bg_raam_boog",
		"gf_corner": "bg_raam_boog_hoek", "upper": ["verd_raam_boog", "verd_erker", "verd_balkon"], "upper_corner": "verd_raam_boog_hoek", "roof": "sloped",
		"top": "dak_mansarde_rand"})
	# front steps and gardens with walls and gates
	for x in [49, 51, 53]:
		D(x * 4 + 2.0, 18 * 4.0, 0.0, "deuren/bordes_klassiek", "N")
	for x in range(49, 59):
		fill_rect(x, 20, x, 27, "natuur/gras" if x % 2 else "natuur/gras_bloemen")
		Pr(x * 4 + 2, 27 * 4 + 3.5, "muurtjes/tuinmuur_hoog_poort" if x % 3 == 0 else "muurtjes/tuinmuur_hoog", "S")
		Pr(x * 4 + 0.5, 23 * 4 + 2, "hekken/haag", "E")
	Pr(50 * 4 + 2, 24 * 4, "bomen/kastanje")
	Pr(55 * 4 + 2, 25 * 4, "bomen/plataan")
	Pr(57 * 4, 22 * 4, "planten/bosje_klein")
	Pr(52 * 4, 22 * 4, "terras/terras_set")


## Village church with tower and a modern church with detached bell tower (x 49..58, z 31..39).
func _small_churches() -> void:
	fill_rect(49, 31, 58, 39, "natuur/gras")
	# village church (small) x 51..55, z 33, gable roof, tower at x=50
	var k := "kerk_baksteen"
	block(51, 33, 5, 1, k, 2, {"front": "S", "gf": ["bg_spitsraam"], "gf_side": "bg_spitsraam", "gf_corner": "bg_spitsraam_hoek",
		"upper": ["verd_dicht"], "upper_corner": "verd_spitsraam_hoek", "roof": "gable"})
	tower(50, 33, k, ["toren_portaal", "toren_raam", "toren_klok", "toren_spits_onder", "toren_spits_boven"], "W")
	fill_rect(49, 32, 56, 34, "natuur/gras_kort")
	G(49, 33, "natuur/grindpad")
	# modern (reformed) church x 53..57, z 36..38 with a detached bell tower
	block(53, 36, 5, 3, "kerk_modern", 2, {"front": "N", "gf": ["bg_entree", "bg_dicht"], "gf_side": "bg_dicht",
		"gf_corner": "bg_entree_hoek", "upper": ["verd_spleet", "verd_kruis"], "upper_corner": "verd_spleet_hoek", "roof": "flat"})
	tower(51, 37, "kerk_modern", ["toren_beton", "toren_beton", "toren_beton_klok"])
	Pr(50 * 4, 36 * 4, "bomen/treurwilg")
	Pr(57 * 4, 31 * 4 + 2, "bomen/den")


## High-rise district x 63..95, z 18..39: offices, apartment towers, a gallery flat,
## parking garage, radio tower, glass canopy, pillars and a footbridge at level 4.
func _high_rise() -> void:
	fill_rect(63, 18, 76, 39, "plein/plein_tegels")
	fill_rect(80, 18, 95, 39, "plein/plein_tegels")
	profile_z(18, 39, [[77, "stoep/stoep_rand", "E"], [78, "weg/rijstrook_onderbroken_kant", "S"], [79, "stoep/stoep_rand", "W"]])
	# 1980s office (10 storeys)
	block(64, 19, 3, 3, "kantoor_80", 10, {"front": "S", "gf": ["bg_entree"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_spiegelband", "verd_band"], "upper_corner": "verd_spiegelband_hoek", "roof": "flat"})
	B(65, 10, 20, "kantoor_80/kantoor_80_dak_installatie", "S")
	D(64 * 4 + 4.0, 19 * 4 + 3.0, 30.0, "dak/koelinstallatie", "S")
	D(66 * 4 + 2.0, 21 * 4 + 2.0, 30.0, "dak/luchtbehandeling", "E")
	D(71 * 4 + 2.0, 20 * 4 + 2.0, 42.0, "dak/koelinstallatie", "E")
	D(65 * 4 + 2.0, 26 * 4 + 2.0, 21.0, "dak/koelinstallatie", "S")
	D(67 * 4 + 2.0, 26 * 4 + 2.0, 21.0, "dak/zonnepanelen_schuin_rij", "S")
	D(73 * 4 + 4.0, 33 * 4 + 4.0, 30.0, "dak/koelinstallatie", "S")
	# 2000s office (14 storeys) with crown
	block(70, 19, 3, 3, "kantoor_2000", 14, {"front": "S", "gf": ["bg_entree"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_zonwering", "verd_vliesgevel"], "upper_corner": "verd_zonwering_hoek", "roof": "flat"})
	for x in range(70, 73):
		B(x, 14, 21, "kantoor_2000/kantoor_2000_dak_kroon_rand", "S")
	# modern office (7 storeys, louvres) and one with large windows
	block(64, 25, 5, 3, "kantoor_modern", 7, {"front": "S", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_lamellen", "verd_raam_groot"], "upper_corner": "verd_lamellen_hoek", "roof": "flat"})
	block(70, 25, 2, 2, "kantoor_glas", 5, {"front": "S", "gf": ["bg_entree"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_raam_klein"], "upper_corner": "verd_band_hoek", "roof": "flat"})
	# modern apartment building (16 storeys)
	block(73, 24, 3, 4, "appartement_modern", 16, {"front": "W", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_glas", "verd_loggia", "verd_balkon", "verd_paneel", "verd_raam_groot", "verd_raam_klein"], "upper_corner": "verd_balkon_hoek", "roof": "flat"})
	B(74, 16, 25, "appartement_modern/appartement_modern_dak_daktuin", "S")
	# gallery flat (1950s/60s, 10 storeys)
	block(64, 33, 12, 2, "galerijflat", 10, {"front": "N", "gf": ["bg_bergingen", "bg_entree", "bg_bergingen"], "gf_side": "bg_bergingen",
		"gf_corner": "bg_bergingen_hoek", "upper": ["verd_galerij"], "upper_corner": "verd_galerij_hoek", "roof": "flat"})
	for x in range(64, 76):
		for v in range(1, 10):
			B(x, v, 34, "galerijflat/galerijflat_" + ("verd_balkons_hoek" if x == 64 or x == 75 else "verd_balkons"),
				("WS" if x == 64 else "SE") if (x == 64 or x == 75) else "S")
	tower(76, 33, "galerijflat", ["bg_entree", "verd_trappenhuis", "verd_trappenhuis", "verd_trappenhuis", "verd_trappenhuis",
		"verd_trappenhuis", "verd_trappenhuis", "verd_trappenhuis", "verd_trappenhuis", "verd_trappenhuis", "dak_liftopbouw"], "E")
	# parking garage (4 decks) x 81..86, z 19..24
	_parking_decks(81, 19, 6, 6, 4)
	B(81, 0, 21, "parkeergarage/parkeergarage_inrit", "W")
	for v in range(3):
		B(84, v, 21 + (v % 2), "parkeergarage/parkeergarage_helling", "N" if v % 2 == 0 else "S")
	for v in range(4):
		B(87, v, 19, "parkeergarage/parkeergarage_trappenhuis", "S")
	Pr(80 * 4 + 1, 21 * 4, "hekken/slagboom", "W")
	Pr(80 * 4 + 1, 23 * 4, "paaltjes/parkeerautomaat", "W")
	# radio tower
	_mast(92, 20, "overig/radiotoren", 12)
	# glass canopy with terrace
	for x in range(88, 95):
		for z in range(24, 29):
			B(x, 0, z, "overkapping/overkapping_glas_kolom" if (x % 2 == 0 and z % 2 == 0) else "overkapping/overkapping_glas", "S")
	for x in [89, 91, 93]:
		Pr(x * 4, 26 * 4, "terras/terras_set")
	Pr(90 * 4, 27 * 4 + 2, "terras/bloembak_terras")
	# pillars and colonnade
	for x in [64, 67, 70]:
		B(x, 0, 30, "pilaren/pilaar_klassiek" if x == 64 else ("pilaren/pilaar_beton" if x == 67 else "pilaren/pilaar_staal"), "S")
	B(72, 0, 30, "pilaren/pilaar_baksteen", "S")
	for x in range(64, 70):
		B(x, 0, 31, "pilaren/zuilengang_klassiek", "N")
	# footbridge over street x=78 (from apartments to parking garage), at level 4 with stairs
	for x in range(76, 81):
		G(x, 30, "brug/loopbrug_overdekt", "E", 4)
	for i in range(4):
		G(80, 34 - i, "brug/loopbrug_trap", "S", i)


## Indoor pool (hollow hall over a sunken basin), a glass hall and an outdoor pool
## (x 80..94, z 28..39).
func _swimming_and_halls() -> void:
	# indoor pool: hollow hall (glass/pool) x 88..94, z 31..37 with pool tiles on layer -1
	var h0 := 88
	var z0 := 31
	_hall(h0, z0, 7, 7, "hal_zwembad", Vector2i(91, z0))
	fill_rect(h0, z0, h0 + 6, z0 + 6, "zwembad/zwembad_kant_tegels")
	_pool_basin(h0 + 1, z0 + 2, 5, 3, true, false)
	# glass hall next to it x 81..86, z 28..31 (door on the south side)
	_hall(81, 28, 6, 4, "hal_glas", Vector2i(83, 31))
	Pr(83 * 4, 29 * 4 + 2, "planten/boombak")
	Pr(85 * 4, 29 * 4 + 2, "terras/terras_set")
	D(83 * 4 + 2.0, 32 * 4.0, 0.0, "deuren/draaideur", "S")
	# outdoor pool x 81..86, z 33..38
	fill_rect(80, 33, 87, 39, "zwembad/zwembad_kant_tegels")
	_pool_basin(81, 34, 6, 4, false, false)
	G(87, 38, "zwembad/kinderbad")
	Pr(81 * 4 + 2, 33 * 4 + 3, "zwembad/duikplank", "S")
	Pr(84 * 4, 33 * 4 + 3.5, "zwembad/zwembadtrap", "S")
	Pr(86 * 4 + 2, 38 * 4 + 2, "zwembad/badmeesterstoel", "N")
	for x in [81, 83, 85]:
		Pr(x * 4 + 2, 39 * 4, "zwembad/ligstoel", "N")
	Pr(87 * 4 + 2, 35 * 4, "zwembad/parasol")
	for z in range(33, 40, 2):
		Pr(80 * 4, z * 4 + 2, "hekken/hek_gaas_hoog", "E")


## River z 49..53 across the whole map (water on level -2, quays z 48 and 54) with a
## steel arch bridge, cable-stayed bridge, drawbridge, footbridge, quay stairs and boats.
func _river_and_bridges() -> void:
	# river z 49..53 on layer -2, quays at z 48 and 54
	for x in range(0, W):
		for z in range(49, 54):
			G(x, z, "water/water", "S", -2)
			occupied[Vector2i(x, z)] = true
		for z in [48, 54]:
			if (x == 8 or x == 9) and z == 48:
				G(x, z, "water/water_gracht", "S", -2)
				occupied[Vector2i(x, z)] = true
				continue
			G(x, z, "water/kademuur_alg", "S", -2)
			G(x, z, "water/kademuur", "S", -1)
			G(x, z, "stoep/stoep_kade" if x % 6 else "stoep/stoep_kade_klinker", "S" if z == 48 else "N")
			if x % 3 == 0:
				Pr(x * 4 + 2, z * 4 + (1 if z == 48 else 3), "paaltjes/bolder")
			if x % 6 == 3:
				Pr(x * 4 + 2, z * 4 + (2.5 if z == 48 else 1.5), "verlichting/lantaarn_klassiek")
	# steel arch bridge in Cross Street 2 (x 60,61)
	for i in range(5):
		G(60, 53 - i, "brug/staalboog_rand_%d" % (i + 1), "S")
		G(61, 49 + i, "brug/staalboog_rand_%d" % (i + 1), "N")
	for z in [48, 54]:
		G(60, z, "weg/rijstrook_geen_kant", "N")
		G(61, z, "weg/rijstrook_onderbroken_kant", "S")
	# cable-stayed bridge at x 40,41
	G(40, 51, "brug/tuibrug_0", "S")
	for i in range(1, 4):
		G(40, 51 - i, "brug/tuibrug_%d" % i, "S")
		G(40, 51 + i, "brug/tuibrug_%d_achter" % i, "S")
	for z in range(48, 55):
		G(41, z, "brug/brug_dek_weg_rand", "N")
	# drawbridge (classic, narrow) at x=20
	G(20, 49, "brug/ophaalbrug_dek", "S")
	G(20, 50, "brug/ophaalbrug_portaal", "N")
	G(20, 51, "brug/ophaalbrug_dek", "S")
	G(20, 52, "brug/ophaalbrug_portaal", "S")
	G(20, 53, "brug/ophaalbrug_dek", "S")
	Pr(19 * 4 + 2, 48 * 4 + 2, "water/brugwachtershuisje_klassiek")
	# modern footbridge and footbridge-style bridge at x=75
	for z in range(49, 54):
		G(75, z, "brug/voetbrug_modern", "S")
	Pr(76 * 4 + 2, 54 * 4 + 2, "water/brugwachtershuisje_modern")
	# quay stairs and boats
	G(30, 54, "waterkant/kadetrap", "N", -2)
	occupied[Vector2i(30, 54)] = true
	for x in [12, 26, 50, 68, 88]:
		Pr(x * 4, 52 * 4 + 2, "water/woonboot", "E", -2.0)
	Pr(34 * 4, 50 * 4, "water/sloep", "W", -2.0)
	Pr(56 * 4, 50 * 4 + 2, "water/roeiboot", "E", -2.0)


## 1960s district x 0..30, z 55..71: residential streets, single-family homes, a low
## gallery flat, car park, playground and a pond with different banks.
func _district_1960s() -> void:
	# residential streets z=56 and z=64 (with speed bumps), N-S street x=15
	profile_x(0, 30, [[55, "stoep/stoep_rand", "S"], [56, "weg/weg_vlak", "E"], [57, "stoep/stoep_rand", "N"]], [15])
	profile_x(0, 30, [[63, "stoep/stoep_rand", "S"], [64, "weg/weg_vlak", "E"], [65, "stoep/stoep_rand", "N"]], [15])
	profile_z(55, 71, [[14, "stoep/stoep_rand", "E"], [15, "weg/weg_vlak", "S"], [16, "stoep/stoep_rand", "W"]], [55, 56, 57, 63, 64, 65])
	for z in [56, 64]:
		G(15, z, "weg/kruising_vlak")
		G(5, z, "weg/drempel_punaise", "E")
		G(25, z, "weg/verkeersdrempel", "E")
	for c in [[14, 55], [16, 55], [14, 57], [16, 57], [14, 63], [16, 63], [14, 65], [16, 65]]:
		G(c[0], c[1], "weg/weg_vlak")
	for z in [55, 57, 63, 65]:
		G(15, z, "weg/weg_vlak")
	Pr(14 * 4, 58 * 4, "borden/bord_woonerf", "E")
	# single-family homes (2 storeys, sloped roof, bay windows and dormers)
	block(1, 58, 12, 2, "jaren60", 2, {"front": "N", "gf": ["bg_deur", "bg_raam", "bg_erker"], "gf_side": "bg_raam",
		"upper": ["verd_raam", "verd_raam_klein"], "roof": "sloped", "roof_extra": ["dak_schuin_dakkapel", "dak_schuin_dakkapel", "dak_schuin_schoorsteen"]})
	block(1, 61, 12, 2, "jaren60", 2, {"front": "S", "gf": ["bg_deur", "bg_erker", "bg_berging"], "gf_side": "bg_raam",
		"upper": ["verd_raam", "verd_balkon"], "roof": "sloped", "roof_extra": ["dak_schuin_dakkapel"]})
	fill_rect(0, 58, 0, 62, "natuur/gras")
	for x in range(1, 13):
		G(x, 60, "natuur/gras" if x % 2 else "natuur/gras_bloemen")
		Pr(x * 4 + 0.5, 60 * 4 + 2, "hekken/schutting_hout", "E")
	# garage doors and details
	D(3 * 4 + 2.0, 63 * 4.0, 0.0, "deuren/garagedeur_kanteldeur", "S")
	D(7 * 4 + 2.0, 63 * 4.0, 0.0, "deuren/garagedeur_sectionaal", "S")
	D(11 * 4 + 2.0, 63 * 4.0, 0.0, "deuren/garagedeur_roldeur", "S")
	for x in [2, 6, 10]:
		D(x * 4 + 2.0, 58 * 4.0, 3.5, "zonwering/knikarmscherm_streep", "N")
		D(x * 4 + 2.0, 58 * 4.0, 6.0, "zonwering/uitvalscherm_oranje", "N")
	# maisonettes / low gallery flat (4 storeys) x 17..28
	block(17, 58, 12, 2, "jaren60", 4, {"front": "N", "gf": ["bg_deur", "bg_raam", "bg_berging"], "gf_side": "bg_raam",
		"upper": ["verd_raam", "verd_galerij_deur", "verd_raam_klein"], "upper_corner": "verd_raam_hoek", "roof": "flat"})
	for x in range(18, 28):
		B(x, 2, 58, "jaren60/jaren60_verd_galerij_deur", "N")
		B(x, 3, 58, "jaren60/jaren60_verd_raam_klein", "N")
	# car park x 17..28, z 60..62
	for x in range(17, 29):
		G(x, 60, "parkeren/parkeervak_haaks" if x % 4 else "parkeren/parkeervak_laadpaal", "S")
		G(x, 61, "parkeren/parkeerplaats_rijbaan", "E")
		G(x, 62, "parkeren/parkeervak_schuin" if x < 23 else "parkeren/parkeervak_haaks_eind", "N")
	for x in [20, 24, 28]:
		Pr(x * 4, 60 * 4 + 0.5, "paaltjes/laadpaal", "S")
	Pr(17 * 4 + 1, 61 * 4 + 2, "paaltjes/parkeerautomaat", "E")
	Pr(22 * 4, 63 * 4 + 0.5, "straat/afvalcontainer_ondergronds")
	Pr(24 * 4, 63 * 4 + 1, "straat/glasbak")
	Pr(26 * 4, 63 * 4 + 1, "straat/kledingcontainer")
	Pr(28 * 4, 63 * 4 + 1, "straat/container_klein")
	# playground, shrubs and pond with waterside x 0..13 / 17..30, z 66..71
	fill_rect(0, 66, 13, 71, "natuur/gras")
	fill_rect(1, 67, 5, 70, "natuur/speeltuin_rubber")
	Pr(2 * 4, 68 * 4, "speeltuin/schommel", "E")
	Pr(4 * 4, 69 * 4, "speeltuin/glijbaan")
	Pr(3 * 4, 67 * 4 + 2, "speeltuin/wipwap")
	for x in [7, 9, 11]:
		Pr(x * 4 + 2, 68 * 4 + 2, "planten/bosje_groot" if x == 9 else "planten/bosje_klein")
	Pr(12 * 4, 71 * 4, "planten/braamstruik")
	fill_rect(17, 66, 30, 71, "natuur/gras")
	for x in range(19, 29):
		G(x, 67, "waterkant/strand" if x < 22 else ("waterkant/beschoeiing" if x < 25 else "waterkant/basalt_talud"), "S")
		for z in range(68, 71):
			G(x, z, "water/water")
		G(x, 71, "water/water_oever", "N")
	G(23, 69, "brug/voetbrug_hout_boog", "S")
	G(26, 69, "water/water_lelies")
	Pr(20 * 4, 69 * 4, "water/steiger_L", "S", 0.0)
	Pr(27 * 4, 68 * 4, "water/steiger_trap", "N", 0.0)
	Pr(18 * 4, 66 * 4 + 2, "terras/terras_set_parasol")
	G(18, 67, "waterkant/strand_hoek", "WS")
	G(29, 67, "waterkant/boulevard", "S")


## Motorway junction (aansluiting) on the northern carriageway (traffic towards the
## west): exit x 58..51 (shoulder becomes the exit lane, gore with crash cushion), exit
## ramp z 71 to a T-junction with a local road x 45..46 (z 64..71, from the farm track),
## on-ramp z 71 from there and the acceleration lane x 41..34 back into the shoulder.
## The ramp designs are 8 x 4 tiles (grond/snelweg/afrit_<i>_<j>, toerit_<i>_<j>, see
## tools/voxgen/ground5.py): tile (i, j) at (x0 + i, 73 - j).
func _motorway_junction() -> void:
	for i in 8:
		for j in 4:
			G(51 + i, 73 - j, "snelweg/afrit_%d_%d" % [i, j])
			G(34 + i, 73 - j, "snelweg/toerit_%d_%d" % [i, j])
	# ramps: one lane with a verge and guardrail on the outside
	for x in [42, 43, 44, 47, 48, 49, 50]:
		G(x, 71, "snelweg/snelweg_aansluiting", "E")
		G(x, 70, "snelweg/snelweg_berm_vangrail", "E")
	# local road from the farm track to the ramps, T-junction at z 71
	for z in range(64, 71):
		G(45, z, "weg/rijstrook_geen_kant", "N")
		G(46, z, "weg/rijstrook_onderbroken_kant", "S")
	G(45, 71, "weg/kruising_vlak")
	G(46, 71, "weg/kruising_vlak")
	# signs: exit sign at the gore, give way at the end of the exit ramp, motorway at the on-ramp
	Pr(54 * 4, 72 * 4 + 3, "borden/bord_afrit", "E")
	Pr(47 * 4 + 1, 70 * 4 + 3, "borden/bord_voorrang_verlenen", "E")
	Pr(44 * 4 + 2, 70 * 4 + 3, "borden/bord_autosnelweg", "E")


## Gallery flat (galerijflat) beside the motorway, x 31..42: a storage plinth and 10
## floors of flats, two wings with a kink (the east wing one tile further north),
## galleries on the motorway side, balconies at the back, a stairwell with a lift
## housing at the west end and at the kink, entrances onto a car park reached from the
## junction road (x 45..46), allotments behind it.
const FLAT_FLOORS := 10


func _gallery_flat() -> void:
	var p := "galerijflat/galerijflat_"
	var cells := []
	for x in range(31, 37):
		cells.append(Vector2i(x, 66))
		cells.append(Vector2i(x, 67))
	for x in range(37, 43):
		cells.append(Vector2i(x, 65))
		cells.append(Vector2i(x, 66))
	var stairs := [Vector2i(31, 67), Vector2i(37, 66)]   # gallery-side cells with the stairwell
	var entrances := [Vector2i(33, 67), Vector2i(39, 66), Vector2i(41, 66)]
	for c in cells:
		var sides := _open_sides(c, cells)
		# the main facade: gallery south, balconies north, else the gable end
		var main: String = "S" if sides.has("S") else ("N" if sides.has("N") else sides[0])
		var key := _corner_pair(sides, main)
		var corner: bool = sides.size() == 2 and key != "" and CORNER.has(key) and key[0] == main
		for y in FLAT_FLOORS + 1:
			var piece := ""
			if y == 0:
				piece = "bg_entree" if c in entrances else "bg_bergingen"
			elif c in stairs:
				piece = "verd_trappenhuis"
			elif main == "S":
				piece = "verd_galerij"
			elif main == "N":
				piece = "verd_balkons"
			else:
				piece = "verd_kopgevel"
			if corner and piece in ["bg_entree", "bg_bergingen", "verd_galerij", "verd_balkons"]:
				B(c.x, y, c.y, p + piece + "_hoek", CORNER[key])
			else:
				B(c.x, y, c.y, p + piece, main)
	# flat roof (gravel) with lift housings over the stairwells
	var kit := _style_kit("galerijflat")
	var kinds := {}
	for k in kit.flat:
		kinds[k] = kit.flat[k].filter(func(nm): return nm.begins_with("dak_grind"))
	_flat_roofs(cells, "galerijflat", FLAT_FLOORS + 1, kinds, {})
	for c in stairs:
		B(c.x, FLAT_FLOORS + 1, c.y, p + "dak_liftopbouw", "S")
	# pavement along the galleries, car park in front, reached from the junction road
	for x in range(37, 43):
		G(x, 67, "stoep/stoep_rand", "S")
	for x in range(31, 45):
		G(x, 68, "parkeren/parkeerplaats_rijbaan", "E")
		G(x, 69, "parkeren/parkeervak_haaks" if x % 5 else "parkeren/parkeervak_laadpaal", "N")
	G(43, 68, "water/duiker", "E")
	G(43, 69, "natuur/gras")
	G(44, 69, "natuur/gras")
	for x in [45, 46]:
		G(x, 68, "weg/kruising_vlak")
	for x in [35, 40]:
		Pr(x * 4.0, 69 * 4 + 0.5, "paaltjes/laadpaal", "N")
	Pr(32 * 4 + 2, 68 * 4 - 1, "straat/afvalcontainer_ondergronds")
	Pr(38 * 4 + 2, 67 * 4 + 2, "fietsen/fietsenrek_vol", "S")
	Pr(42 * 4 + 2, 67 * 4 + 2, "verlichting/lantaarn_modern", "S")
	Pr(34 * 4 + 2, 68 * 4 - 1, "verlichting/lantaarn_modern", "S")
	# trees in the heath on the balcony side
	for x in [38, 41]:
		Pr(x * 4 + 2, 64 * 4 + 2, "bomen/populier")


## Farm with barns, fields, a ditch with culvert, woods, hills, commercial buildings
## and a castle tower (x 31..58, z 55..71).
func _farm_and_businesses() -> void:
	# farm with barns x 32..44, hills and ditches
	fill_rect(31, 55, 58, 71, "natuur/gras_hoog")
	block(33, 58, 4, 2, "schuur_zwart", 1, {"front": "S", "gf": ["bg_deur_groot", "bg_raam"], "gf_side": "bg_raam",
		"gf_corner": "bg_raam_hoek", "upper": ["verd_hooideur"], "roof": "sloped"})
	block(39, 58, 3, 2, "schuur_rood", 2, {"front": "S", "gf": ["bg_deur_groot", "bg_raam"], "gf_side": "bg_raam",
		"gf_corner": "bg_deur_groot_hoek", "upper": ["verd_hooideur"], "upper_corner": "bg_raam_hoek", "roof": "sloped"})
	fill_rect(33, 61, 41, 62, "natuur/grind")
	# farm track to the motorway junction road (x 45..46, see _motorway_junction)
	fill_rect(33, 63, 47, 63, "natuur/grind")
	# allotments and heath behind the gallery flat (_gallery_flat)
	fill_rect(31, 64, 36, 64, "natuur/moestuin")
	fill_rect(37, 64, 42, 64, "natuur/heide")
	column(43, 56, 67, "water/sloot")
	G(43, 63, "water/duiker")
	fill_rect(44, 56, 50, 62, "natuur/bos")
	for i in 6:
		Pr((45 + i) * 4, (57 + (i % 3) * 2) * 4, ["bomen/den", "bomen/berk", "bomen/eik", "bomen/den", "bomen/berk", "bomen/populier"][i])
	Pr(47 * 4, 61 * 4, "planten/struikgewas")
	# hills: grass, sand and gravel
	_hill(47, 64, "gras")
	G(51, 67, "heuvel/heuvel_zand_top")
	G(52, 67, "heuvel/heuvel_zand_helling", "W")
	G(54, 67, "heuvel/heuvel_grind_top")
	G(55, 67, "heuvel/heuvel_grind_helling", "W")
	fill_rect(50, 68, 56, 69, "natuur/zand")
	# commercial buildings with industrial fencing
	block(52, 57, 5, 3, "bedrijfspand", 2, {"front": "S", "gf": ["bg_roldeur", "bg_kantoor", "bg_roldeur"], "gf_side": "bg_dicht",
		"gf_corner": "bg_kantoor_hoek", "upper": ["verd_lichtstraat", "verd_logo"], "upper_corner": "verd_lichtstraat_hoek", "roof": "flat"})
	fill_rect(52, 60, 57, 62, "natuur/grind")
	for x in range(51, 58, 3):
		Pr(x * 4, 63 * 4 + 3, "hekken/hek_industrie", "S")
	Pr(58 * 4 - 3, 61 * 4, "hekken/schuifpoort_industrie", "E")
	Pr(54 * 4, 61 * 4 + 2, "straat/container_groot", "E")
	Pr(56 * 4, 61 * 4, "straat/bouwkeet")
	Pr(53 * 4, 60 * 4 + 2, "trappen/brandtrap", "S")
	Pr(57 * 4, 56 * 4 + 1, "trappen/trap_staal_spiraal")
	# castle tower with battlements
	tower(31, 61, "klassiek_donker", ["blok_dicht", "verd_raam", "verd_dicht", "dak_kantelen_toren"])


## Southeast x 63..95, z 55..71: boulevard with central tram stop, a road with median
## under a viaduct, luxury apartments, an office with roof types, green-roof houses,
## bus station and a sports hall.
func _southeast() -> void:
	fill_rect(64, 55, 95, 71, "natuur/gras")
	# wide boulevard (layout: = = + - - + = =): 2 lanes, pavement with stop, 2 tram tracks,
	# pavement with stop, 2 lanes; outer pavements at x=63 and x=72
	for z in range(55, 72):
		var at_stop := z >= 60 and z <= 63
		G(63, z, "stoep/stoep_rand", "E")
		G(64, z, "weg/rijstrook_onderbroken_kant", "N")
		G(65, z, "weg/rijstrook_geen_geen", "N")
		G(66, z, "tram/tramhalte_middenperron" if at_stop else "stoep/stoep_eiland", "S" if at_stop else "E")
		G(67, z, "tram/trambaan_vrij", "S")
		G(68, z, "tram/trambaan_vrij", "S")
		G(69, z, "tram/tramhalte_middenperron" if at_stop else "stoep/stoep_eiland", "S" if at_stop else "E")
		G(70, z, "weg/rijstrook_geen_geen", "S")
		G(71, z, "weg/rijstrook_onderbroken_kant", "S")
		G(72, z, "stoep/stoep_rand", "W")
		if not at_stop and z % 3 == 0:
			Pr(66 * 4 + 2, z * 4 + 2, "verlichting/lantaarn_dubbel", "E")
			Pr(69 * 4 + 2, z * 4 + 2, "verlichting/lantaarn_dubbel", "E")
			Pr(72 * 4 + 2, z * 4 + 2, "bomen/linde")
	for z in [60, 62]:
		Pr(66 * 4 + 2, z * 4 + 2, "ov/abri", "E", 0.5)
		Pr(69 * 4 + 2, z * 4 + 2, "ov/abri", "W", 0.5)
	Pr(66 * 4 + 2, 63 * 4 + 2, "ov/tramhalte_paal", "E", 0.5)
	Pr(69 * 4 + 2, 63 * 4 + 2, "ov/tramhalte_paal", "W", 0.5)
	for x in [66, 69]:
		Pr(x * 4 + 2, 55 * 4 + 1, "verkeer/verkeerszuil", "N")
		Pr(x * 4 + 2, 71 * 4 + 3, "verkeer/verkeerszuil_geel", "S")
	# road with median (z 63..65) passing under a viaduct
	for x in range(73, W):
		G(x, 63, "weg/rijstrook_geen_kant", "E")
		G(x, 64, "weg/middenberm_gras" if x % 5 else "weg/middenberm_klinkers", "E")
		G(x, 65, "weg/rijstrook_geen_kant", "W")
		if x % 4 == 0:
			Pr(x * 4 + 2, 64 * 4 + 2, "verlichting/lantaarn_middenberm", "S")
	# viaduct: road x 74,75 goes over the median road (at level 5)
	for i in range(5):
		G(74, 57 + i, "helling/helling_brug_weg_vlak", "N", i)
		G(75, 57 + i, "helling/helling_brug_weg_vlak_rand", "N", i)
		G(74, 67 + i, "helling/helling_brug_weg_vlak_rand", "S", 4 - i)
		G(75, 67 + i, "helling/helling_brug_weg_vlak", "S", 4 - i)
	for z in range(62, 67):
		G(74, z, "brug/brug_dek_weg_rand", "S", 5)
		G(75, z, "brug/brug_dek_weg_rand", "N", 5)
	for z in [62, 66]:
		for x in [74, 75]:
			_pier(x, z, "brug/brug_pijler_gras", 0, 4)
	for x in [74, 75]:
		G(x, 56, "weg/weg_vlak")
		G(x, 55, "weg/weg_vlak")
	# luxury apartments with roof terrace and penthouse (8 storeys) x 77..82, z 56..59
	block(77, 56, 6, 4, "luxe_appartement", 8, {"front": "N", "gf": ["bg_glas", "bg_lobby", "bg_glas"], "gf_side": "bg_glas",
		"gf_corner": "bg_glas_hoek", "upper": ["verd_terras", "verd_glas"], "upper_corner": "verd_terras_hoek", "roof": "none"})
	for x in range(77, 83):
		for z in range(56, 60):
			var e := _edge(_sides(x, z, 77, 56, 6, 4))
			B(x, 8, z, "luxe_appartement/luxe_appartement_penthouse_" + e[0], e[1])
	B(79, 9, 57, "luxe_appartement/luxe_appartement_dak_zwembad", "N")
	B(80, 9, 57, "luxe_appartement/luxe_appartement_dak_terras", "N")
	for x in range(77, 83):
		if x != 79 and x != 80:
			B(x, 9, 57, "luxe_appartement/luxe_appartement_dak_groen_midden", "S")
	# office with gravel, bitumen and green roof, cooling units and solar panels x 85..88, z 56..59
	block(85, 56, 4, 4, "kantoor_glas", 4, {"front": "N", "gf": ["bg_entree", "bg_glas"], "gf_side": "bg_glas", "gf_corner": "bg_glas_hoek",
		"upper": ["verd_raam_groot", "verd_vliesgevel"], "upper_corner": "verd_vliesgevel_hoek", "roof": "none"})
	for x in range(85, 89):
		for z in range(56, 60):
			var kind := "grind_midden" if x < 86 else ("bitumen_midden" if x < 87 else "groen_midden")
			B(x, 4, z, "kantoor_glas/kantoor_glas_dak_" + kind, "S")
	D(85 * 4 + 4.0, 57 * 4 + 2.0, 12.0, "dak/koelinstallatie", "S")
	D(86 * 4 + 4.0, 58 * 4.0, 12.0, "dak/zonnepanelen_schuin_rij", "S")
	D(86 * 4 + 4.0, 59 * 4 + 2.0, 12.0, "dak/zonnepanelen_schuin_rij", "S")
	D(85 * 4.0, 59 * 4 + 2.0, 12.0, "dak/luchtbehandeling", "E")
	# terraced houses with green roof x 77..88, z 68..69
	block(77, 68, 12, 2, "modern_hout", 2, {"front": "N", "gf": ["bg_deur", "bg_raam"], "gf_side": "bg_raam",
		"upper": ["verd_raam", "verd_raam_breed"], "roof": "none"})
	for x in range(77, 89):
		for z in [68, 69]:
			# 2 deep: every cell has an open side, so only edges and corners
			var e := _edge(_sides(x, z, 77, 68, 12, 2))
			B(x, 2, z, "modern_hout/modern_hout_dak_groen_" + e[0], e[1])
	# bus station with canopy x 90..95, z 56..61
	fill_rect(90, 55, 95, 61, "weg/weg_vlak")
	for x in range(90, 96):
		G(x, 57, "weg/busbaan_vrij" if x == 92 else "weg/rijstrook_bus_leeg", "E")
		B(x, 0, 59, "overkapping/overkapping_glas_kolom" if x % 3 == 0 else "overkapping/overkapping_glas", "S")
		G(x, 59, "tram/tram_halte_perron", "N")
	Pr(91 * 4, 59 * 4 + 2, "straat/bank_modern", "N")
	Pr(94 * 4, 59 * 4 + 2, "straat/bank_modern", "N")
	Pr(90 * 4, 60 * 4, "ov/bushalte_paal", "N")
	# sports hall x 90..95, z 66..70
	_hall(90, 66, 6, 5, "hal_sport", Vector2i(92, 66))
	D(92 * 4 + 2.0, 66 * 4.0, 3.0, "tekst/tekst_sporthal", "N")


## Motorway z 72..79 across the map, with Cross Street 2 descending into a tunnel
## under it (ramp z 60..65 down to level -6) and a cycle tunnel at x 13.
func _motorway_and_tunnel() -> void:
	# motorway z 72..79, with a tunnel for Cross Street 2 underneath
	for x in range(0, W):
		G(x, 72, "snelweg/snelweg_berm_vangrail", "E")
		G(x, 73, "snelweg/snelweg_vluchtstrook", "E")
		G(x, 74, "weg/weg_vlak", "E")
		G(x, 75, "snelweg/snelweg_rijstrook_links", "E")
		# grass central reservation in the west, concrete barrier where the junction is
		G(x, 76, "snelweg/snelweg_middenberm" if x < 30 else "snelweg/snelweg_middenberm_beton", "E")
		G(x, 77, "snelweg/snelweg_rijstrook_links", "W")
		G(x, 78, "weg/weg_vlak", "W")
		G(x, 79, "snelweg/snelweg_vluchtstrook", "W")
	for x in range(4, W, 10):
		Pr(x * 4, 76 * 4 + 2, "verlichting/lantaarn_middenberm", "E")
		if x < 34 or x > 58:   # not in the junction (_motorway_junction)
			Pr(x * 4 + 6, 72 * 4 + 3, "borden/hectometerpaal", "N")
	Pr(30 * 4, 74 * 4 + 2, "borden/snelweg_portaal", "E")
	Pr(70 * 4, 78 * 4 + 2, "borden/snelweg_portaal", "W")
	Pr(12 * 4, 72 * 4 + 2, "borden/bord_autosnelweg", "N")
	# eastbound: the hard shoulder becomes a deceleration lane (block marking) at x 86..92,
	# the exit leaves in row 80 behind a hatched gore at x 93..95 (towards an exit east of the map)
	for x in range(86, 93):
		G(x, 79, "snelweg/snelweg_blokmarkering", "W")
	for x in range(93, W):
		G(x, 79, "snelweg/snelweg_puntstuk", "W")
		G(x, 80, "snelweg/snelweg_aansluiting", "E")
	_motorway_junction()
	_gallery_flat()
	# Cross Street 2 continues to the tunnel: z 55..59 normal, ramp 60..65, open trough 66..71, tunnel 72..79.
	# Next to the carriageway (x 60,61) runs a cycle path (x 62) in the same trough.
	for z in range(55, 60):
		G(59, z, "stoep/stoep_rand", "E")
		G(60, z, "weg/rijstrook_geen_kant", "N")
		G(61, z, "weg/rijstrook_onderbroken_kant", "S")
		G(62, z, "fietspad/fietspad_recht")
		G(63, z, "stoep/stoep_vol")
	for d in range(1, 7):
		var z := 59 + d
		_trench(60, z, "tunnel/tunnel_toerit_wand_d%d" % d, d)
		_trench(61, z, "tunnel/tunnel_toerit_d%d" % d, d)
		_trench(62, z, "tunnel/fietstunnel_toerit_wand_rechts_d%d" % d, d)
		G(59, z, "stoep/stoep_vol")
		G(63, z, "stoep/stoep_vol")
	for z in range(66, 72):
		_trench(60, z, "tunnel/tunnelbak_rijstrook_wand_d6", 6)
		_trench(61, z, "tunnel/tunnelbak_rijstrook_d6", 6, "N")
		_trench(62, z, "tunnel/tunnelbak_fietspad_wand_rechts_d6", 6)
		G(59, z, "natuur/gras")
		G(63, z, "natuur/gras")
	G(60, 72, "tunnel/tunnel_rijstrook_wand_portaal", "S", -6)
	G(61, 72, "tunnel/tunnel_rijstrook_portaal", "N", -6)
	G(62, 72, "tunnel/tunnel_fiets_wand_rechts_portaal", "S", -6)
	for z in range(73, 80):
		G(60, z, "tunnel/tunnel_rijstrook_wand", "S", -6)
		G(61, z, "tunnel/tunnel_rijstrook", "N", -6)
		G(62, z, "tunnel/tunnel_fiets_wand_rechts", "S", -6)
	Pr(59 * 4, 59 * 4, "borden/bord_tunnel", "E")
	# cycle tunnel under the motorway at x=13 (ramp 6 layers deep, tunnel on layer -6)
	for d in range(1, 7):
		_trench(13, 65 + d, "tunnel/fietstunnel_toerit_wand_d%d" % d, d)
	G(13, 72, "tunnel/tunnel_fiets_wand_portaal", "N", -6)
	for z in range(73, 80):
		G(13, z, "tunnel/tunnel_fiets_wand", "S", -6)


## Footbridge on level 4 along x 95 (z 35..47) with stairs at both ends.
func _pedestrian_bridge() -> void:
	for i in range(4):
		G(95, 35 + i, "brug/loopbrug_trap", "N", i)
	for z in range(39, 47):
		G(95, z, "brug/loopbrug_open", "S", 4)
	G(95, 47, "brug/loopbrug_open", "E", 4)
	for i in range(4):
		G(94 - i, 47, "brug/loopbrug_trap", "W", 3 - i)
	for z in [39, 46]:
		for y in range(0, 4):
			G(95, z, "brug/loopbrug_pijler", "S", y)


## Buffer stops at the south end of the railway (z 30).
func _rail_end() -> void:
	for x in [33, 34]:
		G(x, 30, "spoor/trein_stootblok", "S")
	G(31, 30, "natuur/gras")


## Statues, square terraces, classic lanterns and extra flags throughout the town.
func _decoration() -> void:
	# statues
	Pr(21 * 4 + 2, 18 * 4 + 2, "standbeelden/ruiterstandbeeld", "S")
	Pr(64 * 4, 3 * 4, "standbeelden/obelisk")
	Pr(80 * 4, 11 * 4, "standbeelden/standbeeld_persoon", "S")
	Pr(90 * 4, 11 * 4 + 2, "standbeelden/kunstwerk_modern")
	Pr(39 * 4 + 2, 2 * 4 + 2, "standbeelden/buste", "E")
	# terrace on the old town square
	for i in 4:
		Pr((18 + i * 2) * 4, 25 * 4 + 2, ["terras/tafel_rond_stoelen", "terras/tafel_vierkant_stoelen"][i % 2])
		Pr((18 + i * 2) * 4 + 2, 25 * 4 + 2, ["terras/parasol_rood", "terras/parasol_groen", "terras/parasol_blauw", "terras/parasol_naturel"][i])
	Pr(26 * 4, 23 * 4, "terras/parasol_groot")
	Pr(26 * 4, 23 * 4 + 2, "terras/tafel_rond")
	Pr(25 * 4, 23 * 4 + 2, "terras/bistrostoel")
	# classic lanterns along the mansions and the museum
	for x in range(49, 59, 2):
		Pr(x * 4 + 2, 17 * 4 + 3, "verlichting/lantaarn_gietijzer", "N")
	for x in [64, 70]:
		Pr(x * 4 + 2, 11 * 4 + 2, "verlichting/lantaarn_klassiek_dubbel", "S")
	for x in [84, 88, 92]:
		Pr(x * 4 + 2, 3 * 4, "verlichting/lantaarn_bol")
	# extra flags at the town hall
	for i in 4:
		Pr((82 + i * 2) * 4, 11 * 4 + 3, ["straat/vlaggenmast_eu", "straat/vlaggenmast_amsterdam", "straat/vlaggenmast_rotterdam", "straat/vlaggenmast_transgender"][i], "S")


# ------------------------------------------------------------------ campus below the motorway (z 80..98)

## Campus below the motorway (z 80..98): Campus Lane, university with courtyard, college,
## two office towers with a footbridge at 36 m, and the shopping street.
func _campus() -> void:
	fill_rect(0, 80, 95, 98, "natuur/gras")
	# Campus Lane: pavement 81, lanes 82-83, pavement 84
	profile_x(0, 95, [[81, "stoep/stoep_rand", "S"], [82, "weg/rijstrook_onderbroken_kant", "E"], [83, "weg/rijstrook_geen_kant", "W"], [84, "stoep/stoep_rand", "N"]])
	for x in range(2, W, 6):
		Pr(x * 4, 84 * 4 + 3, "verlichting/lantaarn_modern", "N")
	# university: main building + two wings around a courtyard
	block(4, 86, 15, 2, "universiteit", 3, {"front": "N", "gf": ["bg_raam_boog"], "gf_side": "bg_raam_boog", "gf_corner": "bg_raam_boog_hoek",
		"upper": ["verd_raam", "verd_raam_hoog"], "upper_corner": "verd_raam_hoek", "roof": "flat"})
	B(11, 0, 86, "universiteit/universiteit_bg_portaal", "N")
	B(11, 3, 87, "universiteit/universiteit_dak_dakruiter", "S")
	block(4, 89, 2, 6, "universiteit", 2, {"front": "E", "gf": ["bg_raam_boog"], "gf_side": "bg_raam_boog", "gf_corner": "bg_raam_boog_hoek",
		"upper": ["verd_raam"], "upper_corner": "verd_raam_hoek", "roof": "sloped"})
	block(17, 89, 2, 6, "universiteit", 2, {"front": "W", "gf": ["bg_raam_boog"], "gf_side": "bg_raam_boog", "gf_corner": "bg_raam_boog_hoek",
		"upper": ["verd_raam"], "upper_corner": "verd_raam_hoek", "roof": "sloped"})
	fill_rect(7, 89, 15, 95, "natuur/gras_kort")
	column(11, 89, 95, "natuur/grindpad")
	row(7, 15, 92, "natuur/grindpad", "E")
	Pr(11 * 4 + 2, 92 * 4 + 2, "standbeelden/standbeeld_persoon", "N")
	D(11 * 4 + 2.0, 86 * 4.0, 7.0, "tekst/tekst_universiteit", "N")
	# college
	block(24, 86, 14, 6, "hogeschool", 5, {"front": "N", "gf": ["bg_glas", "bg_entree", "bg_kolonnade"], "gf_side": "bg_glas",
		"gf_corner": "bg_glas_hoek", "upper": ["verd_lamellen", "verd_vliesgevel", "verd_raam_groot"], "upper_corner": "verd_lamellen_hoek", "roof": "flat"})
	for x in range(26, 36, 3):
		B(x, 5, 89, "hogeschool/hogeschool_dak_zonnepanelen", "S")
	D(31 * 4.0, 86 * 4.0, 15.5, "tekst/tekst_hogeschool", "N")
	for x in range(25, 37, 3):
		Pr(x * 4, 85 * 4 + 2, "fietsen/fietsenrek_vol", "N")
	# two office towers with colonnade and a footbridge between them (at 36 m)
	for tx in [44, 54]:
		block(tx, 86, 4, 4, "kantoor_2000", 20, {"front": "N", "gf": ["bg_kolonnade", "bg_entree"], "gf_side": "bg_glas",
			"gf_corner": "bg_kolonnade_hoek", "upper": ["verd_zonwering", "verd_vliesgevel"], "upper_corner": "verd_zonwering_hoek", "roof": "flat"})
		D(tx * 4 + 6.0, 87 * 4 + 2.0, 60.0, "dak/koelinstallatie", "S")
		D(tx * 4 + 10.0, 88 * 4 + 2.0, 60.0, "dak/koelinstallatie", "S")
		D(tx * 4 + 8.0, 89 * 4 + 2.0, 60.0, "dak/luchtbehandeling", "S")
	block(48, 86, 6, 3, "kantoor_glas", 3, {"front": "N", "gf": ["bg_kolonnade"], "gf_side": "bg_glas", "gf_corner": "bg_kolonnade_hoek",
		"upper": ["verd_vliesgevel"], "upper_corner": "verd_vliesgevel_hoek", "roof": "flat"})
	for x in range(48, 54):
		G(x, 88, "brug/loopbrug_overdekt", "E", 36)
	fill_rect(44, 85, 57, 85, "plein/plein_natuursteen")
	for x in [45, 50, 55]:
		Pr(x * 4 + 2, 85 * 4 + 2, "standbeelden/kunstwerk_modern" if x == 50 else "planten/boombak")
	_shopping_street()


# ==================================================================
# DEMO DISTRICTS: every tile applied in a neighbourhood, building or situation
# ==================================================================

const DIR_OFFSET := {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "W": Vector2i(-1, 0), "E": Vector2i(1, 0)}

# packing cursor of _district: next free tile (x, z) and depth of the current row
var _wx := 2
var _wz := 0
var _wrow := 0
var _row := []        # districts of the current row: [origin, w, d, infill style]
var _street_h := {}   # Vector2i -> lane (0 north, 1 south) of the east-west streets
var _street_v := {}   # Vector2i -> lane (0 west, 1 east) of the north-south streets
var _city_blocks := 0 # counter for the styles of the in-between city blocks
var _pavement := {}   # Vector2i -> kerb variant ("", "goot_", "klinker_") of the pavement cells (_auto_kerbs)
var _kerb_count := 0  # counter for the kerb variant of the next block
var _special := {}    # street cells that are not ordinary lanes (roundabouts, avenues)
var _h_rows := []     # z of the north lane of every full-width east-west street
var _district_name := ""  # name recorded for the next _district call
var districts := []  # {name, x, z, w, d} per demo district, saved as scene metadata
var places := {}     # slug -> Vector2 (metres) of spots found while building, saved as scene metadata (tour stops)
var _detail_queue := {}   # group -> Array of names (queue)
var _prop_lists := {"street": [], "green": [], "water": []}  # kind -> prop names, filled from the library
var _prop_counter := {}  # kind -> round-robin index into _prop_lists


## Sorted names of all items in the library of gm that start with prefix.
func _names(gm: GridMap, prefix: String) -> Array:
	var result := []
	for id in gm.mesh_library.get_item_list():
		var nm := gm.mesh_library.get_item_name(id)
		if nm.begins_with(prefix):
			result.append(nm)
	result.sort()
	return result


## Tile name without group folder and style prefix, e.g. "jaren30/jaren30_bg_deur" -> "bg_deur".
func _short(style: String, nm: String) -> String:
	return nm.split("/")[nm.split("/").size() - 1].trim_prefix(style + "_")


## Claims a rectangle of w x d tiles for a demo district (named _district_name) in the
## current row, wrapping to a new row at the map edge, and records it in `districts`.
## Lays a kerb with grass inside; the streets around it (2 lanes, shared with the
## neighbours) and the buildings along them follow when the row is complete
## (_finish_row). Returns the north-west tile.
func _district(w: int, d: int) -> Vector2i:
	if _wx + w > W - 2:
		_finish_row()
	var o := Vector2i(_wx, _wz)
	districts.append({"name": _district_name, "x": o.x, "z": o.y, "w": w, "d": d})
	_row.append([o, w, d, _infill_style(_district_name)])
	_wx += w + 2
	_wrow = maxi(_wrow, d)
	_kerb_block(o.x, o.y, w, d)
	return o


## Pavement ring with grass inside over the block x0..x0+w-1, z0..z0+d-1.
func _kerb_block(x0: int, z0: int, w: int, d: int) -> void:
	_kerb_count += 1
	var variant: String = ["", "goot_", "klinker_"][_kerb_count % 3]
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d):
			var sides: Array = _sides(x, z, x0, z0, w, d)
			if sides.size() > 0:
				_pavement[Vector2i(x, z)] = variant
			if sides.size() == 0:
				G(x, z, "natuur/gras")
			elif sides.size() == 1:
				G(x, z, "stoep/stoep_rand", sides[0])
			elif sides.size() == 2 and _corner_pair(sides, "") != "":
				G(x, z, "stoep/stoep_hoek_buiten", CORNER[_corner_pair(sides, "")])
			else:
				G(x, z, "stoep/stoep_vol")   # a block one tile wide or deep


## Completes the current row of districts: the street along its north side and between
## the districts, a side street and a city block under districts shallower than the row,
## a city block in the space left at the east end, and buildings along the streets in
## every district. Moves the cursor to the next row.
func _finish_row() -> void:
	if _row.is_empty():
		return
	var top := _wz
	var bottom := _wz + _wrow   # first row below the districts
	_h_street(0, W - 1, top - 2)
	_h_rows.append(top - 2)
	for e in _row:
		var o: Vector2i = e[0]
		var w: int = e[1]
		var d: int = e[2]
		_v_street(o.x - 2, top - 2, bottom + 1)
		_line_streets(o.x, o.y, w, d, e[3])
		var left := _wrow - d
		if left >= 3:
			_h_street(o.x, o.x + w - 1, o.y + d)
			_filler_block(o.x, o.y + d + 2, w, left - 2)
		elif left > 0:
			_filler_block(o.x, o.y + d, w, left)
	_v_street(_wx - 2, top - 2, bottom + 1)
	if _wx < W:
		_filler_block(_wx, top, W - _wx, _wrow)
	_row.clear()
	_wz = bottom + 2
	_wx = 2
	_wrow = 0


## Cells of a 2-lane east-west street from x0 to x1 in rows z (westbound) and z+1.
func _h_street(x0: int, x1: int, z: int) -> void:
	for x in range(maxi(x0, 0), mini(x1, W - 1) + 1):
		_street_h[Vector2i(x, z)] = 0
		_street_h[Vector2i(x, z + 1)] = 1


## Cells of a 2-lane north-south street in columns x and x+1 from z0 to z1.
func _v_street(x: int, z0: int, z1: int) -> void:
	for z in range(z0, z1 + 1):
		for k in 2:
			if x + k >= 0 and x + k < W:
				_street_v[Vector2i(x + k, z)] = k


## Lays all recorded streets: lanes with markings, plain asphalt where streets cross,
## and street lights and trees on the pavements beside them.
func _paint_streets() -> void:
	var cells := {}
	for c in _street_h:
		cells[c] = true
	for c in _street_v:
		cells[c] = true
	for c in cells:
		if _street_h.has(c) and _street_v.has(c):
			G(c.x, c.y, "weg/kruising_vlak")
		elif _street_h.has(c):
			if _street_h[c] == 0:
				G(c.x, c.y, "weg/rijstrook_onderbroken_kant", "E")
			else:
				G(c.x, c.y, "weg/rijstrook_geen_kant", "W")
		elif _street_v[c] == 0:
			G(c.x, c.y, "weg/rijstrook_geen_kant", "N")
		else:
			G(c.x, c.y, "weg/rijstrook_onderbroken_kant", "S")
	# lights and trees on the pavement next to the kerb, alternating every 3 tiles
	var trees := ["bomen/linde", "bomen/plataan", "bomen/eik", "bomen/kastanje"]
	for c in cells:
		if _street_h.has(c) and _street_v.has(c):
			continue
		var side: Vector2i = Vector2i(0, -1) if _street_h.get(c, -1) == 0 else (Vector2i(0, 1) if _street_h.get(c, -1) == 1 else (Vector2i(-1, 0) if _street_v.get(c, -1) == 0 else Vector2i(1, 0)))
		var along: int = c.x if _street_h.has(c) else c.y
		if along % 3 != 0:
			continue
		var p: Vector2i = c + side
		if not _is_pavement(p) or _taken.has(p):
			continue
		var wx: float = p.x * 4 + 2.0 - side.x * 1.5
		var wz: float = p.y * 4 + 2.0 - side.y * 1.5
		var face: String = {Vector2i(0, -1): "S", Vector2i(0, 1): "N", Vector2i(-1, 0): "E", Vector2i(1, 0): "W"}[side]
		if along % 6 == 0:
			Pr(wx, wz, "verlichting/lantaarn_modern", face)
		else:
			Pr(wx, wz, trees[_r(p.x, p.y, trees.size())])


## True if ground cell p (level 0) is a pavement tile.
func _is_pavement(p: Vector2i) -> bool:
	var id := ground.get_cell_item(Vector3i(p.x, 0, p.y))
	return id >= 0 and ground.mesh_library.get_item_name(id).begins_with("stoep/")


## Two avenues from the campus road (z 82-83) down to the first street of the demo city
## (rows z0, z0+1), so the districts are part of the town: a lane each way with a
## pavement island (x 19..21) or a divider and a grass median (x 57..59) in the middle,
## pavements on both sides, and a roundabout where they meet the first city street.
func _connect_to_town(z0: int) -> void:
	for a in [[19, "island", ""], [57, "divider", "goot_"]]:
		var x: int = a[0]
		for z in [82, 83]:
			for k in 3:
				G(x + k, z, "weg/kruising_vlak")
		for z in range(84, z0 - 1):
			G(x, z, "weg/rijstrook_geen_kant", "N")
			G(x + 2, z, "weg/rijstrook_geen_kant", "S")
			_special[Vector2i(x, z)] = true
			_special[Vector2i(x + 2, z)] = true
			if z > 84:
				for side in [x - 1, x + 3]:
					G(side, z, "stoep/stoep_vol")
					_pavement[Vector2i(side, z)] = a[2]
				if z % 3 == 0:
					Pr(x * 4 - 2.5, z * 4 + 2.0, "verlichting/lantaarn_modern", "E")
					Pr((x + 3) * 4 + 2.5, z * 4 + 2.0, "verlichting/lantaarn_modern", "W")
		# the middle: from the campus road to the roundabout
		for z in range(84, z0 - 1):
			var c := Vector2i(x + 1, z)
			_special[c] = true
			if a[1] == "island":
				if z == 84:
					G(c.x, c.y, "weg/weg_vlak")
				else:
					G(c.x, c.y, "stoep/stoep_vol")
					_pavement[c] = a[2]
					if z % 4 == 2:
						Pr(c.x * 4 + 2.0, z * 4 + 2.0, "bomen/linde")
			else:
				var mid := "weg/middengeleider"
				var rot := "S"
				if z == 84:
					mid = "weg/middengeleider_kop"
					rot = "N"
				elif z < 89:
					mid = "weg/middengeleider"
				elif z < 92:
					mid = "weg/middengeleider_breed"
				elif z == 92:
					mid = "weg/middenberm_gras_kop"
					rot = "N"
				elif z == z0 - 2:
					mid = "weg/middenberm_gras_kop"
				else:
					mid = "weg/middenberm_gras"
				G(c.x, c.y, mid, rot)
		_roundabout(x + 1, z0, a[2])


## Roundabout of 3 x 3 cells around a round pavement island at (cx, cz): the avenue comes
## in from the north, the street of rows cz, cz+1 passes east-west.
func _roundabout(cx: int, cz: int, variant: String) -> void:
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var c := Vector2i(cx + dx, cz + dz)
			_special[c] = true
			if dx == 0 and dz == 0:
				G(c.x, c.y, "stoep/stoep_vol")
				_pavement[c] = variant
			else:
				G(c.x, c.y, "weg/weg_vlak")
	Pr(cx * 4 + 2.0, cz * 4 + 2.0, "planten/struik")


## Parking bays cut into the pavement on the north side of a city block (beside the
## eastbound lane of the street north of it): the pavement steps back one cell behind
## each bay; two bays with a strip of pavement between them where the block is wide.
func _parking_bays(x0: int, z0: int, w: int, d: int) -> void:
	if w < 8 or d < 5:
		return
	var kinds := ["parkeren/parkeerstrook_langs", "parkeren/parkeerstrook_langs_klinkers", "parkeren/parkeervak_klinkers", "weg/parkeerstrook"]
	var starts := [x0 + 2] if w < 12 else [x0 + 2, x0 + 6]
	for i in starts.size():
		var bx: int = starts[i]
		var kind: String = kinds[(_kerb_count + i) % kinds.size()]
		for x in range(bx, bx + 3):
			G(x, z0, kind, "W" if kind.begins_with("parkeren/parkeerstrook") or kind == "weg/parkeerstrook" else "S")
			_pavement.erase(Vector2i(x, z0))
			_taken[Vector2i(x, z0)] = true
			G(x, z0 + 1, "stoep/stoep_vol")
			_pavement[Vector2i(x, z0 + 1)] = _pavement.get(Vector2i(x0, z0), "")
			_taken[Vector2i(x, z0 + 1)] = true
	if starts.size() == 2:
		# the pavement between the two bays reaches back to the stepped-back pavement
		var gap := Vector2i(x0 + 5, z0 + 1)
		G(gap.x, gap.y, "stoep/stoep_vol")
		_pavement[gap] = _pavement.get(Vector2i(x0, z0), "")
		_taken[gap] = true


## Driveway from the street south of a city block into its courtyard: a lowered kerb (or
## a wide entrance / exit construction) in the pavement and a lane through a gap in the
## buildings to a few parking spaces in the courtyard.
func _driveway(x0: int, z0: int, w: int, d: int) -> void:
	if w < 6 or d < 7:
		return
	var x := x0 + w / 2
	var kerb: Vector2i = Vector2i(x, z0 + d - 1)
	var kind: String = ["stoep/stoep_oprit", "stoep/stoep_goot_oprit", "stoep/stoep_inrit_breed", "weg/uitritconstructie"][_kerb_count % 4]
	G(kerb.x, kerb.y, kind, "S")
	_pavement.erase(kerb)
	_taken[kerb] = true
	for z in range(z0 + d - 4, z0 + d - 1):
		G(x, z, "parkeren/parkeerplaats_rijbaan", "S")
		_taken[Vector2i(x, z)] = true
	for dx in [-1, 1]:
		G(x + dx, z0 + d - 4, "parkeren/parkeervak_haaks", "W" if dx < 0 else "E")
		_taken[Vector2i(x + dx, z0 + d - 4)] = true


## True if ground cell c (level 0) carries traffic: a road, tram, parking or motorway tile.
func _is_road(c: Vector2i) -> bool:
	var id := ground.get_cell_item(Vector3i(c.x, 0, c.y))
	if id < 0:
		return false
	var nm := ground.mesh_library.get_item_name(id)
	return nm.begins_with("weg/") or nm.begins_with("tram/") or nm.begins_with("parkeren/") or nm.begins_with("snelweg/")


## Pavement shapes (tools/voxgen/ground.py SIDEWALK_SHAPES): sides with road (Front,
## Right, Back, Left of the tile) and corners cut by road (FR = front-right, ...).
const KERB_SHAPES := [["vol", [], []], ["rand", ["F"], []], ["hoek_buiten", ["F", "R"], []], ["hoek_binnen", [], ["FR"]],
	["rand_hoek_binnen", ["F"], ["BR"]], ["dubbel_hoek_binnen", [], ["FR", "FL"]], ["eiland", ["F", "B"], []],
	["eiland_eind", ["F", "B", "R"], []], ["smal_eind", ["F", "R", "L"], []], ["eiland_rond", ["F", "R", "B", "L"], []]]


## Gives every pavement cell of the demo city the kerb shape its neighbours ask for: an
## edge towards each road, outer corners, inner corners where only a diagonal is road,
## islands and island ends, in the variant of its block (plain, gutter or clinker).
func _auto_kerbs() -> void:
	var dirs := {"S": Vector2i(0, 1), "E": Vector2i(1, 0), "N": Vector2i(0, -1), "W": Vector2i(-1, 0)}
	for c in _pavement:
		var id := ground.get_cell_item(Vector3i(c.x, 0, c.y))
		if id < 0 or not ground.mesh_library.get_item_name(id).begins_with("stoep/"):
			continue
		var road := {}
		for d in dirs:
			road[d] = _is_road(c + dirs[d])
		var options := []
		for shape in KERB_SHAPES:
			for k in 4:
				var side := {"F": ORDER[k], "R": ORDER[(k + 1) % 4], "B": ORDER[(k + 2) % 4], "L": ORDER[(k + 3) % 4]}
				var ok := true
				for d in dirs:
					var want := false
					for e in shape[1]:
						if side[e] == d:
							want = true
					if want != road[d]:
						ok = false
				if not ok:
					continue
				# diagonal cuts: a road diagonal with pavement on both sides next to it
				for pair in [["F", "R"], ["R", "B"], ["B", "L"], ["L", "F"]]:
					var a: String = side[pair[0]]
					var b: String = side[pair[1]]
					var cut: bool = not road[a] and not road[b] and _is_road(c + dirs[a] + dirs[b])
					var key: String = pair[0] + pair[1]
					var rkey: String = pair[1] + pair[0]
					var listed: bool = shape[2].has(key) or shape[2].has(rkey)
					if cut != listed:
						ok = false
				if ok:
					options.append([shape[0], k])
		if options.is_empty():
			# no exact shape (unusual cut): match the road sides only
			for shape in KERB_SHAPES:
				if not shape[2].is_empty():
					continue
				for k in 4:
					var side := {"F": ORDER[k], "R": ORDER[(k + 1) % 4], "B": ORDER[(k + 2) % 4], "L": ORDER[(k + 3) % 4]}
					var ok := true
					for d in dirs:
						var want := false
						for e in shape[1]:
							if side[e] == d:
								want = true
						if want != road[d]:
							ok = false
					if ok:
						options.append([shape[0], k])
		if options.is_empty():
			continue
		var pick: Array = options[_r(c.x, c.y, options.size())]
		var variant: String = _pavement[c]
		var nm: String = "stoep/stoep_" + variant + pick[0]
		if not _has(nm, ground):
			nm = "stoep/stoep_" + pick[0]
		G(c.x, c.y, nm, pick[1])


## Dresses the lanes of the demo city streets: every intersection gets a control on its
## north-south approaches (stop line with STOP, give-way teeth, zebra crossing with piano
## stripes) and turn arrows with block markings on its east-west approaches; every
## street section between two intersections gets a theme (bicycle street, cycle lanes,
## no overtaking, one-way with parking, old asphalt with a speed table, drains and
## manholes, other line types); one street carries a tram.
const STREET_THEMES := ["standaard", "fietsstraat", "fietsstroken", "inhaalverbod", "eenrichting", "oud", "lijnen", "fietsstrook", "klinkers"]
const ARROWS := ["rijstrook_pijl_rechtdoor", "rijstrook_pijl_links", "rijstrook_pijl_rechts", "rijstrook_pijl_rechtdoor_links", "rijstrook_pijl_rechtdoor_rechts"]


func _dress_streets() -> void:
	var inter := {}
	for c in _street_h:
		if _street_v.has(c):
			inter[c] = true
	var tram_row: int = _h_rows[mini(2, _h_rows.size() - 1)] if not _h_rows.is_empty() else -1
	var section := 0
	# sections: runs of non-intersection cells of a street's first lane
	for horizontal in [true, false]:
		var lanes: Dictionary = _street_h if horizontal else _street_v
		var cells := []
		for c in lanes:
			if lanes[c] == 0 and not inter.has(c) and not _special.has(c):
				cells.append(c)
		if horizontal:
			cells.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
		else:
			cells.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
		var run := []
		for i in cells.size() + 1:
			var c: Vector2i = cells[i] if i < cells.size() else Vector2i(-9999, -9999)
			var prev: Vector2i = run[-1] if not run.is_empty() else Vector2i(-9999, -9999)
			var step := Vector2i(1, 0) if horizontal else Vector2i(0, 1)
			if not run.is_empty() and c != prev + step:
				var theme: String = "tram" if horizontal and run[0].y == tram_row else STREET_THEMES[section % STREET_THEMES.size()]
				_dress_section(run, horizontal, theme, inter, section)
				section += 1
				run = []
			if i < cells.size():
				run.append(c)
	# the tram crosses the intersections of its street
	if tram_row >= 0:
		for c in inter:
			if c.y == tram_row or c.y == tram_row + 1:
				G(c.x, c.y, "tram/tram_recht", "E")
	# two busy intersections get traffic lights (all light types; green and amber north-south)
	var candidates := []
	for c in inter:
		if c.y == tram_row or c.y == tram_row + 1:
			continue
		if not (inter.has(c + Vector2i(1, 0)) and inter.has(c + Vector2i(0, 1)) and inter.has(c + Vector2i(1, 1))):
			continue
		var ok := true
		for i in [-4, -3, -2, -1, 2, 3, 4, 5]:
			for cell in [c + Vector2i(0, i), c + Vector2i(1, i), c + Vector2i(i, 0), c + Vector2i(i, 1)]:
				if inter.has(cell) or _special.has(cell) or not (_street_h.has(cell) or _street_v.has(cell)):
					ok = false
		if ok:
			candidates.append(c)
	candidates.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	if candidates.size() >= 2:
		var c1: Vector2i = candidates[candidates.size() / 3]
		var c2: Vector2i = candidates[candidates.size() * 2 / 3]
		_intersection_with_lights(c1.x, c1.y, "groen", "rood", "rijden", "stop", "groen", "rood")
		_intersection_with_lights(c2.x, c2.y, "oranje", "rood", "attentie", "stop", "oranje", "rood")
		# the 2 x 2 crossing cells start at c: its centre lies on the far corner of c
		places["verkeerslichten"] = Vector2(c1 + Vector2i.ONE) * 4.0
		places["verkeerslichten_2"] = Vector2(c2 + Vector2i.ONE) * 4.0


## Lane tiles of one street section (cells of its first lane, west to east or north to
## south; the second lane lies one cell south or east).
func _dress_section(run: Array, horizontal: bool, theme: String, inter: Dictionary, section: int) -> void:
	var n := run.size()
	var other := Vector2i(0, 1) if horizontal else Vector2i(1, 0)
	# lane 0: westbound (rotation E) or southbound (N); lane 1: eastbound (W) or northbound (S)
	var rot0 := "E" if horizontal else "N"
	var rot1 := "W" if horizontal else "S"
	for i in n:
		var c0: Vector2i = run[i]
		var c1: Vector2i = c0 + other
		var t0 := ""
		var t1 := ""
		var mid := i == n / 2
		match theme:
			"fietsstraat":
				t0 = "weg/fietsstraat"
				t1 = "weg/fietsstraat"
			"fietsstroken":
				t0 = "weg/rijstrook_fietsstrook"
				t1 = "weg/rijstrook_fietsstrook"
			"fietsstrook":
				t0 = "weg/fietsstrook"
				t1 = "weg/fietsstrook"
			"inhaalverbod":
				t0 = "weg/rijstrook_dubbel_kant" if i % 4 else "weg/rijstrook_dubbel_geen"
				t1 = "weg/rijstrook_dubbel_kant"
			"eenrichting":
				t0 = "weg/parkeervak_gehandicapt" if mid else "weg/parkeerstrook"
				t1 = "weg/straat_eenrichting" if i % 4 == 1 else "weg/weg_vlak"
			"oud":
				t0 = "weg/drempel_plateau" if mid else "weg/weg_vlak_oud"
				t1 = "weg/drempel_plateau" if mid else "weg/weg_vlak_oud"
			"lijnen":
				t0 = "weg/rijstrook_onderbroken_onderbroken" if i % 2 else "weg/rijstrook_streep_geen"
				t1 = "weg/rijstrook_geen_kant_onderbroken"
			"klinkers":
				t0 = "weg/straat_klinkers_middengoot" if mid else "weg/straat_klinkers"
				t1 = "weg/kruis_markering" if mid else "weg/straat_klinkers"
			"tram":
				var v := section % 3
				t0 = ["tram/tram_rijstrook_onderbroken_kant", "tram/tram_rijstrook_dubbel_kant", "tram/tram_rijstrook_streep_kant"][v]
				t1 = ["tram/tram_rijstrook_geen_kant", "tram/tram_rijstrook_geen_geen", "tram/tram_rijstrook_onderbroken_geen"][v]
			_:
				if mid:
					t0 = "weg/weg_putdeksel"
					t1 = "weg/weg_kolk"
		if t0 != "":
			G(c0.x, c0.y, t0, rot0)
		if t1 != "":
			G(c1.x, c1.y, t1, rot1)
	if theme in ["tram", "eenrichting", "fietsstraat"]:
		return
	# approaches: lane 0 drives towards +x/+z... (west/south): its last cell in driving
	# direction is run[0] - step for westbound, run[-1] for southbound; lane 1 the other way
	var step := Vector2i(1, 0) if horizontal else Vector2i(0, 1)
	var ends := []
	if horizontal:
		ends = [[run[0], rot0, run[0] - step, run[0] + step], [run[-1] + other, rot1, run[-1] + other + step, run[-1] + other - step]]
	else:
		ends = [[run[-1], rot0, run[-1] + step, run[-1] - step], [run[0] + other, rot1, run[0] + other - step, run[0] + other + step]]
	for e in ends:
		var cell: Vector2i = e[0]
		if not inter.has(e[2]) or n < 2:
			continue
		var before: Vector2i = e[3]
		var kind := _r(e[2].x, e[2].y, 4)
		if horizontal:
			G(cell.x, cell.y, "weg/" + ARROWS[(section + (0 if e[1] == rot0 else 2)) % ARROWS.size()], e[1])
			if n >= 3:
				G(before.x, before.y, "weg/rijstrook_blok_kant" if e[1] == rot0 else "weg/rijstrook_blok_geen", e[1])
		elif kind == 0:
			G(cell.x, cell.y, "weg/rijstrook_stopstreep", e[1])
			if n >= 3:
				G(before.x, before.y, "weg/rijstrook_stop_tekst", e[1])
		elif kind == 1:
			G(cell.x, cell.y, "weg/rijstrook_haaientanden", e[1])
		elif kind == 2:
			G(cell.x, cell.y, "weg/zebrapad", e[1])
			if n >= 3:
				G(before.x, before.y, "weg/pianostrepen", e[1])


# ------------------------------------------------------------------ city blocks and buildings along the streets

## Districts that stay open (no buildings along their streets): the structures in them
## need to be seen from the street.
const OPEN_DISTRICTS := ["keerlussen", "viaductbochten"]


## Residential style for the buildings along the streets of a district: the district's
## own style where that makes a street (houses, flats, offices, industry), else a
## residential style that changes from block to block.
func _infill_style(district: String) -> String:
	if district in OPEN_DISTRICTS:
		return ""
	var own := district.trim_prefix("stijl:")
	if district.begins_with("stijl:") and not (own.begins_with("kerk") or own.begins_with("museum") or own in
			["universiteit", "hogeschool", "school", "overheid", "schuur_rood", "schuur_zwart"]):
		return own
	var styles := ["herenhuis_1900", "jaren30", "klassiek_rood", "modern_wit", "jaren60", "klassiek_geel", "modern_hout", "appartement_modern"]
	_city_blocks += 1
	return styles[_city_blocks % styles.size()]


## A block of the city between the demo districts: kerb, buildings along the streets
## and a garden in the middle.
func _filler_block(x0: int, z0: int, w: int, d: int) -> void:
	if w <= 0 or d <= 0:
		return
	if w > 16:
		var half := w / 2 - 1
		_v_street(x0 + half, z0, z0 + d - 1)
		_filler_block(x0, z0, half, d)
		_filler_block(x0 + half + 2, z0, w - half - 2, d)
		return
	if d > 16:
		var half := d / 2 - 1
		_h_street(x0, x0 + w - 1, z0 + half)
		_filler_block(x0, z0, w, half)
		_filler_block(x0, z0 + half + 2, w, d - half - 2)
		return
	_kerb_block(x0, z0, w, d)
	_parking_bays(x0, z0, w, d)
	_driveway(x0, z0, w, d)
	_line_streets(x0, z0, w, d, _infill_style(""))


## Buildings along the streets of the block x0..x0+w-1, z0..z0+d-1 (inside its kerb):
## a band two cells deep wherever it and one cell behind it are still empty, in runs of
## at least 3 cells; built as one perimeter block in `style` (facades all round, flat
## or sloped roofs), with a back garden behind it.
func _line_streets(x0: int, z0: int, w: int, d: int, style: String) -> void:
	if style == "":
		return
	var inner := Rect2i(x0 + 1, z0 + 1, w - 2, d - 2)
	if inner.size.x < 3 or inner.size.y < 3:
		return
	var band := {}
	# the four sides: (first cell, step along the side, step inwards)
	var sides := [[inner.position, Vector2i(1, 0), Vector2i(0, 1), inner.size.x],
		[Vector2i(inner.position.x, inner.end.y - 1), Vector2i(1, 0), Vector2i(0, -1), inner.size.x],
		[inner.position, Vector2i(0, 1), Vector2i(1, 0), inner.size.y],
		[Vector2i(inner.end.x - 1, inner.position.y), Vector2i(0, 1), Vector2i(-1, 0), inner.size.y]]
	for sd in sides:
		var run := []
		for k in sd[3] + 1:
			var c: Vector2i = sd[0] + sd[1] * k
			var ok: bool = k < sd[3]
			if ok:
				for depth in 3:
					var q: Vector2i = c + sd[2] * depth
					if not inner.has_point(q) or _taken.has(q):
						ok = false
			if ok:
				run.append(c)
			else:
				if run.size() >= 3:
					for rc in run:
						band[rc] = true
						band[rc + sd[2]] = true
				run = []
	if band.is_empty():
		return
	var cells := band.keys()
	var kit := _style_kit(style)
	var floors := mini(_floors_for(style), 4)
	var counter := {}
	_facades(cells, style, floors, kit.gf, kit.upper, kit.gf_corners, kit.upper_corners, counter)
	_roof(cells, style, floors, kit, counter)
	# back gardens: short grass behind the band
	for c in cells:
		for dir in DIR_OFFSET.values():
			var q: Vector2i = c + dir
			if inner.has_point(q) and not band.has(q) and not _taken.has(q):
				G(q.x, q.y, "natuur/gras_kort")


## The tiles of a building style sorted by role (names without the style prefix): ground
## and upper floor facades with their corners, flat roof kinds and sloped roofs.
func _style_kit(style: String) -> Dictionary:
	var kit := {"gf": [], "gf_corners": [], "upper": [], "upper_corners": [],
		"flat": {"midden": [], "rand": [], "hoek": [], "tegenover": [], "eind": [], "los": []}, "sloped": [], "outer": []}
	for nm in _names(buildings, style + "/"):
		var k := _short(style, nm)
		if k.begins_with("bg_"):
			kit[("gf_corners" if k.contains("hoek") else "gf")].append(k)
		elif k.begins_with("verd_"):
			kit[("upper_corners" if k.contains("hoek") else "upper")].append(k)
		elif k.begins_with("dak_schuin") and not k.contains("hoek_binnen"):
			kit[("outer" if k.contains("hoek_buiten") else "sloped")].append(k)
		elif k.begins_with("dak_plat") or k.begins_with("dak_bitumen") or k.begins_with("dak_grind"):
			for e in ["rand", "hoek", "tegenover", "eind", "los"]:
				if k.ends_with("_" + e):
					kit.flat[e].append(k)
					break
			if k.ends_with("_midden"):
				kit.flat.midden.append(k)
	return kit


## Roof on storey y over a set of cells: flat if the style has flat roofs, else sloped
## (outer corner tiles on the corners, slopes facing the open side).
func _roof(cells: Array, style: String, y: int, kit: Dictionary, counter: Dictionary) -> void:
	if not kit.flat.midden.is_empty():
		# one roof family (dak_plat, dak_grind, ...) for the whole building
		var mid: String = kit.flat.midden[_r(cells[0].x, cells[0].y, kit.flat.midden.size())]
		var fam := mid.trim_suffix("_midden") + "_"
		var kinds := {}
		for k in kit.flat:
			kinds[k] = []
			for nm in kit.flat[k]:
				if nm.begins_with(fam):
					kinds[k].append(nm)
		_flat_roofs(cells, style, y, kinds, counter)
		return
	if kit.sloped.is_empty():
		return
	var p := style + "/" + style + "_"
	for c in cells:
		var sides := _open_sides(c, cells)
		if sides.is_empty():
			B(c.x, y, c.y, p + kit.sloped[0], "S")
			continue
		var key := _corner_pair(sides, "N")
		if key != "" and sides.size() >= 2 and not kit.outer.is_empty():
			B(c.x, y, c.y, p + _next(kit.outer, counter, "outer"), CORNER[key])
		else:
			B(c.x, y, c.y, p + _next(kit.sloped, counter, "slope"), sides[0])


## Facades for an arbitrary set of cells (Array of Vector2i tiles), `floors` storeys from
## storey y0. Exposure is relative to the set itself; corner cells use the corner lists.
## Tiles are taken round-robin from the lists using `counter` (shared across calls).
func _facades(cells: Array, style: String, floors: int, gf: Array, upper: Array, gf_corners: Array, upper_corners: Array, counter: Dictionary, y0 := 0) -> void:
	var p := style + "/" + style + "_"
	var cell_set := {}
	for c in cells:
		cell_set[c] = true
	for c in cells:
		var sides := _open_sides(c, cell_set)
		var key := _corner_pair(sides, "N")
		for v in range(floors):
			# counters are kept separately for the ground floor (0) and upper floors (1)
			var level := mini(v, 1)
			var tile_name := "blok_dicht"
			var rot = "S"
			if sides.size() == 0:
				pass  # interior cell: closed block
			elif key == "" or sides.size() == 1:
				var list: Array = gf if v == 0 else upper
				if list.size() > 0:
					tile_name = _next(list, counter, "f%d" % level)
				rot = sides[0]
			else:
				var list: Array = gf_corners if v == 0 else upper_corners
				if list.size() > 0:
					tile_name = _next(list, counter, "c%d" % level)
				rot = CORNER[key]
			B(c.x, y0 + v, c.y, p + tile_name, rot)


## Flat roofs on storey y over a set of cells. kinds maps an edge kind (see _edge) to a list
## of tile names (without style prefix); variants alternate per kind via `counter`.
func _flat_roofs(cells: Array, style: String, y: int, kinds: Dictionary, counter: Dictionary) -> void:
	var p := style + "/" + style + "_"
	var cell_set := {}
	for c in cells:
		cell_set[c] = true
	for c in cells:
		var e := _edge(_open_sides(c, cell_set))
		var kind: String = e[0]
		# missing kinds fall back to an edge tile, then to a middle tile
		var list: Array = kinds.get(kind, [])
		if list.is_empty() and kind in ["tegenover", "eind", "los"]:
			list = kinds.get("rand", [])
		if list.is_empty():
			list = kinds.get("midden", [])
		if list.is_empty():
			continue
		B(c.x, y, c.y, p + _next(list, counter, kind), e[1])


## Number of storeys used for a style in its demo neighbourhood (default 3).
func _floors_for(style: String) -> int:
	var t := {"jaren30": 4, "jaren60": 2, "galerijflat": 6, "appartement_modern": 8, "luxe_appartement": 6,
		"kantoor_glas": 6, "kantoor_beton": 6, "kantoor_80": 7, "kantoor_2000": 8, "kantoor_modern": 6, "hogeschool": 4,
		"school": 2, "museum_klassiek": 2, "museum_modern": 2, "bedrijfspand": 2, "schuur_zwart": 2, "schuur_rood": 2,
		"kerk_baksteen": 2, "kerk_steen": 3, "kerk_modern": 2}
	return t.get(style, 3)


## Builds all demo districts starting at tile row z0 and returns the first z below them.
## First sorts the detail and prop libraries into queues used to dress the districts.
func _demo_districts(z0: int) -> int:
	_wx = 2
	_wz = z0 + 2
	_wrow = 0
	# queues for details and props
	for nm in _names(details, ""):
		var g: String = nm.split("/")[0]
		if not _detail_queue.has(g):
			_detail_queue[g] = []
		_detail_queue[g].append(nm)
	for nm in _names(props, ""):
		var g: String = nm.split("/")[0]
		if g in ["bomen", "planten", "speeltuin"]:
			_prop_lists["green"].append(nm)
		elif g in ["water", "zwembad"]:
			_prop_lists["water"].append(nm)
		else:
			_prop_lists["street"].append(nm)
	# one neighbourhood per building style
	var styles := []
	for nm in _names(buildings, ""):
		var st: String = nm.split("/")[0]
		if not styles.has(st) and not st in ["daken", "hallen", "overkapping", "pilaren", "parkeergarage", "overig"]:
			styles.append(st)
	for st in styles:
		_district_name = "stijl:" + st
		_style_neighbourhood(st)
	_roofs_district()
	_halls_and_misc()
	_industrial_estate()
	_tint_demo()
	_curves()
	_village_centre()
	_loops_and_rail()
	_dike_with_ramps()
	_tunnel_park()
	_slopes_and_curves()
	_flyovers()
	_canal_with_bridges()
	_nature_park()
	_finish_row()
	_h_street(0, W - 1, _wz - 2)
	_paint_streets()
	_dress_streets()
	_connect_to_town(z0)
	_auto_kerbs()
	_green_up(z0, _wz)
	# every tile must be in the town somewhere: report the ones that are not
	for gm in [ground, buildings, details, props]:
		var unused := _unused_list(gm)
		if not unused.is_empty():
			push_warning("NOT IN THE TOWN (%s): %s" % [gm.name, unused])
	return _wz


## Trees and shrubs on about 9% of the empty lawn cells between rows z0 and z1.
func _green_up(z0: int, z1: int) -> void:
	var grass_id := ground.mesh_library.find_item_by_name("natuur/gras")
	var trees := ["bomen/linde", "bomen/eik", "bomen/berk", "bomen/kastanje", "bomen/plataan", "planten/struik", "planten/bosje_klein", "bomen/bloesemboom"]
	for x in range(0, W):
		for z in range(z0, z1):
			if ground.get_cell_item(Vector3i(x, 0, z)) != grass_id:
				continue
			if buildings.get_cell_item(Vector3i(x, 0, z)) != GridMap.INVALID_CELL_ITEM:
				continue
			if _r(x * 3, z * 7, 100) < 9:
				Pr(x * 4 + 2.0, z * 4 + 2.0, trees[_r(x, z, trees.size())])


# ------------------------------------------------------------------ neighbourhood per building style

## Demo neighbourhood for one building style: sorts all tiles of the style by kind
## (ground floors, upper floors, roofs, tops, towers, specials) and builds block A (all
## facades and flat or sloped roofs), a second row with courtyard ring, gable and T roofs,
## small rows, narrow buildings with each top, towers and special roofs, plus a detail building.
func _style_neighbourhood(style: String) -> void:
	var p := style + "/" + style + "_"
	var gf := []
	var gf_corners := []
	var upper := []
	var upper_corners := []
	var flat_kinds := {"midden": [], "rand": [], "hoek": [], "tegenover": [], "eind": [], "los": []}
	var sloped := []
	var outer_corners := []
	var inner_corners := []
	var gable := []
	var gable_hip := []
	var gable_corner := []
	var gable_t := []
	var tops := []
	var tower := []
	var penthouse := {}
	var special := []
	# sort the tiles of the style by role (names without the style prefix)
	for nm in _names(buildings, style + "/"):
		var k := _short(style, nm)
		if k == "blok_dicht":
			continue
		if k.begins_with("bg_"):
			(gf_corners if k.contains("hoek") else gf).append(k)
		elif k.begins_with("verd_"):
			(upper_corners if k.contains("hoek") else upper).append(k)
		elif k.begins_with("toren_"):
			tower.append(k)
		elif k.begins_with("penthouse_"):
			penthouse[k.trim_prefix("penthouse_")] = k
		elif k.begins_with("gevel_") or k.begins_with("top_"):
			tops.append(k)
		elif k.contains("koepel") or k.contains("dakruiter") or k.contains("overstek") or k.contains("liftopbouw") or k == "luchtboog":
			special.append(k)
		elif k.begins_with("dak_schuin") or k == "dak_lessenaar" or k == "dak_piramide":
			if k.contains("hoek_buiten"):
				outer_corners.append(k)
			elif k.contains("hoek_binnen"):
				inner_corners.append(k)
			else:
				sloped.append(k)
		elif k.begins_with("dak_zadel"):
			if k.contains("schild"):
				gable_hip.append(k)
			elif k.contains("hoek"):
				gable_corner.append(k)
			elif k.ends_with("_t"):
				gable_t.append(k)
			else:
				gable.append(k)
		elif k.begins_with("dak_"):
			# flat roof: the edge kind is part of the name (dak_plat_rand, dak_x_hoek_y, ...)
			var kind := "midden"
			for s in ["rand", "hoek", "tegenover", "eind", "los"]:
				if k.ends_with("_" + s) or k.contains("_" + s + "_"):
					kind = s
			if k.contains("terras") or k.contains("zwembad") or k.contains("daktuin"):
				kind = "rand"
			if k == "dak_kantelen_toren":
				kind = "los"
			flat_kinds[kind].append(k)
		else:
			special.append(k)
	var floors := _floors_for(style)
	var has_flat: bool = not (flat_kinds["midden"].is_empty() and flat_kinds["rand"].is_empty())
	var has_sloped := not sloped.is_empty()
	# block A: wide enough to show every ground/upper floor variant on its front, and deep
	# enough (with flat roofs) to show every middle roof variant in its interior
	var nA := clampi(maxi(ceili(gf.size() / 2.0), ceili(upper.size() / 1.5)), 5, 14)
	var dA := 2
	if has_flat:
		dA = 2 + maxi(1, ceili(flat_kinds["midden"].size() / float(maxi(1, nA - 2))))
	# compute the width of the second row
	var row2 := 0
	if has_sloped and not inner_corners.is_empty():
		row2 += 6
	if not gable.is_empty() or not gable_hip.is_empty():
		row2 += 4
	if not gable_t.is_empty():
		row2 += 4
	row2 += 5                                  # small row for end/opposite/single
	row2 += tops.size() + 1
	if not tower.is_empty():
		row2 += 3
	row2 += special.size() * 2
	var w := maxi(nA + 6, mini(row2 + 2, 60)) + 2
	# depth: margin, block A, gardens, second row, detail building, extra sloped row if needed
	var d := 2 + dA + 2 + 5 + 2 + 3 + 1 + (3 if has_sloped and inner_corners.is_empty() else 0)
	var o := _district(w, d)
	var cx := o.x + 1
	var cz := o.y + 1
	# one shared counter, so consecutive buildings keep cycling through the variants
	var counter := {}
	var facades := func(cs: Array, n: int) -> void:
		_facades(cs, style, n, gf, upper, gf_corners, upper_corners, counter)
	# --- block A: front facing north (street), gardens at the back
	var cells := []
	for x in range(cx + 1, cx + 1 + nA):
		for z in range(cz + 1, cz + 1 + dA):
			cells.append(Vector2i(x, z))
	facades.call(cells, floors)
	var roof_y := floors
	if not penthouse.is_empty():
		# penthouse storey on top of block A (only the kinds the style has)
		var pt := {"rand": [penthouse.get("rand", "")], "hoek": [penthouse.get("hoek", "")], "tegenover": [penthouse.get("tegenover", "")], "midden": [penthouse.get("midden", "")]}
		for k in pt.keys():
			if pt[k][0] == "":
				pt.erase(k)
		_flat_roofs(cells, style, roof_y, pt, {})
		roof_y += 1
	if has_flat:
		_flat_roofs(cells, style, roof_y, flat_kinds, counter)
	elif has_sloped:
		for c in cells:
			var sides := _open_sides(c, cells)
			var key := _corner_pair(sides, "N")
			if key != "" and sides.size() >= 2:
				var nm := _next(outer_corners, counter, "outer")
				B(c.x, roof_y, c.y, p + (nm if nm != "" else sloped[0]), CORNER[key])
			else:
				B(c.x, roof_y, c.y, p + _next(sloped, counter, "slope"), sides[0])
	# gardens behind block A
	var zt := cz + 1 + dA
	fill_rect(cx + 1, zt, cx + nA, zt + 1, "natuur/gras_kort")
	for x in range(cx + 1, cx + 1 + nA):
		_prop(x * 4 + 2.0, (zt + 2) * 4 - 0.5, "green")
	# a residential street (woonerf, clinkers) right through the district: the second
	# row of buildings stands along it, joined to the streets west and east
	for x in range(o.x, o.x + w):
		G(x, zt + 2, "weg/straat_klinkers", "E")
		_pavement.erase(Vector2i(x, zt + 2))
		_taken[Vector2i(x, zt + 2)] = true
	Pr((o.x + 1) * 4.0 + 1.0, (zt + 2) * 4.0 - 0.5, "borden/bord_woonerf", "E")
	# --- second row: courtyard, gable roofs, row, tops, tower, specials
	var rx := cx + 1
	var rz := cz + dA + 4
	if has_sloped and not inner_corners.is_empty():
		var ring_cells := []
		for x in range(rx, rx + 5):
			for z in range(rz, rz + 5):
				if x == rx + 2 and z == rz + 2:
					continue
				ring_cells.append(Vector2i(x, z))
		var yr := maxi(1, mini(floors, 3))
		facades.call(ring_cells, yr)
		for c in ring_cells:
			var sides := _open_sides(c, ring_cells)
			if sides.size() == 0:
				# inner corner (diagonal to the courtyard): valley piece turned towards it
				var dx: int = (rx + 2) - c.x
				var dz: int = (rz + 2) - c.y
				var dk: String = ("S" if dz > 0 else "N") + ("E" if dx > 0 else "W")
				var map := {"SE": "SE", "SW": "WS", "NE": "EN", "NW": "NW"}
				B(c.x, yr, c.y, p + _next(inner_corners, counter, "inner"), CORNER[map[dk]])
			elif sides.size() >= 2:
				B(c.x, yr, c.y, p + _next(outer_corners, counter, "outer"), CORNER[_corner_pair(sides, "")])
			else:
				B(c.x, yr, c.y, p + _next(sloped, counter, "slope"), sides[0])
		G(rx + 2, rz + 2, "natuur/gras_bloemen")
		_prop((rx + 2) * 4 + 2.0, (rz + 2) * 4 + 2.0, "green")
		rx += 5
	if not gable.is_empty() or not gable_hip.is_empty():
		# L shape (1 deep) with gable roofs, hipped ends and an L corner
		var lc := [Vector2i(rx, rz + 2), Vector2i(rx + 1, rz + 2), Vector2i(rx + 2, rz + 2), Vector2i(rx + 2, rz + 1), Vector2i(rx + 2, rz)]
		facades.call(lc, 1)
		var zs: String = gable_hip[0] if not gable_hip.is_empty() else gable[0]
		var zz: String = gable[counter.get("gable", 0) % gable.size()] if not gable.is_empty() else zs
		B(rx, 1, rz + 2, p + zs, "N")
		B(rx + 1, 1, rz + 2, p + zz, "S")
		B(rx + 2, 1, rz + 2, p + (gable_corner[0] if not gable_corner.is_empty() else zz), "SE")
		B(rx + 2, 1, rz + 1, p + (gable[1 % gable.size()] if not gable.is_empty() else zs), "E")
		B(rx + 2, 1, rz, p + zs, "E")
		# remaining gable variants on a separate row of 3
		var extra := gable.slice(2) if gable.size() > 2 else []
		var zr := rz + 4
		if not extra.is_empty():
			var rc := [Vector2i(rx, zr), Vector2i(rx + 1, zr), Vector2i(rx + 2, zr)]
			facades.call(rc, 1)
			B(rx, 1, zr, p + zs, "N")
			B(rx + 1, 1, zr, p + extra[0], "S")
			B(rx + 2, 1, zr, p + zs, "S")
		rx += 3
	if not gable_t.is_empty():
		var tc := [Vector2i(rx, rz + 1), Vector2i(rx + 1, rz + 1), Vector2i(rx + 2, rz + 1), Vector2i(rx + 1, rz)]
		facades.call(tc, 1)
		var zs2: String = gable_hip[0] if not gable_hip.is_empty() else gable_t[0]
		B(rx + 1, 1, rz + 1, p + gable_t[0], "S")
		B(rx, 1, rz + 1, p + zs2, "N")
		B(rx + 2, 1, rz + 1, p + zs2, "S")
		B(rx + 1, 1, rz, p + zs2, "E")
		rx += 3
	if has_sloped and inner_corners.is_empty():
		var sc := []
		var bw := maxi(2, ceili(sloped.size() / 2.0) + 2)
		for x in range(rx, rx + bw):
			for z in [rz, rz + 1]:
				sc.append(Vector2i(x, z))
		facades.call(sc, 1)
		var si := 0
		for c in sc:
			var sides := _open_sides(c, sc)
			if sides.size() >= 2 and not outer_corners.is_empty():
				B(c.x, 1, c.y, p + outer_corners[0], CORNER[_corner_pair(sides, "")])
			else:
				B(c.x, 1, c.y, p + sloped[si % sloped.size()], sides[0] if sides.size() == 1 else "N")
				si += 1
		rx += bw
	# small row (1 deep) + detached building: end / opposite / single
	var kc := [Vector2i(rx, rz), Vector2i(rx + 1, rz), Vector2i(rx + 2, rz)]
	var ky := maxi(1, mini(floors, 2))
	facades.call(kc, ky)
	if not penthouse.is_empty():
		var pt2 := {}
		for k2 in penthouse.keys():
			pt2[k2] = [penthouse[k2]]
		_flat_roofs(kc, style, ky, pt2, {})
		ky += 1
	if has_flat:
		_flat_roofs(kc, style, ky, flat_kinds, counter)
	facades.call([Vector2i(rx, rz + 2)], 1)
	if has_flat:
		_flat_roofs([Vector2i(rx, rz + 2)], style, 1, flat_kinds, counter)
	rx += 3
	# narrow buildings, each with a different top (canal gable, cornice gable, pediment, ...)
	for i in tops.size():
		var x: int = rx + i
		var hc := [Vector2i(x, rz), Vector2i(x, rz + 1)]
		var yt := maxi(2, mini(floors, 3))
		facades.call(hc, yt)
		B(x, yt, rz, p + tops[i], "N")
		if not gable.is_empty():
			B(x, yt, rz + 1, p + gable[0], "E")
		elif has_flat:
			B(x, yt, rz + 1, p + flat_kinds["rand"][0] if not flat_kinds["rand"].is_empty() else p + flat_kinds["midden"][0], "S")
	if not tops.is_empty():
		rx += tops.size()
	# tower(s)
	if not tower.is_empty():
		var order := ["toren_portaal", "toren_raam", "toren_galmgat", "toren_klok", "toren_spits_onder", "toren_spits_boven"]
		var t1 := []
		for t in order:
			if tower.has(t):
				t1.append(t)
		if t1.is_empty() or not t1[0] in ["toren_portaal", "toren_raam"]:
			t1.push_front("blok_dicht")
			t1.push_front("blok_dicht")
		tower(rx, rz + 1, style, t1, "N")
		if tower.has("toren_pinakels"):
			tower(rx + 1, rz + 1, style, ["blok_dicht", "toren_raam" if tower.has("toren_raam") else "blok_dicht", "toren_pinakels"], "N")
		if tower.has("toren_beton"):
			tower(rx + 1, rz + 3, style, ["toren_beton", "toren_beton", "toren_beton_klok" if tower.has("toren_beton_klok") else "toren_beton"], "N")
		rx += 2
	# special roofs on their own small buildings
	for k in special:
		if k.ends_with("3x3"):
			var dc := []
			for x in range(rx, rx + 3):
				for z in range(rz, rz + 3):
					dc.append(Vector2i(x, z))
			facades.call(dc, 1)
			B(rx + 1, 1, rz + 1, p + k, "S")
			rx += 3
		elif k == "luchtboog":
			facades.call([Vector2i(rx, rz + 1), Vector2i(rx + 1, rz + 1)], 2)
			B(rx, 0, rz, p + k, "N")
			B(rx + 1, 0, rz, p + k, "N")
			rx += 2
		else:
			facades.call([Vector2i(rx, rz)], 1)
			B(rx, 1, rz, p + k, "N")
			rx += 1
	# --- detail building at the end of the row: a blank building on which facade and
	# roof parts are placed
	if rx + 4 <= o.x + w - 1:
		_detail_building(rx, rz, style, "N")
	else:
		_detail_building(cx + 1, cz + d - 6, style)
	# street furniture along the north edge
	for x in range(o.x + 1, o.x + w - 1, 2):
		_prop(x * 4 + 2.0, o.y * 4 + 0.75, "street")


## Next detail name of a group from its rotating queue ("" if the group is empty).
func _take_detail(group: String) -> String:
	if not _detail_queue.has(group) or _detail_queue[group].is_empty():
		return ""
	var list: Array = _detail_queue[group]
	var nm: String = list.pop_front()
	list.push_back(nm)  # keeps rotating
	return nm


var _detail_used := {}  # detail names already placed by _take_new_detail


## First detail of a group that has not been used yet; when all are used, falls back
## to the rotating queue.
func _take_new_detail(group: String) -> String:
	if not _detail_queue.has(group):
		return ""
	for nm in _detail_queue[group]:
		if not _detail_used.has(nm):
			_detail_used[nm] = true
			return nm
	return _take_detail(group)


## Blank 4x2 building at tile (x0, z0) (2 storeys + flat roof) on which unused doors,
## awnings, windows, facade parts, texts, a balcony and roof details are placed.
func _detail_building(x0: int, z0: int, style: String, front := "S") -> void:
	var base_tile := style + "/" + style + "_blok_dicht"
	if not _has(base_tile):
		base_tile = "klassiek_rood/klassiek_rood_blok_dicht"
	for x in range(x0, x0 + 4):
		for z in range(z0, z0 + 2):
			B(x, 0, z, base_tile, "S")
			B(x, 1, z, base_tile, "S")
			B(x, 2, z, "modern_wit/modern_wit_dak_plat_" + ("hoek" if (x == x0 or x == x0 + 3) else "rand"),
				("WS" if x == x0 else "SE") if (x == x0 or x == x0 + 3) else "S")
	# the facade with the parts faces `front` (the street), the back gets the second text
	var fz := z0 * 4.0 if front == "N" else (z0 + 2) * 4.0
	var back := "S" if front == "N" else "N"
	var bz := (z0 + 2) * 4.0 if front == "N" else z0 * 4.0
	for i in 4:
		var mx := (x0 + i) * 4 + 2.0
		var door := _take_new_detail("deuren")
		if door != "":
			D(mx, fz, 0.0, door, front)
		var above := _take_new_detail("luifels") if i % 2 == 0 else _take_new_detail("zonwering")
		if above != "":
			D(mx, fz, 2.5, above, front)
		var window := _take_new_detail("ramen")
		if window != "":
			D(mx, fz, 3.5, window, front)
		var g := _take_new_detail("gevel")
		if g != "":
			D((x0 + i) * 4 + 0.5, fz, 1.0, g, front)
	var text := _take_new_detail("tekst")
	if text != "":
		D((x0 + 2) * 4.0, fz, 5.0, text, front)
	var text2 := _take_new_detail("tekst")
	if text2 != "":
		D((x0 + 2) * 4.0, bz, 5.0, text2, back)
	var balcony := _take_new_detail("balkons")
	if balcony != "":
		D(x0 * 4.0, (z0 + 1) * 4.0, 3.0, balcony, "W")
	for i in 2:
		var dk := _take_new_detail("dak")
		if dk != "":
			D((x0 + 1 + i * 2) * 4.0, (z0 + 1) * 4.0, 6.0, dk, "S")


## Places the next prop of a kind ("street", "green" or "water") at (wx, wz) metres,
## height wy, cycling through all props of that kind.
func _prop(wx: float, wz: float, kind: String, wy := 0.0) -> void:
	var list: Array = _prop_lists[kind]
	if list.is_empty():
		return
	Pr(wx, wz, _next(list, _prop_counter, kind), "S", wy)


# ------------------------------------------------------------------ roofs district: all roof tile kinds and roof shapes

## One district per roof material in the "daken" group: a sloped row, L shapes with
## valleys, gable roofs with L corner and T, and pyramid / lean-to sheds.
func _roofs_district() -> void:
	var kinds := []
	for nm in _names(buildings, "daken/"):
		var s: String = nm.split("/")[1]
		if not kinds.has(s):
			kinds.append(s)
	for s in kinds:
		var p: String = "daken/" + s + "/" + s + "_"
		var shapes := []
		for nm in _names(buildings, "daken/" + s + "/"):
			shapes.append(nm.split("/")[2].trim_prefix(s + "_"))
		_district_name = "dak:" + s
		var o := _district(22, 10)
		# walls under the roofs: tile roofs on 1930s brick, the rest on classic red brick
		var wall: String = "jaren30" if s.begins_with("pannen") else "klassiek_rood"
		var cx := o.x + 2
		var cz := o.y + 2
		# row 2 deep: sloped roofs with hip ridges, variants in the middle
		var row := []
		for x in range(cx, cx + 6):
			for z in [cz, cz + 1]:
				row.append(Vector2i(x, z))
		_plain_facades(row, wall, 2)
		var vi := 0
		var mid := []
		for v in ["schuin", "schuin_dakkapel", "schuin_schoorsteen", "schuin_afgeplat"]:
			if shapes.has(v):
				mid.append(v)
		for c in row:
			var sides := _open_sides(c, row)
			if sides.size() >= 2:
				var corner: String = "schuin_afgeplat_hoek_buiten" if (c.x == cx and shapes.has("schuin_afgeplat_hoek_buiten")) else "schuin_hoek_buiten"
				B(c.x, 2, c.y, p + corner, CORNER[_corner_pair(sides, "")])
			else:
				B(c.x, 2, c.y, p + mid[vi % mid.size()], sides[0])
				vi += 1
		# L shape with inner corner (valley)
		_l_building(cx + 7, cz, wall, p, "schuin")
		# second L shape with truncated roofs
		if shapes.has("schuin_afgeplat_hoek_binnen"):
			_l_building(cx, cz + 4, wall, p, "schuin_afgeplat", true)
		# gable roofs (1 deep), L corner and T
		var zx := cx + 12
		var zc := [Vector2i(zx, cz + 2), Vector2i(zx + 1, cz + 2), Vector2i(zx + 2, cz + 2), Vector2i(zx + 2, cz + 1), Vector2i(zx + 2, cz)]
		_plain_facades(zc, wall, 1)
		B(zx, 1, cz + 2, p + "zadel_schild", "N")
		B(zx + 1, 1, cz + 2, p + ("zadel_afgeplat" if shapes.has("zadel_afgeplat") else "zadel"), "S")
		B(zx + 2, 1, cz + 2, p + "zadel_hoek", "SE")
		B(zx + 2, 1, cz + 1, p + "zadel", "E")
		B(zx + 2, 1, cz, p + "zadel_schild", "E")
		var tx := cx + 16
		if shapes.has("zadel_t"):
			var tc := [Vector2i(tx, cz + 1), Vector2i(tx + 1, cz + 1), Vector2i(tx + 2, cz + 1), Vector2i(tx + 1, cz)]
			_plain_facades(tc, wall, 1)
			B(tx + 1, 1, cz + 1, p + "zadel_t", "S")
			B(tx, 1, cz + 1, p + "zadel_schild", "N")
			B(tx + 2, 1, cz + 1, p + "zadel_schild", "S")
			B(tx + 1, 1, cz, p + "zadel_schild", "E")
		# pyramid and lean-to roof on separate sheds
		for i in 2:
			var nm2: String = ["piramide", "lessenaar"][i]
			if shapes.has(nm2):
				_plain_facades([Vector2i(tx + i * 2, cz + 4)], wall, 1)
				B(tx + i * 2, 1, cz + 4, p + nm2, "S")
		for x in range(o.x + 1, o.x + 21, 3):
			_prop(x * 4 + 2.0, (o.y + 9) * 4 + 3.0, "green")


## Facades with plain windows (and window corners) for the test buildings in the roofs district.
func _plain_facades(cells: Array, style: String, floors: int) -> void:
	_facades(cells, style, floors, ["bg_raam"], ["verd_raam"], ["bg_raam_hoek"], ["verd_raam_hoek"], {})


## L-shaped one-storey building with a sloped roof that has an inner corner (valley):
## a 4x2 bar with a 2x2 leg below its west half; (x, z) = north-west cell.
## p = roof tile prefix ("daken/<kind>/<kind>_"), slope = "schuin" or "schuin_afgeplat".
## row_major: walls are placed row by row instead of per 2x2 quarter (only the
## placement order differs, which is kept so the saved scene stays the same).
func _l_building(x: int, z: int, wall: String, p: String, slope: String, row_major := false) -> void:
	var cells := [Vector2i(x, z), Vector2i(x + 1, z), Vector2i(x, z + 1), Vector2i(x + 1, z + 1),
		Vector2i(x + 2, z), Vector2i(x + 3, z), Vector2i(x + 2, z + 1), Vector2i(x + 3, z + 1),
		Vector2i(x, z + 2), Vector2i(x + 1, z + 2), Vector2i(x, z + 3), Vector2i(x + 1, z + 3)]
	if row_major:
		cells = [Vector2i(x, z), Vector2i(x + 1, z), Vector2i(x + 2, z), Vector2i(x + 3, z),
			Vector2i(x, z + 1), Vector2i(x + 1, z + 1), Vector2i(x + 2, z + 1), Vector2i(x + 3, z + 1),
			Vector2i(x, z + 2), Vector2i(x + 1, z + 2), Vector2i(x, z + 3), Vector2i(x + 1, z + 3)]
	_plain_facades(cells, wall, 1)
	var outer := p + slope + "_hoek_buiten"
	B(x, 1, z, outer, "NW")
	B(x + 1, 1, z, p + slope, "N")
	B(x + 2, 1, z, p + slope, "N")
	B(x + 3, 1, z, outer, "EN")
	B(x + 3, 1, z + 1, outer, "SE")
	B(x + 2, 1, z + 1, p + slope, "S")
	B(x + 1, 1, z + 1, p + slope + "_hoek_binnen", "SE")
	B(x, 1, z + 1, p + slope, "W")
	B(x, 1, z + 2, p + slope, "W")
	B(x + 1, 1, z + 2, p + slope, "E")
	B(x, 1, z + 3, outer, "WS")
	B(x + 1, 1, z + 3, outer, "SE")


# ------------------------------------------------------------------ halls, canopies, pillars, parking garage, radio tower

## Sports complex: the three hollow halls (glass, swimming pool, sports, incl. open walls)
## on one paved forecourt with a glass entrance canopy and a colonnade of all pillars, a
## parking garage with all parts and a radio mast.
func _halls_and_misc() -> void:
	_district_name = "hallen"
	var o := _district(30, 14)
	var x0 := o.x + 2
	var z0 := o.y + 2
	# sports complex: one paved forecourt round the halls, the canopy and the colonnade
	fill_rect(o.x + 1, o.y + 1, o.x + 28, o.y + 12, "plein/plein_tegels")
	for i in 6:
		Pr((x0 + 1 + i * 4) * 4.0, (z0 + 5) * 4.0 + 2.0, "bomen/plataan" if i % 2 else "verlichting/lantaarn_modern")
	# three hollow halls side by side (glass, pool, sports) with roof variants
	var hs := ["hal_glas", "hal_zwembad", "hal_sport"]
	for i in 3:
		var hx := x0 + i * 6
		_hall(hx, z0, 5, 4, hs[i], Vector2i(hx + 2, z0 + 3), hx + 2)
		# open wall variants without roof as a tall hall (2 storeys)
		for x in range(hx, hx + 5):
			var sides2 := ["N"] if x != hx and x != hx + 4 else (["N", "W"] if x == hx else ["N", "E"])
			if sides2.size() == 1:
				B(x, 1, z0, "hallen/" + hs[i] + "_wand", "N")
			else:
				B(x, 1, z0, "hallen/" + hs[i] + "_hoek", CORNER[_corner_pair(sides2, "")])
		fill_rect(hx, z0, hx + 4, z0 + 3, "zwembad/zwembad_kant_tegels" if i == 1 else "plein/plein_tegels")
	# canopy and pillars
	for x in range(x0, x0 + 6):
		for z in range(z0 + 6, z0 + 9):
			B(x, 0, z, "overkapping/overkapping_glas_kolom" if (x - x0) % 2 == 0 and z == z0 + 6 else "overkapping/overkapping_glas", "S")
	var pil := _names(buildings, "pilaren/")
	for i in pil.size():
		B(x0 + 8 + i, 0, z0 + 7, pil[i], "N")
	# parking garage with all parts
	var gx := x0 + 18
	var gz := z0 + 6
	_parking_decks(gx, gz, 4, 4, 2)
	B(gx, 0, gz + 1, "parkeergarage/parkeergarage_inrit", "W")
	B(gx + 1, 0, gz + 1, "parkeergarage/parkeergarage_helling", "N")
	B(gx + 2, 0, gz + 2, "parkeergarage/parkeergarage_helling_rand", "S")
	B(gx + 4, 0, gz, "parkeergarage/parkeergarage_trappenhuis", "S")
	B(gx + 4, 1, gz, "parkeergarage/parkeergarage_trappenhuis", "S")
	# radio tower
	_mast(x0 + 26, z0 + 2, "overig/radiotoren", 8)


# ------------------------------------------------------------------ traffic garden: continuous streets with all markings

# ------------------------------------------------------------------ cycle loop, tram loop and rail yard

## Square 5x5 loop of track/path at tile (x0, z0): curve tiles in the corners, straight
## tiles (cycled from straight_list) on the sides, T pieces in the middle of each side,
## a crossing in the centre and an end piece (or straight) sticking out at the bottom.
func _loop(x0: int, z0: int, curve: String, straight_list: Array, t: String, crossing: String, ending: String) -> void:
	var x1 := x0 + 4
	var z1 := z0 + 4
	G(x0, z0, curve, "S")
	G(x1, z0, curve, "W")
	G(x1, z1, curve, "N")
	G(x0, z1, curve, "E")
	var i := 0
	for x in range(x0 + 1, x1):
		if x == x0 + 2:
			continue
		G(x, z0, straight_list[i % straight_list.size()], "E"); i += 1
		G(x, z1, straight_list[i % straight_list.size()], "E"); i += 1
	for z in range(z0 + 1, z1):
		if z == z0 + 2:
			continue
		G(x0, z, straight_list[i % straight_list.size()], "S"); i += 1
		G(x1, z, straight_list[i % straight_list.size()], "S"); i += 1
	G(x0 + 2, z0, t, "W")
	G(x0, z0 + 2, t, "S")
	G(x1, z0 + 2, t, "N")
	G(x0 + 2, z1, t, "W")
	G(x0 + 2, z1 + 1, ending if ending != "" else straight_list[0], "N")
	G(x0 + 2, z0 + 2, crossing, "S")
	G(x0 + 2, z0 + 1, straight_list[0], "S")
	G(x0 + 2, z0 + 3, straight_list[0], "S")
	G(x0 + 1, z0 + 2, straight_list[0], "E")
	G(x0 + 3, z0 + 2, straight_list[0], "E")
	for c in [[x0 + 1, z0 + 1], [x0 + 3, z0 + 1], [x0 + 1, z0 + 3], [x0 + 3, z0 + 3]]:
		G(c[0], c[1], "natuur/gras_bloemen")


## District with a cycle loop, tram loop (with stops and large 3x3 curve) and a rail
## yard (switch, level crossings, platform, buffer stop, large curve).
func _loops_and_rail() -> void:
	_district_name = "lussen"
	var o := _district(40, 12)
	var x0 := o.x + 2
	var z0 := o.y + 2
	fill_rect(o.x + 1, o.y + 1, o.x + 38, o.y + 10, "natuur/gras")
	# cycle loop
	var fr := []
	for nm in _names(ground, "fietspad/"):
		var k: String = nm.split("/")[1]
		if not (k.contains("bocht") or k.ends_with("_t") or k.contains("kruising") or k.contains("eind")):
			fr.append(nm)
	_loop(x0, z0, "fietspad/fietspad_bocht", fr, "fietspad/fietspad_t", "fietspad/fietspad_kruising", "fietspad/fietspad_eind")
	_prop((x0 + 1) * 4 + 2.0, (z0 + 1) * 4 + 2.0, "green")
	# tram loop
	var tr := ["tram/tram_recht", "tram/tram_klinker_recht", "tram/tram_gras_recht", "tram/trambaan_vrij", "tram/trambaan_vrij_gras"]
	var tx := x0 + 7
	_loop(tx, z0, "tram/tram_bocht", tr, "tram/tram_t", "tram/tram_kruising", "")
	G(tx, z0 + 4, "tram/tram_gras_bocht", "E")
	G(tx - 1, z0 + 1, "tram/tram_halte_perron", "E")
	G(tx + 5, z0 + 1, "tram/tramhalte_middenperron", "S")
	G(tx + 7, z0 + 2, "tram/tram_bocht_groot_3x3", "S")
	for x in range(tx + 6, tx + 9):
		for z in range(z0 + 1, z0 + 4):
			if not (x == tx + 7 and z == z0 + 2):
				ground.set_cell_item(Vector3i(x, 0, z), GridMap.INVALID_CELL_ITEM)
	# rail yard: loop with small curves, level crossing, switch, platform, buffer stop, large curve
	var sx := x0 + 18
	_loop(sx, z0, "spoor/trein_bocht", ["spoor/trein_recht", "spoor/trein_bovenleiding_recht"], "spoor/trein_recht", "spoor/trein_recht", "spoor/trein_stootblok")
	G(sx + 4, z0 + 5, "spoor/tram_gras_kruising_weg", "E")
	G(sx + 2, z0, "spoor/trein_overweg", "S")
	G(sx + 2, z0 - 1, "weg/weg_vlak")
	G(sx + 2, z0 + 4, "spoor/trein_overweg_fiets", "S")
	G(sx, z0 + 2, "spoor/trein_wissel", "S")
	G(sx + 2, z0 + 2, "spoor/trein_recht", "S")
	G(sx - 1, z0 + 1, "spoor/perron", "E")
	G(sx - 1, z0 + 2, "spoor/perron_midden")
	G(sx - 1, z0 + 3, "spoor/perron_trap", "N")
	G(sx + 8, z0 + 2, "spoor/trein_bocht_groot_3x3", "S")
	for x in range(sx + 7, sx + 10):
		for z in range(z0 + 1, z0 + 4):
			if not (x == sx + 8 and z == z0 + 2):
				ground.set_cell_item(Vector3i(x, 0, z), GridMap.INVALID_CELL_ITEM)
	_prop((sx + 1) * 4 + 2.0, (z0 - 1) * 4 + 3.0, "street")


# ------------------------------------------------------------------ dike with all ramps as driveways

## River dike: a gentle north slope, a dike road on the crown (level 1) and a steep south
## slope down to the floodplain with sand, gravel and grass hills. Roads, a cycle path and
## a little square climb the gentle side on gentle ramps; a street, a one-way cycle path,
## a tram, a railway and a motorway link cross the steep side on steep ramps; four
## viaducts (road, tram, cycle path, motorway link) pass over the dike on bridge ramps;
## a raised square (terp) juts out of the crown with outer and inner slope corners.
## Everything continues to the city streets north and south of the district.
const FLAT_OF := {"stoep_rand": "stoep/stoep_rand", "stoep_goot_rand": "stoep/stoep_goot_rand", "stoep_vol": "stoep/stoep_vol",
	"stoep_hoek_buiten": "stoep/stoep_hoek_buiten", "rijstrook_geen_kant": "weg/rijstrook_geen_kant",
	"rijstrook_onderbroken_kant": "weg/rijstrook_onderbroken_kant", "rijstrook_streep_kant": "weg/rijstrook_streep_kant",
	"rijstrook_onderbroken_geen": "weg/rijstrook_onderbroken_geen", "weg_vlak": "weg/weg_vlak", "straat_klinkers": "weg/straat_klinkers",
	"plein_tegels": "plein/plein_tegels", "fietspad_recht": "fietspad/fietspad_recht", "fietspad_eenrichting": "fietspad/fietspad_eenrichting",
	"tram_recht": "tram/tram_recht", "trein_recht": "spoor/trein_recht", "snelweg_rijstrook": "snelweg/snelweg_rijstrook",
	"snelweg_vluchtstrook": "snelweg/snelweg_vluchtstrook", "snelweg_aansluiting": "snelweg/snelweg_aansluiting"}


func _dike_with_ramps() -> void:
	_district_name = "dijk"
	var o := _district(60, 13)
	var r := func(i: int) -> int: return o.y + i   # row i of the district
	var x0 := o.x + 1
	var x1 := o.x + 58
	# the dike: gentle north slope (rows 4, 5), crown road (6, 7, level 1), steep south slope (8)
	for x in range(x0, x1 + 1):
		G(x, r.call(4), "helling/flauw_gras_a", "N")
		G(x, r.call(5), "helling/flauw_gras_b", "N")
		for z in [r.call(6), r.call(7)]:
			G(x, z, "terrein/grond_blok")
		G(x, r.call(6), "weg/rijstrook_onderbroken_kant", "E", 1)
		G(x, r.call(7), "weg/rijstrook_geen_kant", "W", 1)
		G(x, r.call(8), "helling/helling_gras", "S")
		for z in range(o.y + 4, o.y + 9):
			_taken[Vector2i(x, z)] = true
		if x % 6 == 0:
			Pr(x * 4 + 2.0, r.call(6) * 4 + 0.5, "verlichting/lantaarn_modern", "S", 1.0)
	# a route across one side of the dike: flat tiles from the city street, then the ramp
	var route := func(x: int, part: String, north: bool) -> void:
		var flat: String = FLAT_OF[part]
		var rows: Array = [0, 1, 2, 3] if north else [9, 10, 11, 12]
		for i in rows:
			var c := Vector2i(x, r.call(i))
			G(c.x, c.y, flat, "N" if north else "S")
			_pavement.erase(c)
			_taken[c] = true
		if north:
			G(x, r.call(4), "helling/flauw_%s_a" % part, "N")
			G(x, r.call(5), "helling/flauw_%s_b" % part, "N")
		else:
			G(x, r.call(8), "helling/helling_" + part, "S")
	# gentle side: a street with pavements, a clinker street with a cycle path, a road with a square
	var north_routes := [[o.x + 2, ["stoep_rand", "rijstrook_geen_kant", "rijstrook_onderbroken_kant", "stoep_goot_rand"]],
		[o.x + 18, ["fietspad_recht", "straat_klinkers", "stoep_vol"]], [o.x + 28, ["weg_vlak", "plein_tegels"]]]
	for nr in north_routes:
		for k in nr[1].size():
			route.call(nr[0] + k, nr[1][k], true)
	# steep side: a street, a one-way cycle path, a square, a tram, a railway, a motorway link
	var south_routes := [[o.x + 2, ["stoep_rand", "rijstrook_streep_kant", "rijstrook_onderbroken_geen", "rijstrook_geen_kant", "rijstrook_onderbroken_kant", "stoep_goot_rand"]],
		[o.x + 11, ["fietspad_eenrichting", "stoep_hoek_buiten"]], [o.x + 14, ["plein_tegels"]], [o.x + 16, ["tram_recht"]],
		[o.x + 18, ["trein_recht"]], [o.x + 20, ["snelweg_vluchtstrook", "snelweg_rijstrook", "snelweg_aansluiting"]]]
	for sr in south_routes:
		for k in sr[1].size():
			route.call(sr[0] + k, sr[1][k], false)
	# the tram and the train cross the crown on their own track
	for c in [[o.x + 16, "tram/tram_recht"], [o.x + 18, "spoor/trein_recht"]]:
		for z in [r.call(6), r.call(7)]:
			G(c[0], z, c[1], "S", 1)
	# viaducts over the dike: bridge ramps up (rows 1..3), deck on level 3 (rows 4..8), down (9..11)
	var viaducts := [[o.x + 8, ["rijstrook_geen_kant", "rijstrook_onderbroken_kant"], ["brug/brug_dek_rijstrook_kant_rand", "brug/brug_dek_rijstrook_onderbroken"]],
		[o.x + 24, ["tram_recht", "tram_recht"], ["brug/brug_dek_tram_rand", "brug/brug_dek_tram_rand"]],
		[o.x + 40, ["stoep_vol", "fietspad_recht"], ["brug/brug_dek_stoep_rand", "brug/brug_dek_fietspad_rand"]],
		[o.x + 54, ["snelweg_aansluiting", "snelweg_aansluiting"], ["brug/brug_dek_weg_rand", "brug/brug_dek_weg_rand"]]]
	for v in viaducts:
		for k in 2:
			var x: int = v[0] + k
			var part: String = v[1][k]
			# parapets on the outer edge: east going up from the north, west coming down south
			var up := "helling/helling_brug_%s%s" % [part, "_rand" if k == 1 else ""]
			var down := "helling/helling_brug_%s%s" % [part, "_rand" if k == 0 else ""]
			for i in 3:
				G(x, r.call(1 + i), up, "N", i)
				G(x, r.call(11 - i), down, "S", i)
			for z in range(r.call(4), r.call(9)):
				G(x, z, v[2][k], "S" if k == 0 else "N", 3)
			for i in [0, 12]:
				var c := Vector2i(x, r.call(i))
				G(c.x, c.y, FLAT_OF[part], "N" if i == 0 else "S")
				_pavement.erase(c)
			for z in range(o.y, o.y + 13):
				_taken[Vector2i(x, z)] = true
	# terp: a raised square on the crown, steep slopes with outer and inner corners
	var tx := o.x + 12
	for x in range(tx, tx + 3):
		for z in [r.call(4), r.call(5)]:
			G(x, z, "terrein/grond_blok")
			G(x, z, "plein/plein_tegels", "S", 1)
		G(x, r.call(3), "helling/helling_gras", "N")
		_taken[Vector2i(x, r.call(3))] = true
	G(tx - 1, r.call(4), "helling/helling_gras", "W")
	G(tx + 3, r.call(4), "helling/helling_gras", "E")
	G(tx - 1, r.call(3), "helling/helling_gras_hoek_buiten", "W")
	G(tx + 3, r.call(3), "helling/helling_gras_hoek_buiten", "N")
	G(tx - 1, r.call(5), "helling/helling_gras_hoek_binnen", "W")
	G(tx + 3, r.call(5), "helling/helling_gras_hoek_binnen", "N")
	for c in [Vector2i(tx - 1, r.call(3)), Vector2i(tx + 3, r.call(3))]:
		_taken[c] = true
	Pr((tx + 1) * 4 + 2.0, r.call(4) * 4 + 2.0, "straat/bank_hout", "N", 1.0)
	Pr((tx + 1) * 4 + 2.0, r.call(5) * 4 + 2.0, "bomen/linde", "S", 1.0)
	# floodplain hills: grass, sand and gravel, each with a spur (inner corner)
	var hx := o.x + 27
	for mat in ["gras", "zand", "grind"]:
		_hill(hx, r.call(9), mat)
		G(hx + 3, r.call(10), "heuvel/heuvel_" + mat + "_hoek_binnen", "S")
		for x in range(hx, hx + 4):
			for z in range(r.call(9), r.call(12)):
				_taken[Vector2i(x, z)] = true
		hx += 5 if mat == "gras" else 12


# ------------------------------------------------------------------ tunnel park: sunken roads and tunnels

## Sunk ground tile: empties level 0 at (x, z) and places tile_name on level -depth.
func _trench(x: int, z: int, tile_name: String, depth: int, rot = "S") -> void:
	ground.set_cell_item(Vector3i(x, 0, z), GridMap.INVALID_CELL_ITEM)
	G(x, z, tile_name, rot, -depth)
	occupied[Vector2i(x, z)] = true


## District with sunken roads: a 3-lane car tunnel (ramp, trough, portal, road on top),
## a road getting deeper step by step, an underpass with pavements and a cycle tunnel.
func _tunnel_park() -> void:
	_district_name = "tunnelpark"
	var o := _district(40, 26)
	fill_rect(o.x + 1, o.y + 1, o.x + 38, o.y + 24, "natuur/gras")
	var z0 := o.y + 2
	# A: car tunnel (3 lanes) with ramp, open trough, portal and tunnel with a road above it
	var x := o.x + 2
	for d in range(1, 7):
		_trench(x, z0 + d - 1, "tunnel/tunnel_toerit_wand_d%d" % d, d)
		_trench(x + 1, z0 + d - 1, "tunnel/tunnel_toerit_d%d" % d, d)
		_trench(x + 2, z0 + d - 1, "tunnel/tunnel_toerit_wand_rechts_d%d" % d, d)
	for r in range(2):
		_trench(x, z0 + 6 + r, "tunnel/tunnelbak_rijstrook_wand_d6", 6)
		_trench(x + 1, z0 + 6 + r, "tunnel/tunnelbak_rijstrook_d6", 6)
		_trench(x + 2, z0 + 6 + r, "tunnel/tunnelbak_rijstrook_wand_rechts_d6", 6)
	G(x, z0 + 8, "tunnel/tunnel_rijstrook_wand_portaal", "S", -6)
	G(x + 1, z0 + 8, "tunnel/tunnel_rijstrook_portaal", "S", -6)
	G(x + 2, z0 + 8, "tunnel/tunnel_rijstrook_wand_rechts_portaal", "S", -6)
	for r in range(9, 14):
		G(x, z0 + r, "tunnel/tunnel_rijstrook_wand", "S", -6)
		G(x + 1, z0 + r, "tunnel/tunnel_middenwand" if r == 11 else "tunnel/tunnel_rijstrook", "S", -6)
		G(x + 2, z0 + r, "tunnel/tunnel_rijstrook_wand_rechts", "S", -6)
	# road on top of the tunnel
	for xx in range(o.x + 1, o.x + 12):
		for zz in [z0 + 10, z0 + 11]:
			G(xx, zz, "weg/rijstrook_onderbroken_kant" if zz == z0 + 10 else "weg/rijstrook_geen_kant", "E" if zz == z0 + 10 else "W")
	# B: sunken road that gets deeper step by step (car + bicycle), without roof
	x = o.x + 8
	var z := z0
	for d in range(1, 7):
		_trench(x, z, "tunnel/tunnel_toerit_wand_d%d" % d, d)
		_trench(x + 1, z, "tunnel/tunnel_toerit_d%d" % d, d)
		_trench(x + 2, z, "tunnel/fietstunnel_toerit_wand_rechts_d%d" % d, d)
		_trench(x, z + 1, "tunnel/tunnelbak_rijstrook_wand_d%d" % d, d)
		_trench(x + 1, z + 1, "tunnel/tunnelbak_rijstrook_d%d" % d, d)
		_trench(x + 2, z + 1, "tunnel/tunnelbak_fietspad_wand_rechts_d%d" % d, d)
		z += 2
	# C: pedestrian/cycle underpass with pavement and cycle troughs at every depth
	x = o.x + 14
	for d in range(1, 7):
		var zz: int = z0 + (d - 1) * 2
		_trench(x, zz, "tunnel/tunnelbak_stoep_wand_d%d" % d, d)
		_trench(x + 1, zz, "tunnel/tunnelbak_stoep_d%d" % d, d)
		_trench(x + 2, zz, "tunnel/tunnelbak_fietspad_d%d" % d, d)
		_trench(x + 3, zz, "tunnel/tunnelbak_fietspad_wand_d%d" % d, d)
		_trench(x + 4, zz, "tunnel/tunnelbak_stoep_wand_rechts_d%d" % d, d)
		_trench(x, zz + 1, "tunnel/tunnelbak_rijstrook_wand_d%d" % d, d)
		_trench(x + 4, zz + 1, "tunnel/tunnelbak_rijstrook_wand_rechts_d%d" % d, d)
		_trench(x + 1, zz + 1, "tunnel/tunnelbak_stoep_d%d" % d, d)
		_trench(x + 2, zz + 1, "tunnel/tunnelbak_fietspad_d%d" % d, d)
		_trench(x + 3, zz + 1, "tunnel/tunnelbak_stoep_d%d" % d, d)
	# D: cycle tunnel with ramps and portals
	x = o.x + 21
	for d in range(1, 7):
		_trench(x, z0 + d - 1, "tunnel/fietstunnel_toerit_wand_d%d" % d, d)
		_trench(x + 1, z0 + d - 1, "tunnel/fietstunnel_toerit_wand_rechts_d%d" % d, d)
	G(x, z0 + 6, "tunnel/tunnel_fiets_wand_portaal", "N", -6)
	G(x + 1, z0 + 6, "tunnel/tunnel_fiets_wand_rechts_portaal", "N", -6)
	G(x + 2, z0 + 6, "tunnel/tunnel_fietspad", "S", -6)
	for r in range(7, 11):
		G(x, z0 + r, "tunnel/tunnel_fiets_wand", "S", -6)
		G(x + 1, z0 + r, "tunnel/tunnel_fiets_wand_rechts", "S", -6)
	for xx in range(x - 1, x + 3):
		for zz in range(z0 + 7, z0 + 11):
			G(xx, zz, "natuur/gras_kort")


# ------------------------------------------------------------------ canal with all bridges

## Canal ring (grachtengordel) on level -2: canal houses on both quays facing a quay
## street, every bridge type spread along the canal linking the two quays, a few side
## streets through the rows of houses to the city streets, a viaduct carrying a through
## road over houses and canal (bridge ramps up to level 3), quay walls round the ends of
## the canal (inner quay corners) and a landing jutting into the water (outer corners).
func _canal_with_bridges() -> void:
	_district_name = "kanaal"
	var o := _district(90, 19)
	var x0 := o.x + 1
	var x1 := o.x + 88          # last column inside the kerb
	var zq := o.y + 4           # north quay street
	var zw := o.y + 6           # first water row (5 rows)
	var zs := o.y + 12          # south quay street
	var houses_n := [o.y + 1, o.y + 2]
	var houses_s := [o.y + 14, o.y + 15]
	# canal with quay walls; the ends of the canal are walled too
	for x in range(x0, x1 + 1):
		var end := x == x0 or x == x1
		for z in range(zw, zw + 5):
			if end:
				_quay(x, z, "stoep/stoep_kade", "E" if x == x0 else "W")
			else:
				_trench(x, z, "water/water_gracht", 2)
		for z in [zw - 1, zw + 5]:
			var kind := "stoep/stoep_kade" if x % 4 else "stoep/stoep_kade_klinker"
			var rot := "S" if z == zw - 1 else "N"
			if end:
				# inner quay corner: the water only lies diagonally
				kind = "stoep/stoep_kade_hoek_binnen"
				rot = {Vector2i(0, 0): "S", Vector2i(0, 1): "E", Vector2i(1, 0): "W", Vector2i(1, 1): "N"}[Vector2i(0 if x == x0 else 1, 0 if z == zw - 1 else 1)]
			_quay(x, z, kind, rot)
		# quay streets and pavements in front of the houses
		G(x, zq, "weg/straat_klinkers", "E")
		G(x, zs, "weg/straat_klinkers", "E")
		for z in [zq - 1, zs + 1]:
			G(x, z, "stoep/stoep_vol")
			_pavement[Vector2i(x, z)] = "klinker_"
	# a landing jutting into the canal from the south quay (outer quay corners)
	var lx := o.x + 44
	for k in 2:
		_quay(lx + k, zw + 4, "stoep/stoep_kade_hoek_buiten", "N" if k == 0 else "E")
		G(lx + k, zw + 5, "stoep/stoep_vol")
	G(lx + 2, zw + 5, "waterkant/kadetrap", "N", -2)
	# side streets through the rows of houses to the city streets north and south
	var side := [o.x + 12, o.x + 34, o.x + 58, o.x + 80]
	for sx in side:
		for z in range(o.y, zq):
			G(sx, z, "weg/straat_klinkers", "S")
			_pavement.erase(Vector2i(sx, z))
			_taken[Vector2i(sx, z)] = true
		for z in range(zs + 1, o.y + 19):
			G(sx, z, "weg/straat_klinkers", "S")
			_pavement.erase(Vector2i(sx, z))
			_taken[Vector2i(sx, z)] = true
	# bridges, each linking the two quay streets, spread along the canal
	var bridges := []   # [width, callable(x)]
	for nm in _names(ground, "brug/brug_dek_"):
		var k: String = nm.split("/")[1]
		var twin: bool = k.ends_with("_rand") or k.contains("_rand_")
		bridges.append([2 if twin else 1, func(bx: int) -> void:
			for z in range(zw, zw + 5):
				G(bx, z, nm)
				if twin:
					G(bx + 1, z, nm, "N")])
	bridges.append([3, func(bx: int) -> void:
		for i in 3:
			for z in range(zw, zw + 5):
				G(bx + i, z, ["brug/brug_boog_gracht_rand", "brug/brug_boog_gracht_midden", "brug/brug_boog_gracht_rand"][i], ["S", "S", "N"][i], -2)])
	bridges.append([1, func(bx: int) -> void:
		for z in range(zw, zw + 5):
			G(bx, z, "brug/brug_boog_gracht_beide", "S", -2)])
	bridges.append([1, func(bx: int) -> void:
		for i in 5:
			G(bx, zw + i, "brug/ophaalbrug_portaal" if i in [1, 3] else "brug/ophaalbrug_dek", "N" if i == 1 else "S")])
	bridges.append([1, func(bx: int) -> void:
		for i in 5:
			G(bx, zw + i, "brug/voetbrug_modern", "S")])
	bridges.append([4, func(bx: int) -> void:
		for i in 5:
			G(bx, zw + 4 - i, "brug/staalboog_%d" % (i + 1), "S")
			G(bx + 2, zw + 4 - i, "brug/staalboog_rand_%d" % (i + 1), "S")
			G(bx + 3, zw + i, "brug/staalboog_rand_%d" % (i + 1), "N")])
	bridges.append([1, func(bx: int) -> void:
		G(bx, zw + 2, "brug/tuibrug_0", "S")
		for i in range(1, 4):
			G(bx, zw + 2 - i, "brug/tuibrug_%d" % i, "S")
			G(bx, zw + 2 + i, "brug/tuibrug_%d_achter" % i, "S")])
	var total := 0
	for b in bridges:
		total += b[0]
	var free_cols := []
	for x in range(x0 + 2, x1 - 1):
		if not (x in side) and absi(x - lx) > 2 and x != o.x + 70:
			free_cols.append(x)
	var gap := maxi(1, (free_cols.size() - total) / bridges.size())
	var at := 0
	for b in bridges:
		at += gap / 2
		while at < free_cols.size() - b[0] and free_cols[at + b[0] - 1] - free_cols[at] != b[0] - 1:
			at += 1
		if at >= free_cols.size() - b[0]:
			push_warning("canal too short for every bridge")
			break
		b[1].call(free_cols[at])
		at += b[0] + gap - gap / 2
	# viaduct: a through road at level 3 over the houses, quays and canal
	var vx := o.x + 70
	for z in range(o.y, o.y + 19):
		var c := Vector2i(vx, z)
		_pavement.erase(c)
		_taken[c] = true
		if z < o.y + 3:
			G(vx, z, "helling/helling_brug_weg_vlak", "N", z - o.y)
		elif z > o.y + 15:
			G(vx, z, "helling/helling_brug_weg_vlak", "S", o.y + 18 - z)
		else:
			G(vx, z, "brug/brug_dek_weg_beide", "S", 3)
			if z >= zw and z < zw + 5 and (z - zw) % 2 == 1:
				_pier(vx, z, "brug/brug_pijler_water", -2, 2)
			elif z == zw - 3 or z == zs + 3:
				# abutment where the ramp reaches the deck, on a pier
				_pier(vx, z, "brug/brug_pijler_stoep" if z == zw - 3 else "brug/brug_pijler_gras", 0, 1)
				G(vx, z, "brug/brug_landhoofd", "S", 2)
	G(vx, zw - 1, "brug/brug_ligger", "S", 2)
	G(vx, zw + 5, "brug/brug_ligger", "S", 2)
	# canal houses on both quays: narrow fronts with gable and cornice tops, gardens behind
	var tops := ["gevel_klok", "gevel_hals", "top_lijstgevel", "top_lijstgevel_fronton"]
	for rows in [[houses_n, "S"], [houses_s, "N"]]:
		var front: int = rows[0][1] if rows[1] == "S" else rows[0][0]
		var back: int = rows[0][0] if rows[1] == "S" else rows[0][1]
		for x in range(x0, x1 + 1):
			if x in side or x == vx:
				continue
			var p := "herenhuis_1600/herenhuis_1600_"
			for y in 3:
				B(x, y, front, p + ("bg_deur" if y == 0 and x % 2 == 0 else ("bg_raam" if y == 0 else "verd_raam")), rows[1])
				B(x, y, back, p + ("bg_raam" if y == 0 else "verd_raam"), "N" if rows[1] == "S" else "S")
			B(x, 3, front, p + tops[x % tops.size()], rows[1])
			B(x, 3, back, p + "dak_plat_midden", "S")
	# boats along the quays
	for i in range(0, 84, 7):
		_prop((x0 + 3 + i) * 4 + 0.0, (zw + 1 + (i / 7) % 3) * 4 + 2.0, "water", -2.0)


## A quay cell: pavement on top of a quay wall reaching down to the canal floor.
func _quay(x: int, z: int, tile_name: String, rot) -> void:
	G(x, z, "water/kademuur_alg", "S", -2)
	G(x, z, "water/kademuur", "S", -1)
	G(x, z, tile_name, rot)


# ------------------------------------------------------------------ nature and recreation park

## Nature park: pond with all bank types and wooden footbridges, a ditch with culvert,
## terraced garden with stairs, paths, a small wood, a planted bed, a boules court and an
## outdoor pool.
func _nature_park() -> void:
	_district_name = "natuurpark"
	var o := _district(48, 16)
	fill_rect(o.x + 1, o.y + 1, o.x + 46, o.y + 14, "natuur/gras")
	# pond (layer 0) with banks, beach, sheet piling, basalt, boulevard, reeds and lilies
	var px := o.x + 2
	var pz := o.y + 2
	for x in range(px + 1, px + 7):
		for z in range(pz + 1, pz + 5):
			G(x, z, ["water/water", "water/water_lelies", "water/water_riet", "water/water"][(x + z) % 4])
	for x in range(px + 1, px + 7):
		G(x, pz, ["water/water_oever", "waterkant/strand", "waterkant/beschoeiing", "waterkant/basalt_talud", "waterkant/boulevard", "water/water_oever"][x - px - 1], "S")
		G(x, pz + 5, "water/water_oever", "N")
	for z in range(pz + 1, pz + 5):
		G(px, z, "water/water_oever", "E")
		G(px + 7, z, "water/water_oever", "W")
	G(px, pz, "water/water_oever_hoek_buiten", "SE")
	G(px + 7, pz, "water/water_oever_hoek_buiten", "WS")
	G(px, pz + 5, "waterkant/strand_hoek", "EN")
	G(px + 7, pz + 5, "water/water_oever_hoek_buiten", "NW")
	G(px + 3, pz + 2, "brug/voetbrug_hout_boog", "E")
	G(px + 5, pz + 3, "brug/voetbrug_hout_vlak", "S")
	G(px + 2, pz + 4, "waterkant/aanlegplaats", "N")
	G(px + 6, pz + 1, "water/kademuur_water", "S")
	G(px + 8, pz + 2, "water/water_oever_hoek_binnen", "S")
	for i in 4:
		_prop((px + 2 + i * 1.5) * 4, (pz + 3) * 4 + 2.0, "water", 0.0)
	# ditch with bend and culvert
	var sx := o.x + 12
	for z in range(o.y + 2, o.y + 8):
		G(sx, z, "water/duiker" if z == o.y + 5 else "water/sloot")
	G(sx, o.y + 8, "water/sloot_bocht", "N")
	for xx in range(sx - 2, sx + 3):
		G(xx, o.y + 5, "weg/berm" if xx != sx else "water/duiker", "N")
	# terraced garden with ground blocks and stairs
	var tx := o.x + 16
	var tz := o.y + 2
	for x in range(tx, tx + 4):
		G(x, tz, ["terrein/grond_blok", "terrein/grond_blok_beton", "terrein/grond_blok_baksteen", "terrein/grond_blok"][x - tx])
		G(x, tz, "natuur/gras_bloemen", "S", 1)
	G(tx, tz + 1, "terrein/trap_1m", "S")
	G(tx + 1, tz + 1, "terrein/trap_1m_breed", "S")
	G(tx + 2, tz + 1, "terrein/trap_1m_fietsgoot", "S")
	G(tx + 3, tz + 1, "helling/helling_dijk_beton", "S")
	# gravel path from the pond to the outdoor pool, bending south; a sand path along the
	# south of the pond; a small wood with its edge along the path; a freshly planted
	# bed of bare earth with young trees and a gravel boules court with benches
	for x in range(o.x + 21, o.x + 29):
		G(x, o.y + 3, "natuur/pad_grind", "E")
	G(o.x + 29, o.y + 3, "natuur/pad_grind_bocht", "W")
	for z in range(o.y + 4, o.y + 8):
		G(o.x + 29, z, "natuur/pad_grind", "S")
	for x in range(o.x + 1, o.x + 12):
		G(x, o.y + 9, "natuur/zandpad", "E")
	for x in range(o.x + 31, o.x + 46):
		for z in range(o.y + 1, o.y + 4):
			G(x, z, "natuur/bos")
		G(x, o.y + 4, "natuur/bosrand", "S")
		if x % 3 == 0:
			Pr(x * 4 + 2.0, (o.y + 2) * 4 + 2.0, ["bomen/eik", "bomen/den", "bomen/berk"][(x / 3) % 3])
	for x in range(o.x + 22, o.x + 25):
		for z in [o.y + 5, o.y + 6]:
			G(x, z, "natuur/aarde")
			Pr(x * 4 + 2.0, z * 4 + 2.0, "bomen/jonge_boom")
	for x in range(o.x + 25, o.x + 28):
		for z in [o.y + 5, o.y + 6]:
			G(x, z, "plein/plein_grind")
	Pr((o.x + 26) * 4 + 2.0, (o.y + 7) * 4 + 0.5, "straat/bank_hout", "N")
	# outdoor pool with all pool tiles
	var zx := o.x + 22
	var zz := o.y + 8
	fill_rect(zx, zz, zx + 7, zz + 5, "zwembad/zwembad_kant_tegels")
	_pool_basin(zx + 1, zz + 1, 5, 3, true, true)
	_trench(zx + 6, zz + 2, "zwembad/zwembad_eind", 1, "E")
	G(zx + 7, zz + 4, "zwembad/kinderbad")
	for i in 4:
		_prop((zx + 1 + i * 1.5) * 4, (zz + 5) * 4 + 1.0, "water", 0.0)


# ------------------------------------------------------------------ check: every tile in the town

## Sorted names of the library items of gm that are not placed in gm yet.
func _unused_list(gm: GridMap) -> Array:
	var present := {}
	for c in gm.get_used_cells():
		present[gm.get_cell_item(c)] = true
	var result := []
	for id in gm.mesh_library.get_item_list():
		if not present.has(id):
			result.append(gm.mesh_library.get_item_name(id))
	result.sort()
	return result


# ------------------------------------------------------------------ intersections: traffic islands, roundabout and pavement corners

# ------------------------------------------------------------------ shopping street (pedestrian zone) near the campus

## Pedestrian shopping street x 62..95 (z 90..92) with two rows of shop buildings on
## each side (styles alternate every four), facade details, terraces and street furniture.
func _shopping_street() -> void:
	var x0 := 62
	var x1 := 95
	# pedestrian street z 90..92 with a central strip of natural stone
	fill_rect(x0, 86, x1, 97, "natuur/gras")
	for x in range(x0, x1 + 1):
		G(x, 90, "plein/plein_klinkers")
		G(x, 91, "plein/plein_natuursteen" if x % 6 else "plein/plein_patroon")
		G(x, 92, "plein/plein_klinkers")
	# entrances with bollards and signs
	for z in [90, 91, 92]:
		Pr(x0 * 4 + 0.5, z * 4 + 2.0, "paaltjes/paal_afzet")
		Pr((x1 + 1) * 4 - 0.5, z * 4 + 2.0, "paaltjes/paal_afzet")
	Pr(x0 * 4 + 1.0, 90 * 4 + 0.5, "borden/bord_voetpad", "W")
	Pr((x1 + 1) * 4 - 1.0, 92 * 4 + 3.5, "borden/bord_voetpad", "E")
	# shop buildings on both sides: alternating styles every four buildings
	var styles := ["klassiek_rood", "jaren30", "klassiek_geel", "herenhuis_1900", "modern_wit", "klassiek_donker", "modern_donker", "jaren30"]
	var shops := ["bg_bakker", "bg_cafe", "bg_kleding", "bg_boekhandel", "bg_restaurant", "bg_bloemist", "bg_juwelier", "bg_telefoon",
		"bg_ijssalon", "bg_slager", "bg_fietsenwinkel", "bg_bar", "bg_drogist", "bg_kapper", "bg_snackbar", "bg_supermarkt", "bg_dierenwinkel",
		"bg_winkel_luifel", "bg_kleding", "bg_cafe"]
	var upper_variants := ["verd_raam", "verd_balkon", "verd_raam", "verd_luiken", "verd_erker", "verd_raam_breed"]
	var roof_variants := ["dak_schuin", "dak_schuin_dakkapel", "dak_schuin", "dak_schuin_schoorsteen"]
	var wi := 0
	# two rows of 2 deep, first the one south of the street (front facing north, z 93..94),
	# then the one north of it (front facing south, z 88..89)
	for front in ["N", "S"]:
		var back := "N" if front == "S" else "S"
		var fz := 89 if front == "S" else 93
		var bz := 88 if front == "S" else 94
		for x in range(x0, x1 + 1):
			var style: String = styles[((x - x0) / 4) % styles.size()]
			var p := style + "/" + style + "_"
			var edge_x := x == x0 or x == x1
			# corner rotations of the front and back cell at the ends of the row
			var front_corner := ("WS" if x == x0 else "SE") if front == "S" else ("NW" if x == x0 else "EN")
			var back_corner := ("NW" if x == x0 else "EN") if front == "S" else ("WS" if x == x0 else "SE")
			# front row: shop on the ground floor, homes above
			var shop: String = shops[wi % shops.size()]
			wi += 1
			if not _has(p + shop):
				shop = _first(p, ["bg_winkel_luifel", "bg_winkel", "bg_raam_boog", "bg_raam"])
			if edge_x:
				B(x, 0, fz, p + ("bg_raam_hoek" if _has(p + "bg_raam_hoek") else "blok_dicht"), front_corner)
				for v in range(1, 3):
					B(x, v, fz, p + ("verd_raam_hoek" if _has(p + "verd_raam_hoek") else "blok_dicht"), front_corner)
			else:
				B(x, 0, fz, p + shop, front)
				for v in range(1, 3):
					var nm: String = upper_variants[(x + v) % upper_variants.size()]
					B(x, v, fz, p + (nm if _has(p + nm) else _first(p, ["verd_raam", "verd_raam_boog", "verd_glas"])), front)
			# back row: rear facades with windows and doors
			if edge_x:
				B(x, 0, bz, p + _first(p, ["bg_raam_hoek", "bg_raam_boog_hoek"]), back_corner)
				for v in range(1, 3):
					B(x, v, bz, p + _first(p, ["verd_raam_hoek", "verd_raam_boog_hoek"]), back_corner)
			else:
				B(x, 0, bz, p + _first(p, ["bg_deur", "bg_raam"] if x % 2 else ["bg_raam", "bg_raam_boog"]), back)
				for v in range(1, 3):
					B(x, v, bz, p + _first(p, ["verd_raam", "verd_raam_boog", "verd_glas"]), back)
			# roofs: a sloped roof if the style has one, otherwise flat with an edge on both sides
			if _has(p + "dak_schuin"):
				if edge_x:
					B(x, 3, fz, p + "dak_schuin_hoek_buiten", front_corner)
					B(x, 3, bz, p + "dak_schuin_hoek_buiten", back_corner)
				else:
					var dn: String = roof_variants[x % roof_variants.size()]
					B(x, 3, fz, p + (dn if _has(p + dn) else "dak_schuin"), front)
					B(x, 3, bz, p + "dak_schuin", back)
			else:
				B(x, 3, fz, p + "dak_plat_rand", front)
				B(x, 3, bz, p + "dak_plat_rand", back)
			# facade details above the shops (on the street-side face of the front cell)
			var facade_z := (fz + 1) * 4.0 if front == "S" else fz * 4.0
			if not edge_x and x % 3 == 0:
				D(x * 4 + 2.0, facade_z, 3.2, "ramen/bloembak", front)
			if not edge_x and x % 5 == 2:
				D(x * 4 + 0.5, facade_z, 2.6, "gevel/uithangbord", front)
			if not edge_x and x % 7 == 4:
				D(x * 4 + 2.0, facade_z, 6.0, "gevel/vlag_regenboog" if x % 2 else "gevel/vlag_nl", front)
	# street furniture and terraces in the pedestrian street
	for x in range(x0 + 1, x1, 2):
		var wx := x * 4 + 2.0
		match x % 8:
			1:
				Pr(wx, 90 * 4 + 1.5, "terras/tafel_rond_stoelen")
				Pr(wx, 90 * 4 + 1.5, "terras/parasol_rood")
			3:
				Pr(wx, 91 * 4 + 2.0, "bomen/linde")
				Pr(wx + 2.0, 91 * 4 + 2.0, "straat/bank_hout", "N")
			5:
				Pr(wx, 92 * 4 + 2.5, "terras/tafel_vierkant_stoelen")
				Pr(wx, 92 * 4 + 2.5, "terras/parasol_groen")
			7:
				Pr(wx, 91 * 4 + 2.0, "planten/plantenbak_beton")
				Pr(wx + 2.0, 91 * 4 + 1.0, "verlichting/lantaarn_klassiek")
	for x in range(x0 + 2, x1, 6):
		Pr(x * 4 + 2.0, 91 * 4 + 3.0, "straat/prullenbak_paal")
		if x % 12 == 2:
			Pr(x * 4 + 3.5, 92 * 4 + 3.0, "fietsen/fietsenrek", "E")
	Pr(78 * 4 + 2.0, 91 * 4 + 2.0, "straat/fontein")
	Pr(70 * 4 + 2.0, 90 * 4 + 1.0, "terras/stoepbord", "S")
	Pr(86 * 4 + 2.0, 92 * 4 + 3.0, "ov/reclamezuil")
	Pr(90 * 4 + 2.0, 91 * 4 + 2.0, "standbeelden/standbeeld_persoon", "S")


## First option that exists as p + option in the buildings library, else "blok_dicht".
func _first(p: String, options: Array) -> String:
	for o in options:
		if _has(p + o):
			return o
	return "blok_dicht"


# ------------------------------------------------------------------ traffic lights: all types in all states

## Signalised intersection centred on tiles (cx..cx+1, cz..cz+1) with 4-tile arms,
## kerbs, stop lines and zebra crossings. ns/ew = car light state per direction,
## ov_ns/ov_ew = public-transport light state, mast_ns/mast_ew = mast light state ("" = none).
func _intersection_with_lights(cx: int, cz: int, ns: String, ew: String, ov_ns: String, ov_ew: String, mast_ns: String, mast_ew: String) -> void:
	# roads: N-S at x = cx, cx+1; E-W at z = cz, cz+1; 4 tiles long per arm
	for i in range(-4, 6):
		if i == 0 or i == 1:
			continue  # the intersection itself
		# the two cells nearest to the intersection get a solid line (no overtaking)
		var near := absi(i) < 3
		G(cx, cz + i, "weg/rijstrook_streep_kant" if near else "weg/rijstrook_geen_kant", "N")
		G(cx + 1, cz + i, "weg/rijstrook_streep_kant" if near else "weg/rijstrook_onderbroken_kant", "S")
		G(cx + i, cz, "weg/rijstrook_streep_kant" if near else "weg/rijstrook_onderbroken_kant", "E")
		G(cx + i, cz + 1, "weg/rijstrook_streep_kant" if near else "weg/rijstrook_geen_kant", "W")
		G(cx - 1, cz + i, "stoep/stoep_rand", "E")
		G(cx + 2, cz + i, "stoep/stoep_rand", "W")
		G(cx + i, cz - 1, "stoep/stoep_rand", "S")
		G(cx + i, cz + 2, "stoep/stoep_rand", "N")
	G(cx + 1, cz + 2, "weg/rijstrook_stopstreep", "S")
	G(cx, cz - 1, "weg/rijstrook_stopstreep", "N")
	G(cx - 1, cz, "weg/rijstrook_stopstreep", "E")
	G(cx + 2, cz + 1, "weg/rijstrook_stopstreep", "W")
	for x in [cx, cx + 1]:
		for z in [cz, cz + 1]:
			G(x, z, "weg/weg_vlak")
	G(cx - 1, cz - 1, "stoep/stoep_hoek_buiten", "SE")
	G(cx + 2, cz - 1, "stoep/stoep_hoek_buiten", "WS")
	G(cx - 1, cz + 2, "stoep/stoep_hoek_buiten", "EN")
	G(cx + 2, cz + 2, "stoep/stoep_hoek_buiten", "NW")
	# pedestrians may cross a road while the traffic along the other road has green
	var ped_ns := "groen" if ns == "groen" else "rood"
	var ped_ew := "groen" if ew == "groen" else "rood"
	var L := "verkeerslichten/"
	# northbound traffic (coming from the south): lights on the southeast corner, facing south
	_light_corner(Vector2((cx + 2) * 4 + 1.0, (cz + 2) * 4 + 1.0), Vector2(1.5, 0), Vector2(0, 1.5), "S", ns, ov_ns, ped_ew, "W")
	if mast_ns != "":
		Pr((cx + 1) * 4 + 2.0, (cz + 4) * 4 + 2.0, L + "mast_" + mast_ns, "S")
	# southbound traffic: northwest corner
	_light_corner(Vector2((cx - 1) * 4 + 3.0, (cz - 1) * 4 + 3.0), Vector2(-1.5, 0), Vector2(0, -1.5), "N", ns, ov_ns, ped_ew, "E")
	# westbound traffic (coming from the east): northeast corner
	_light_corner(Vector2((cx + 2) * 4 + 1.0, (cz - 1) * 4 + 3.0), Vector2(0, -1.5), Vector2(1.5, 0), "E", ew, ov_ew, ped_ns, "S")
	if mast_ew != "":
		Pr((cx + 4) * 4 + 2.0, cz * 4 + 2.0, L + "mast_" + mast_ew, "E")
	# eastbound traffic: southwest corner
	_light_corner(Vector2((cx - 1) * 4 + 3.0, (cz + 2) * 4 + 1.0), Vector2(0, 1.5), Vector2(-1.5, 0), "W", ew, ov_ew, ped_ns, "N")
	for c in [[cx, cz - 2], [cx + 1, cz + 3], [cx - 2, cz + 1], [cx + 3, cz]]:
		G(c[0], c[1], "weg/zebrapad", "S" if c[0] <= cx + 1 and c[0] >= cx else "E")


## One corner of a signalised intersection: car light at pos (metres), bicycle light at
## pos + bike, public-transport light at pos + ov and the pedestrian light diagonally at
## pos + bike + ov. phase / ov_phase / ped_phase are the light states in the tile names.
func _light_corner(pos: Vector2, bike: Vector2, ov: Vector2, rot: String, phase: String, ov_phase: String, ped_phase: String, ped_rot: String) -> void:
	var L := "verkeerslichten/"
	Pr(pos.x, pos.y, L + "auto_" + phase, rot)
	Pr(pos.x + bike.x, pos.y + bike.y, L + "fiets_" + phase, rot)
	Pr(pos.x + ov.x, pos.y + ov.y, L + "ov_" + ov_phase, rot)
	Pr(pos.x + bike.x + ov.x, pos.y + bike.y + ov.y, L + "voetganger_" + ped_phase, ped_rot)


# ------------------------------------------------------------------ industrial estate: sheds, warehouse, factory

## Industrial building at tile (x0, z0), w x d tiles, `floors` storeys, ground floor
## tiles gf and roof "barrel", "sawtooth" or anything else for a flat roof with skylights.
func _ind_block(x0: int, z0: int, w: int, d: int, style: String, floors: int, gf: Array, roof: String) -> void:
	var cells := []
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d):
			cells.append(Vector2i(x, z))
	var upper := ["verd_wand", "verd_lichtstraat", "verd_wand", "verd_logo"]
	if style == "fabriek":
		upper = ["verd_raam_hoog"]
	_facades(cells, style, floors, gf, upper, ["bg_dicht_hoek", "bg_roldeur_hoek", "bg_kantoor_hoek"],
		["verd_lichtstraat_hoek"] if style != "fabriek" else ["verd_raam_hoog_hoek"], {})
	var p := style + "/" + style + "_"
	match roof:
		"barrel":
			for c in cells:
				B(c.x, floors, c.y, p + "dak_ton", "S")
		"sawtooth":
			for c in cells:
				B(c.x, floors, c.y, p + ("dak_shed_rand" if c.y == z0 else "dak_shed"), "N" if c.y == z0 else "N")
		_:
			var kinds := {"midden": ["dak_lichtstraten", "dak_plat_midden", "dak_lichtstraten"], "rand": ["dak_plat_rand"],
				"hoek": ["dak_plat_hoek"], "tegenover": ["dak_plat_tegenover"], "eind": ["dak_plat_eind"]}
			_flat_roofs(cells, style, floors, kinds, {})


## Industrial estate with sheds, warehouses, a factory with chimney, small units,
## a yard full of props, a staff car park and fencing.
func _industrial_estate() -> void:
	_district_name = "bedrijventerrein"
	var o := _district(62, 26)
	fill_rect(o.x + 1, o.y + 1, o.x + 60, o.y + 24, "plein/plein_tegels")
	var x0 := o.x + 2
	var z0 := o.y + 2
	# large steel shed (10x6, 9 m high) with loading docks and roller doors
	_ind_block(x0, z0, 10, 6, "loods_staal", 3, ["bg_dock", "bg_dock", "bg_roldeur", "bg_dock", "bg_loopdeur"], "flat")
	# shed with stone plinth and barrel roof
	_ind_block(x0 + 12, z0, 6, 4, "loods_steen", 2, ["bg_roldeur", "bg_loopdeur", "bg_kantoor"], "barrel")
	# warehouse with a row of loading docks
	_ind_block(x0 + 20, z0, 8, 6, "magazijn", 3, ["bg_dock"], "flat")
	# factory with sawtooth roof and factory chimney
	_ind_block(x0 + 30, z0, 8, 4, "fabriek", 2, ["bg_poort", "bg_dicht", "bg_loopdeur"], "sawtooth")
	_mast(x0 + 39, z0 + 1, "overig/fabrieksschoorsteen", 9)
	# small business units (various sizes and materials)
	_ind_block(x0 + 42, z0, 3, 2, "loods_staal", 1, ["bg_roldeur", "bg_loopdeur"], "flat")
	_ind_block(x0 + 46, z0, 4, 2, "loods_steen", 2, ["bg_roldeur", "bg_kantoor"], "flat")
	_ind_block(x0 + 51, z0, 5, 3, "magazijn", 2, ["bg_dock", "bg_kantoor", "bg_roldeur"], "flat")
	_ind_block(x0 + 42, z0 + 4, 6, 3, "fabriek", 2, ["bg_poort", "bg_loopdeur"], "flat")
	_ind_block(x0 + 50, z0 + 5, 6, 2, "loods_staal", 2, ["bg_kantoor", "bg_roldeur", "bg_dock"], "barrel")
	# yard: containers, pallets, forklift, silos, tank, cable reels, loading platform, fencing and gate
	var yz := (z0 + 8) * 4.0
	Pr((x0 + 2) * 4.0, yz + 6.0, "industrie/zeecontainer_stapel", "S")
	Pr((x0 + 8) * 4.0, yz + 4.0, "industrie/zeecontainer", "S")
	Pr((x0 + 8) * 4.0, yz + 8.0, "industrie/zeecontainer", "S")
	for i in 5:
		Pr((x0 + 12 + i) * 4.0, yz + 3.0, "industrie/pallet_stapel")
	Pr((x0 + 14) * 4.0, yz + 9.0, "industrie/heftruck", "W")
	Pr((x0 + 22) * 4.0, yz + 8.0, "industrie/silo")
	Pr((x0 + 26) * 4.0, yz + 8.0, "industrie/silo")
	Pr((x0 + 33) * 4.0, yz + 9.0, "industrie/opslagtank")
	Pr((x0 + 38) * 4.0, yz + 4.0, "industrie/kabelhaspel")
	Pr((x0 + 39) * 4.0, yz + 4.0, "industrie/kabelhaspel")
	Pr((x0 + 24) * 4.0, (z0 + 6) * 4.0 + 2.0, "industrie/laadperron", "S")
	# second row: distribution centre (12x8) and a stone shed, with loading docks facing the yard
	_ind_block(x0 + 22, z0 + 14, 14, 8, "magazijn", 4, ["bg_dock"], "flat")
	_ind_block(x0 + 38, z0 + 15, 8, 5, "loods_steen", 3, ["bg_roldeur", "bg_dock", "bg_loopdeur"], "barrel")
	_ind_block(x0 + 48, z0 + 15, 8, 6, "loods_staal", 3, ["bg_dock", "bg_roldeur", "bg_kantoor"], "flat")
	# staff car park and a green strip with trees
	for x in range(x0, x0 + 18):
		G(x, z0 + 15, "parkeren/parkeervak_haaks", "N")
		G(x, z0 + 16, "parkeren/parkeerplaats_rijbaan", "E")
		G(x, z0 + 17, "parkeren/parkeervak_haaks", "S")
	for x in range(x0, x0 + 18):
		G(x, z0 + 19, "natuur/gras")
		G(x, z0 + 20, "natuur/gras")
		if x % 3 == 0:
			Pr(x * 4 + 2.0, (z0 + 19) * 4 + 4.0, "bomen/populier" if x % 2 else "bomen/linde")
	for x in [x0 + 4, x0 + 9, x0 + 14]:
		Pr(x * 4.0, (z0 + 15) * 4 + 1.0, "paaltjes/laadpaal", "N")
	# more yard furnishing: container rows, pallets and cable reels at the docks
	for i in 3:
		Pr((x0 + 2 + i * 6) * 4.0, (z0 + 11) * 4.0, "industrie/zeecontainer_stapel", "S")
	for i in 8:
		Pr((x0 + 22 + i * 1.5) * 4.0, (z0 + 12) * 4.0, "industrie/pallet_stapel")
	Pr((x0 + 30) * 4.0, (z0 + 12) * 4.0, "industrie/heftruck", "E")
	Pr((x0 + 44) * 4.0, (z0 + 12) * 4.0, "industrie/zeecontainer", "E")
	Pr((x0 + 50) * 4.0, (z0 + 12) * 4.0, "industrie/opslagtank")
	for x in range(o.x + 1, o.x + 60, 6):
		Pr(x * 4 + 3.0, (o.y + 25) * 4 - 0.5, "hekken/hek_industrie", "S")
	Pr((o.x + 30) * 4.0, (o.y + 25) * 4 - 1.0, "hekken/schuifpoort_industrie", "S")
	Pr((o.x + 44) * 4.0, (o.y + 25) * 4 - 1.5, "hekken/slagboom", "S")


# ------------------------------------------------------------------ tint demo: the same buildings with different tints

## Adds a tint area (tint_area.gd) to the tint map: pos in metres (centre), colour,
## area_size in tiles, brightness multiplier and node name.
func _tint_area(pos: Vector3, color: Color, area_size: Vector2i, brightness := 1.0, node_name := "TintVlak") -> void:
	var tv := Node3D.new()
	tv.name = node_name
	tv.set_script(load("res://scripts/tint_area.gd"))
	tv.position = pos
	tv.set("color", color)
	tv.set("size", area_size)
	tv.set("brightness", brightness)
	tint_map.add_child(tv, true)


## Tint demo: a residential street with three terraces of identical houses, each house
## with its own tint (warm, cool, greenish, lighter, darker, ochre, pink), facing a
## street through the district; gardens behind; on the corner a block whose tint
## also covers the ground in front of it.
func _tint_demo() -> void:
	_district_name = "tint"
	var o := _district(30, 18)
	var tints := [
		["origineel", Color(1, 1, 1), 1.0], ["warm", Color(1.0, 0.8, 0.62), 1.0], ["koel", Color(0.75, 0.86, 1.1), 1.0],
		["groenig", Color(0.82, 1.0, 0.78), 1.0], ["lichter", Color(1, 1, 1), 1.35], ["donkerder", Color(1, 1, 1), 0.65],
		["oker", Color(1.1, 0.95, 0.6), 1.0], ["rozig", Color(1.1, 0.82, 0.86), 1.0],
	]
	# the street (z 7, 8) right through the district, joining the streets west and east
	var zs := o.y + 7
	for x in range(o.x, o.x + 30):
		G(x, zs, "weg/rijstrook_onderbroken_kant", "E")
		G(x, zs + 1, "weg/rijstrook_geen_kant", "W")
		for z in [zs, zs + 1]:
			_pavement.erase(Vector2i(x, z))
			_taken[Vector2i(x, z)] = true
	for x in range(o.x + 1, o.x + 29):
		for z in [zs - 1, zs + 2]:
			G(x, z, "stoep/stoep_vol")
			_pavement[Vector2i(x, z)] = ""
			_taken[Vector2i(x, z)] = true
		if x % 3 == 0:
			Pr(x * 4 + 2.0, (zs - 1) * 4 + 1.0, "bomen/linde")
			Pr(x * 4 + 2.0, (zs + 3) * 4 - 1.0, "verlichting/lantaarn_modern", "N")
	# terraces: [style, front row, facing]; houses one cell wide, two deep
	var rows := [["klassiek_rood", zs - 3, "S"], ["modern_wit", zs + 3, "N"], ["jaren30", zs + 7, "N"]]
	for r in rows:
		var style: String = r[0]
		var front: int = r[1]
		var facing: String = r[2]
		var back := front - 1 if facing == "S" else front + 1
		var p := style + "/" + style + "_"
		for i in tints.size():
			var x := o.x + 2 + i
			for zz in [front, back]:
				var face := facing if zz == front else ("N" if facing == "S" else "S")
				var gf: String = (("bg_deur" if zz == front else "bg_raam") if _has(p + "bg_deur") else _first(p, ["bg_raam", "bg_portiek"]))
				B(x, 0, zz, p + gf, face)
				B(x, 1, zz, p + _first(p, ["verd_raam", "verd_balkon"]), face)
				if _has(p + "dak_schuin"):
					B(x, 2, zz, p + "dak_schuin", face)
				else:
					B(x, 2, zz, p + ("dak_plat_rand" if _has(p + "dak_plat_rand") else "dak_plat_midden"), face)
			var t: Array = tints[i]
			if t[0] != "origineel":
				_tint_area(Vector3(x * 4 + 2.0, 0, (mini(front, back) + 1) * 4.0), t[1], Vector2i(1, 2), t[2], "Tint_" + style + "_" + t[0])
			# back garden
			var garden := back - 1 if facing == "S" else back + 1
			G(x, garden, "natuur/gras_kort")
			_taken[Vector2i(x, garden)] = true
	# corner block with a tint over the block and the ground in front of it
	var bx := o.x + 12
	var bz := zs - 4
	var cells := []
	for x in range(bx, bx + 2):
		for z in range(bz, bz + 3):
			cells.append(Vector2i(x, z))
	var kit := _style_kit("klassiek_geel")
	_facades(cells, "klassiek_geel", 3, ["bg_raam"], ["verd_raam"], ["bg_raam_hoek"], ["verd_raam_hoek"], {})
	_roof(cells, "klassiek_geel", 3, kit, {})
	_tint_area(Vector3(bx * 4 + 4.0, 0, (bz + 2) * 4.0), Color(0.7, 0.85, 1.15), Vector2i(2, 4), 1.0, "Tint_blok_inclusief_grond")


# ------------------------------------------------------------------ slopes and curves

## 3-lane tunnel cross-section, from the "wand" side to the "wand_rechts" side.
const TUNNEL_LANES := ["%s_wand%s", "%s%s", "%s_wand_rechts%s"]


## District with curves that change height: a tunnel with a bend in it (more to follow).
func _slopes_and_curves() -> void:
	_district_name = "hellingen_bochten"
	var o := _district(24, 24)
	_tunnel_with_bend(o.x + 15, o.y + 7, o)


# ------------------------------------------------------------------ flyovers: rising and elevated curves

## Straight ramp parts per curve profile (pavements without a kerb, which would lie across a ramp).
const RAMP_PARTS := {"straat": ["stoep_vol", "weg_vlak", "stoep_vol"], "klinkerstraat": ["stoep_vol", "straat_klinkers", "stoep_vol"],
	"weg": ["stoep_vol", "weg_vlak", "weg_vlak", "stoep_vol"], "fietspad": ["stoep_vol", "fietspad_recht", "stoep_vol"]}
const LOOP_PROFILES := ["straat", "klinkerstraat", "fietspad", "weg"]


## Two districts of turning loops over the rising and elevated curves of every profile
## that has them (tools/voxgen/ground4.py): per profile a loop on an embankment (a left-
## and a right-rising curve back to back, fill blocks under the high cells) and one as a
## bridge (embankment cells on the ground, bridge cells with piers above), and a district
## with flat curved bridges on piers, reached by straight bridge ramps. The legs run
## down to the street south of the district.
func _flyovers() -> void:
	_district_name = "keerlussen"
	var o := _district(78, 10)
	var x := o.x + 1
	for kind in ["dijk", "brug"]:
		for profile in LOOP_PROFILES:
			var n: int = 1 + PROFILES[profile].size()
			_curve_loop(x, o.y + 1, o.y + 9, profile, kind)
			x += 2 * n + 1
	_district_name = "viaductbochten"
	o = _district(40, 11)
	x = o.x + 1
	for profile in LOOP_PROFILES:
		var n: int = 1 + PROFILES[profile].size()
		_curve_loop(x, o.y + 1, o.y + 10, profile, "vlak")
		x += 2 * n + 1


## A turning loop of `profile` with its west edge at x0, top row z0, legs down to row z1
## (inclusive). Curve A (rotation 0) comes from the south and turns west, curve B
## (rotation 1, west of A) turns south again; kind "dijk": A rises, B descends, on an
## embankment two floors up (fill blocks below); "brug": the same as bridge decks (piers
## below); "vlak": flat curved bridge decks on floor 2. Ramps in the legs lead up.
func _curve_loop(x0: int, z0: int, z1: int, profile: String, kind: String) -> void:
	var parts: Array = PROFILES[profile]
	var w := parts.size()
	var n := 1 + w
	var a := Vector2i(x0 + n, z0 + n - 1)
	var lift: int = {"dijk": 2, "brug": 1, "vlak": 2, "plat": 0}[kind]
	for half in 2:
		var origin := a + Vector2i(-half, 0)
		var right := half == 1
		for i in n:
			for j in n:
				var c: Vector2i = origin + _rotate_offset(Vector2i(i, -j), half)
				var f: int = lift if kind in ["vlak", "plat"] else _rising_floor(profile, i, j, right) + lift
				var cell := "%s%s_%d_%d" % [profile, "_rechts" if right else "", i, j]
				var nm := "helling_bocht/" + ("brug_" if kind == "brug" else "") + cell
				if kind == "vlak":
					nm = "brug/bocht_%s_%d_%d" % [profile, i, j]
				elif kind == "plat":
					nm = "bocht/%s_%d_%d" % [profile, i, j]
				if not _has(nm, ground):
					continue
				G(c.x, c.y, nm, half, f)
				if kind == "plat":
					continue
				if kind == "dijk":
					if f > 0:
						G(c.x, c.y, "helling_bocht/ophoging_gras_%dx%d_%d_%d" % [n, n, i, j], half, 0)
						for y in range(1, f):
							G(c.x, c.y, "helling_bocht/ophoging_%dx%d_%d_%d" % [n, n, i, j], half, y)
				elif _pier_cell(i, j, w):
					if f == 1:
						G(c.x, c.y, "brug/brug_pijler_gras", "S", 0)
					else:
						_pier(c.x, c.y, "brug/brug_pijler_gras", 0, f - 1)
	# legs: lane d of A's start at x a.x+1+d, of B's end at x a.x-2-d, heading south
	var ramp: Array = RAMP_PARTS.get(profile, [])
	for r in range(1, z1 - a.y + 1):
		for d in w:
			for leg in 2:
				var c := Vector2i(a.x + 1 + d if leg == 0 else a.x - 2 - d, a.y + r)
				if r <= lift:
					# bridge ramp up to the deck, parapets on the outer edges
					var edge := ""
					if d == 0:
						edge = "_rand" if leg == 0 else "_rand_rechts"
					elif d == w - 1:
						edge = "_rand_rechts" if leg == 0 else "_rand"
					var part: String = ramp[d]
					if edge != "" and not _has("helling/helling_brug_%s%s" % [part, edge], ground):
						edge = ""
					if kind == "dijk":
						G(c.x, c.y, "helling/helling_" + part, "S", lift - r)
					else:
						G(c.x, c.y, "helling/helling_brug_%s%s" % [part, edge], "S", lift - r)
				else:
					G(c.x, c.y, parts[d][0], int(parts[d][1]) % 4)


## Floor of cell (i, j) of the rising curve of `profile` (left, or right with `right`):
## the floor of its lowest point, as curve_floors() in tools/voxgen/ground4.py.
func _rising_floor(profile: String, i: int, j: int, right: bool) -> int:
	var vox = VoxLib.new()
	vox.size = Vector3i(32, 32, 12)
	var plan: Dictionary = SlopesLib.plan(vox, "bocht_rechts" if right else "bocht", {"curve": [i, j, PROFILES[profile].size()]})
	return int(plan.base) / 8


## True if a round pier fits under the centre of cell (i, j) of the bridge curve of a
## w-part profile (pier_cell() in tools/voxgen/ground4.py).
func _pier_cell(i: int, j: int, w: int) -> bool:
	var r := Vector2(i * 32 + 16, j * 32 + 16).length()
	return 32 + 5.2 <= r and r <= 32 + w * 32 - 5.2


## Car tunnel on floor -6 that turns 90 degrees underground (tunnel/bocht_<i>_<j>, a 4x4
## curve whose centre is the south-west corner of tile (hx, hz)). Legs to the south and
## to the west, each: 3 covered tiles, portal, open trough, 6-step ramp, road to the
## district edge. Streets cross both covered legs on street level.
func _tunnel_with_bend(hx: int, hz: int, o: Vector2i) -> void:
	for i in 4:
		for j in 4:
			if i < 3 or j < 3:
				G(hx + i, hz - j, "tunnel/bocht_%d_%d" % [i, j], 0, -6)
	# south leg: lane d at x = hx+1+d; leaving the tunnel heading south
	_tunnel_leg(func(r, d): return Vector2i(hx + 1 + d, hz + r), 0, o.y + 24 - hz)
	# west leg: lane d at z = hz-1-d; leaving the tunnel heading west
	_tunnel_leg(func(r, d): return Vector2i(hx - r, hz - 1 - d), 1, hx - o.x + 1)
	# streets over the covered parts
	for x in range(hx - 3, o.x + 24):
		G(x, hz + 2, "weg/weg_vlak", "E")
	for z in range(o.y, hz + 2):
		G(hx - 2, z, "weg/weg_vlak", "S")


## One leg of a tunnel, counted outwards from the bend: r = 1..3 covered tunnel, then the
## portal, 2 trough tiles and a ramp of 6 steps up, then flat road until r = length - 1.
## cell(r, d) gives the tile of lane d at distance r. rot = rotation of the straight
## tunnel tiles in this leg (as in the curve guide, tools/voxgen/ground4.py). The
## portal, trough and ramp face into the tunnel: for the south leg (rot 0) that is the
## opposite way, so they turn 180 degrees and their lanes swap sides.
func _tunnel_leg(cell: Callable, rot: int, length: int) -> void:
	var into := rot if rot % 2 == 1 else (rot + 2) % 4
	for r in range(1, length):
		for d in 3:
			var c: Vector2i = cell.call(r, d)
			var lane: String = TUNNEL_LANES[d if into == rot else 2 - d]
			if r <= 3:
				G(c.x, c.y, TUNNEL_LANES[d] % ["tunnel/tunnel_rijstrook", ""], rot, -6)
			elif r == 4:
				G(c.x, c.y, lane % ["tunnel/tunnel_rijstrook", "_portaal"], into, -6)
			elif r <= 6:
				_trench(c.x, c.y, lane % ["tunnel/tunnelbak_rijstrook", "_d6"], 6, into)
			elif r <= 12:
				var depth := 13 - r
				_trench(c.x, c.y, lane % ["tunnel/tunnel_toerit", "_d%d" % depth], depth, into)
			else:
				G(c.x, c.y, "weg/weg_vlak", into)


# ------------------------------------------------------------------ rounded curves: streets that turn the corner

## Street profiles: parts from inner curve to outer curve, as [tile, rotation] for a
## straight road running from south to north.
const PROFILES := {
	"straat": [["stoep/stoep_rand", 1], ["weg/weg_vlak", 0], ["stoep/stoep_rand", 3]],
	"klinkerstraat": [["stoep/stoep_klinker_rand", 1], ["weg/straat_klinkers", 0], ["stoep/stoep_klinker_rand", 3]],
	"weg": [["stoep/stoep_goot_rand", 1], ["weg/rijstrook_geen_kant", 2], ["weg/rijstrook_onderbroken_kant", 0], ["stoep/stoep_goot_rand", 3]],
	"hoofdweg": [["stoep/stoep_goot_rand", 1], ["fietspad/fietspad_recht", 0], ["weg/rijstrook_geen_kant", 2],
		["weg/rijstrook_onderbroken_kant", 0], ["fietspad/fietspad_recht", 0], ["stoep/stoep_goot_rand", 3]],
	"tramweg": [["stoep/stoep_rand", 1], ["tram/tram_rijstrook_geen_kant", 2], ["tram/tram_rijstrook_onderbroken_kant", 0], ["stoep/stoep_rand", 3]],
	"laan": [["stoep/stoep_rand", 1], ["weg/rijstrook_onderbroken_kant", 2], ["weg/rijstrook_geen_geen", 2], ["weg/middenberm_gras", 1],
		["weg/rijstrook_geen_geen", 0], ["weg/rijstrook_onderbroken_kant", 0], ["stoep/stoep_rand", 3]],
	"fietspad": [["natuur/gras", 0], ["fietspad/fietspad_recht", 0], ["natuur/gras", 0]],
}


## Rotates a tile offset by k quarter turns (same direction as the tile rotations).
func _rotate_offset(o: Vector2i, k: int) -> Vector2i:
	var v := o
	for i in (k % 4 + 4) % 4:
		v = Vector2i(v.y, -v.x)
	return v


## Lays a rounded curve of a street profile. (hx, hz) = the tile whose north-west corner
## is the centre of the curve; k = rotation in quarter turns; straight = length in tiles
## of the straight sections. The road comes from the south and turns off to the west (k=0).
func curve(hx: int, hz: int, profile: String, k := 0, straight := 3) -> void:
	var parts: Array = PROFILES[profile]
	var n: int = 1 + parts.size()
	for i in n:
		for j in n:
			var o := _rotate_offset(Vector2i(i, -j), k)
			G(hx + o.x, hz + o.y, "bocht/%s_%d_%d" % [profile, i, j], k)
	# straight sections: to the south (below the curve) and to the west (left)
	for d in parts.size():
		var part: Array = parts[d]
		for r in range(1, straight + 1):
			var o1 := _rotate_offset(Vector2i(1 + d, r), k)
			G(hx + o1.x, hz + o1.y, part[0], (int(part[1]) + k) % 4)
			var o2 := _rotate_offset(Vector2i(-r, -(1 + d)), k)
			G(hx + o2.x, hz + o2.y, part[0], (int(part[1]) + 3 + k) % 4)


## District with a residential loop street for every street profile in PROFILES: two
## rounded curves back to back (a U), whose legs join the street south of the district;
## a small playground inside each loop.
func _curves() -> void:
	_district_name = "bochten"
	var o := _district(92, 12)
	var x := o.x + 1
	for profile in ["straat", "klinkerstraat", "weg", "tramweg", "fietspad", "hoofdweg", "laan"]:
		var n: int = 1 + PROFILES[profile].size()
		if x + 2 * n > o.x + 91:
			break
		_curve_loop(x, o.y + 11 - n - 2, o.y + 11, profile, "plat")
		# playground in the middle of the loop
		Pr((x + n - 1) * 4.0 + 2.0, (o.y + 11) * 4.0 - 4.0, "speeltuin/" + ["schommel", "glijbaan", "wipwap", "zandbak"][profile.length() % 4])
		x += 2 * n + 1


# ------------------------------------------------------------------ village centre with cobblestones

## Village centre with a cobbled green, cobblestone streets, a church tower and cottages.
func _village_centre() -> void:
	_district_name = "dorpskern"
	var o := _district(30, 20)
	fill_rect(o.x + 1, o.y + 1, o.x + 28, o.y + 18, "natuur/gras")
	var cx := o.x + 14
	var cz := o.y + 9
	# village green (village square) with cobblestones and a tree
	fill_rect(cx - 3, cz - 2, cx + 3, cz + 2, "plein/plein_keien")
	Pr(cx * 4 + 2.0, cz * 4 + 2.0, "bomen/linde")
	Pr((cx - 2) * 4 + 2.0, cz * 4 + 2.0, "straat/bank_hout", "E")
	Pr((cx + 2) * 4 + 2.0, cz * 4 + 2.0, "straat/bank_hout", "W")
	Pr((cx + 1) * 4 + 2.0, (cz - 1) * 4 + 2.0, "verlichting/lantaarn_klassiek")
	# cobblestone streets from the square, with cobblestone pavements and a central gutter
	for z in range(o.y + 1, cz - 2):
		G(cx, z, "weg/straat_keien_middengoot")
		G(cx - 1, z, "stoep/stoep_keien_rand", "E")
		G(cx + 1, z, "stoep/stoep_keien_rand", "W")
	for z in range(cz + 3, o.y + 19):
		G(cx, z, "weg/straat_keien")
		G(cx - 1, z, "stoep/stoep_keien_rand", "E")
		G(cx + 1, z, "stoep/stoep_keien_rand", "W")
	for x in range(o.x + 1, cx - 3):
		G(x, cz, "weg/straat_keien", "E")
		G(x, cz - 1, "stoep/stoep_keien_rand", "S")
		G(x, cz + 1, "stoep/stoep_keien_rand", "N")
	# cobblestone path to the church
	for x in range(cx + 4, o.x + 26):
		G(x, cz, "natuur/keienpad", "E")
	tower(o.x + 26, cz, "kerk_baksteen", ["toren_portaal", "toren_raam", "toren_klok", "toren_spits_onder", "toren_spits_boven"], "W")
	# classic cottages around the village green
	for i in range(4):
		var hx := cx - 3 + i * 2
		for zz in [cz - 4, cz + 4]:
			var facing := "S" if zz < cz else "N"
			B(hx, 0, zz, "klassiek_rood/klassiek_rood_" + ["bg_deur", "bg_raam", "bg_winkel_luifel", "bg_deur"][i], facing)
			B(hx, 1, zz, "klassiek_rood/klassiek_rood_dak_zadel", "E")
	Pr((cx - 3) * 4.0, (cz - 2) * 4.0, "paaltjes/amsterdammertje")
	Pr((cx + 4) * 4.0, (cz + 3) * 4.0, "paaltjes/amsterdammertje")
