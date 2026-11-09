extends SceneTree
## City builder, part 1: shared constants, the build state, the scene setup
## (_make_scene, _save) and the placement primitives G/B/D/Pr.
##
## The builder is a chain of scripts, each extending the previous one. A part may only use
## what is defined in itself or an earlier part.
##   General, for any town:
##     1 base         this file
##     2 kit          building blocks, rings, towers, halls, parking decks, styles
##     3 street_grid  streets with markings, signalised crossings and kerbs
##   This town (The Hague):
##     4 map          the plan: street grid, names, shared structures, small helpers
##     5 streets      its streets, the singel with quays and bridges
##     6 old_centre   inside the singel
##     7 east         east of the singel
##     8 south        south of the viaducts
##     9 a12          the motorway and Voorburg
##    10 rail         trams, tram tunnel, viaducts, railway
##    11 finishing    passes over the whole town, scene nodes
##   tools/build/build_city.gd: the entry point (the order of the build).
##
## HOW IT WORKS
## The scene gets its root setup from _make_scene: environment, sun and fill light,
## camera, helper nodes (DetailNiveau, Dagcyclus, Rook, TintKaart, GrondKaart, Grassprieten)
## and four GridMaps,
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


const Common = preload("res://tools/tool_common.gd")
const LIB := "res://assets/libraries/%s.res"
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
var _taken := {}    # cells (x,z) holding something other than plain grass or pavement (any layer)


# ------------------------------------------------------------------ scene

## How far the Details and Props layers float over the surface they stand on (m): their
## undersides would otherwise lie in the same plane as the ground's top and flicker.
const GROUND_CLEARANCE := 0.02


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
	# soft glow only round the lamps (emit material, energy 6): a lower threshold and more glow
	# blurred every bright edge, so things ran into each other
	e.glow_enabled = true
	e.glow_intensity = 0.25
	e.glow_hdr_threshold = 1.8
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.12
	e.adjustment_contrast = 1.22
	e.fog_enabled = false
	e.fog_light_color = Color(0.7, 0.78, 0.88)
	e.fog_density = 0.0005
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "Zon"
	# sun from south-southeast: in the isometric view (looking northwest)
	# both the south and east facades get light, with clear shadows.
	sun.rotation_degrees = Vector3(-62, 27, 0)
	sun.light_energy = 1.55
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.9
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.5
	sun.shadow_blur = 0.1   # crisp shadow edges
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
	details = _gridmap("Details", "details", Vector3(0.5, 0.5, 0.5), false, 0.375 + GROUND_CLEARANCE)
	props = _gridmap("Props", "props", Vector3(0.5, 0.5, 0.5), false, 0.25 + GROUND_CLEARANCE)
	for gm in [ground, buildings, details, props]:
		root.add_child(gm)
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.set_script(load("res://scripts/camera/free_camera.gd"))
	# isometric camera, aimed at the centre of the old town
	var focus := Vector3(72, 0, 60)
	var Iso = load("res://scripts/camera/iso_camera.gd")
	cam.position = Iso.position(focus, 140.0)
	cam.rotation_degrees = Iso.ROTATION
	cam.fov = Iso.FOV
	cam.near = 2.0
	cam.far = 6000.0
	root.add_child(cam)
	var dn := Node.new()
	dn.name = "DetailNiveau"
	dn.set_script(load("res://scripts/world/level_of_detail.gd"))
	root.add_child(dn)
	var dc := Node.new()
	dc.name = "Dagcyclus"
	dc.set_script(load("res://scripts/world/day_cycle.gd"))
	root.add_child(dc)
	var tl := Node.new()
	tl.name = "Verkeerslichten"
	tl.set_script(load("res://scripts/traffic/traffic_lights.gd"))
	root.add_child(tl)
	var arrows := Node3D.new()
	arrows.name = "Rijrichtingen"   # editor only: the driving direction of every lane
	arrows.set_script(load("res://scripts/traffic/lane_arrows.gd"))
	root.add_child(arrows)
	var smoke := Node3D.new()
	smoke.name = "Rook"
	smoke.set_script(load("res://scripts/effects/smoke.gd"))
	root.add_child(smoke)
	var tk := Node3D.new()
	tk.name = "TintKaart"
	tk.set_script(load("res://scripts/world/tint_map.gd"))
	root.add_child(tk)
	var gk := Node.new()
	gk.name = "GrondKaart"
	gk.set_script(load("res://scripts/world/ground_map.gd"))
	root.add_child(gk)
	var overhead := Node3D.new()
	overhead.name = "Bovenleiding"   # contact wires over the tram and train tracks
	overhead.set_script(load("res://scripts/world/overhead_lines.gd"))
	root.add_child(overhead)
	var gb := Node3D.new()
	gb.name = "Grassprieten"
	gb.set_script(load("res://scripts/world/grass_blades.gd"))
	root.add_child(gb)
	var hud := CanvasLayer.new()
	hud.name = "HUD"   # player stats, minimap, clock, quests, money (scripts/ui/hud.gd)
	hud.set_script(load("res://scripts/ui/hud.gd"))
	root.add_child(hud)
	tint_map = tk
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


## Packs root into a PackedScene, saves it to scene_path and frees the tree. The scene
## is marked as a Vox Tiles scene (fast editor view and build tools, see the plugin).
func _save(root: Node3D, scene_path: String) -> void:
	root.set_meta("vox_tiles", true)
	keep_lane_choices(root, scene_path)
	var ps := PackedScene.new()
	ps.pack(root)
	var err := ResourceSaver.save(ps, scene_path)
	print("saved: ", scene_path, " (", err, ")")
	root.free()


## Copies the lanes chosen by hand in the editor (RoadNetwork.LANE_CHOICES on Grond) from
## the scene about to be overwritten, so building again does not lose them; the choices
## the builder made itself (kit.gd, _choose_lanes, marked "by_builder") are made anew and go
## over them. A choice only counts
## while the same tile is in its cell (road_network.gd).
static func keep_lane_choices(root: Node3D, scene_path: String) -> void:
	var ground := root.get_node_or_null("Grond")
	if ground == null or not ResourceLoader.exists(scene_path):
		return
	var state: SceneState = (load(scene_path) as PackedScene).get_state()
	var property := "metadata/" + String(RoadNetwork.LANE_CHOICES)
	for node_index in state.get_node_count():
		if state.get_node_name(node_index) != &"Grond":
			continue
		for property_index in state.get_node_property_count(node_index):
			if state.get_node_property_name(node_index, property_index) == property:
				var kept := {}
				var old_choices: Dictionary = state.get_node_property_value(node_index, property_index)
				for cell: Vector3i in old_choices:
					if not old_choices[cell].get("by_builder", false):
						kept[cell] = old_choices[cell]   # chosen by hand
				kept.merge(ground.get_meta(RoadNetwork.LANE_CHOICES, {}), true)
				ground.set_meta(RoadNetwork.LANE_CHOICES, kept)


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


# ------------------------------------------------------------------ map size

const W := 96  # map width in tiles
# ------------------------------------------------------------------ build state of the demo districts (street_grid.gd and later)

var _street_h := {}   # Vector2i -> lane (0 north, 1 south) of the east-west streets
var _street_v := {}   # Vector2i -> lane (0 west, 1 east) of the north-south streets
var _pavement := {}   # Vector2i -> kerb variant ("", "goot_", "klinker_") of the pavement cells (_auto_kerbs)
var _kerb_count := 0  # counter for the kerb variant of the next block
var lights_last_column := 1 << 20   # traffic lights only at intersections up to this column
var _special := {}    # street cells that are not ordinary lanes (roundabouts, avenues)
var _h_rows := []     # z of the north lane of every full-width east-west street
var districts := []  # {name, x, z, w, d} per demo district, saved as scene metadata
var places := {}     # slug -> Vector2 (metres) of spots found while building, saved as scene metadata (tour stops)
