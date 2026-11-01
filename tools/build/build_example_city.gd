extends "res://tools/build/city/situations.gd"
## Builds the example map: a small Dutch town showcasing all tiles, saved in parts
## (scenes/wereld/deel_*.tscn) with the tour scene scenes/rondleiding.tscn that shows
## them one by one (scripts/world/world_parts.gd), and scenes/nieuwe_kaart.tscn: an empty map
## with the same setup.
## usage: tools/godot.sh --headless --script tools/build/build_example_city.gd
##
## CODE LAYOUT
## This file holds only the build order (_init, _build_town, _expansion, _demo_districts).
## The rest lives in tools/build/city/, a chain of scripts that each extend the previous
## one: base (state, scene setup, G/B/D/Pr) -> kit (reusable helpers) -> old_town ->
## expansion -> street_grid -> neighbourhoods -> situations -> this file.
##
## HOW IT WORKS
## Both scenes get the same root setup (_make_scene): environment, sun and fill light,
## camera, helper nodes (DetailNiveau, Dagcyclus, Rook, TintKaart, GrondKaart, Grassprieten,
## Wandelaar) and four GridMaps,
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
	WorldParts.save_split(world, Common.WORLD, WORLD_PARTS)
	world.free()
	var empty := _make_scene("NieuweKaart")
	_own_tints(empty)
	_save(empty, "res://scenes/nieuwe_kaart.tscn")
	if missing.size() > 0:
		print("MISSING TILES: ", missing.keys())
	quit()


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
