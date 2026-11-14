extends "res://tools/build/city/rail.gd"
## City builder, part 11 (see base.gd for the chain): the passes over the whole town once
## every district stands (grass, paths, roof equipment, facades and signs that clash,
## trees in buildings, bins) and the scene nodes it adds (camera, a car, the Zebraklok, the
## helicopter flights).


# ------------------------------------------------------------------ east of the singel

## The Zebraklok on the square before Centraal Station (Jaap Karman, 1977): a node with
## scripts/world/town/zebra_clock.gd, which builds the clock and sets its hands to the time.
func _zebra_clock(root: Node3D) -> void:
	var clock := Node3D.new()
	clock.name = "Zebraklok"
	clock.set_script(load("res://scripts/world/town/zebra_clock.gd"))
	clock.position = Vector3(ZEBRA_CLOCK_AT.x, 0.0, ZEBRA_CLOCK_AT.y)
	clock.rotation_degrees.y = ZEBRA_CLOCK_TURN
	root.add_child(clock)
	clock.owner = root


## Now and then the police helicopter flies over the town (scripts/traffic/helicopter_flights.gd).
func _helicopter_flights(root: Node3D) -> void:
	var flights := Node3D.new()
	flights.name = "Helikoptervluchten"
	flights.set_script(load("res://scripts/traffic/helicopter_flights.gd"))
	root.add_child(flights)
	flights.owner = root


# ------------------------------------------------------------------ trams

## Styles whose roofs stay bare: churches, museums, the Binnenhof and other monuments,
## halls and structures.
const BARE_ROOF_STYLES := ["kerk_baksteen", "kerk_steen", "kerk_modern", "museum_klassiek", "museum_modern", "herenhuis_1600",
	"overheid", "universiteit", "hallen", "pilaren", "overkapping", "parkeergarage", "overig", "daken"]
## Building groups by what they put on their roofs.
const OFFICE_STYLES := ["kantoor_2000", "kantoor_80", "kantoor_beton", "kantoor_glas", "kantoor_modern", "hogeschool", "school"]
const FLAT_STYLES := ["galerijflat", "jaren60", "appartement_modern", "luxe_appartement", "modern_donker", "modern_hout", "modern_wit"]
const INDUSTRY_STYLES := ["loods_staal", "loods_steen", "magazijn", "fabriek", "bedrijfspand"]
## Antennas on the roofs of tall buildings (from this storey), metres between two of them.
const ANTENNAS := ["dak/zendmast", "dak/telecom_antennes", "dak/zendmast_klein", "dak/telecom_antennes"]
const ANTENNA_FROM_STOREY := 8
const ANTENNA_SPACING := 60.0


## What stands on the roofs, where it makes sense: on offices installation roofs, air
## handlers and cooling units; on flats solar panels and vents; on halls and factories
## big fields of solar panels; on houses solar panels on the slopes facing south or west
## and now and then an air conditioner. Churches, museums and monuments stay bare
## (BARE_ROOF_STYLES). Chosen per cell from its position, so a rebuild gives the same.
func _roof_equipment() -> void:
	var antennas: Array[Vector2] = []
	for cell: Vector3i in buildings.get_used_cells():
		if buildings.get_cell_item(cell + Vector3i.UP) >= 0:
			continue
		var tile_name := buildings.mesh_library.get_item_name(buildings.get_cell_item(cell))
		var style := tile_name.get_slice("/", 0)
		if style in BARE_ROOF_STYLES:
			continue
		var piece := tile_name.get_slice("/", 1).trim_prefix(style + "_")
		var flat_middle := piece in ["dak_plat_midden", "dak_bitumen_midden", "dak_grind_midden"]
		var flat_edge := piece in ["dak_plat_rand", "dak_bitumen_rand", "dak_grind_rand"]
		var pick := _r(cell.x * 7 + cell.y, cell.z * 3 + 1, 12)
		var prefix := style + "/" + style + "_"
		var side := _front_of(cell)
		var roof_height := cell.y * 3.0
		var spot := Vector2(cell.x * 4 + 2.0, cell.z * 4 + 2.0)
		var turn: String = ["S", "E", "N", "W"][pick % 4]
		# here and there a radio mast or telecom antennas on a tall flat roof
		if flat_middle and cell.y >= ANTENNA_FROM_STOREY and pick == 11 \
				and antennas.all(func(other: Vector2) -> bool: return other.distance_to(spot) > ANTENNA_SPACING):
			D(spot.x, spot.y, roof_height, ANTENNAS[_r(cell.x, cell.z, ANTENNAS.size())], turn)
			antennas.append(spot)
			continue
		if style in OFFICE_STYLES:
			if flat_middle and pick < 3 and _has(prefix + "dak_installatie"):
				B(cell.x, cell.y, cell.z, prefix + "dak_installatie", "S")
			elif flat_middle and pick < 5:
				D(spot.x, spot.y, roof_height, "dak/luchtbehandeling" if pick == 3 else "dak/koelinstallatie", turn)
			elif flat_middle and pick < 7 and _has(prefix + "dak_zonnepanelen"):
				B(cell.x, cell.y, cell.z, prefix + "dak_zonnepanelen", "S")
			elif flat_edge and pick == 0 and _has(prefix + "dak_installatie_rand"):
				B(cell.x, cell.y, cell.z, prefix + "dak_installatie_rand", side)
		elif style in FLAT_STYLES:
			if flat_middle and pick < 4:
				if _has(prefix + "dak_zonnepanelen"):
					B(cell.x, cell.y, cell.z, prefix + "dak_zonnepanelen", "S")
				else:
					D(spot.x, spot.y, roof_height, "dak/zonnepanelen", "S")
			elif (flat_middle or flat_edge) and pick == 5:
				D(spot.x, spot.y, roof_height, "dak/ventilatiekap", "S")
			elif flat_middle and pick == 6:
				D(spot.x, spot.y, roof_height, "dak/airco_buitenunit", turn)
		elif style in INDUSTRY_STYLES:
			if flat_middle and pick < 6:
				D(spot.x, spot.y, roof_height, "dak/zonnepanelen_groot", "S")
			elif (flat_middle or flat_edge) and pick == 6:
				D(spot.x, spot.y, roof_height, "dak/ventilatiekap", "S")
		elif piece == "dak_schuin" and side in ["S", "W"] and pick < 3 and _has(prefix + "dak_schuin_zonnepanelen"):
			B(cell.x, cell.y, cell.z, prefix + "dak_schuin_zonnepanelen", side)
		elif (flat_middle or flat_edge) and pick == 0:
			D(spot.x, spot.y, roof_height, "dak/airco_buitenunit", turn)


## Ground a building can be reached over (a street, pavement, square, path or car park).
const ACCESS_GROUND := ["stoep/", "plein/", "weg/", "tram/", "spoor/perron", "natuur/pad", "natuur/grindpad", "natuur/keienpad", "brug/", "parkeren/"]
## Ground-floor pieces that are a way in.
const ENTRANCE_PIECES := ["bg_entree", "bg_deur", "bg_portiek", "bg_portaal", "bg_lobby"]


## Gravel paths that join up (the parks): every straight gravel path cell is turned along
## the paths beside it, and where a path turns a corner it gets the curve. A junction of
## three or four keeps the straight piece of its through way; a lone piece turns towards
## the pavement it leads onto.
const GRAVEL_PATH := "natuur/pad_grind"
const GRAVEL_PATH_CURVE := "natuur/pad_grind_bocht"


func _join_gravel_paths() -> void:
	var paths := {}
	for cell in ground.get_used_cells():
		if cell.y == 0 and _street_tile(Vector2i(cell.x, cell.z)) in [GRAVEL_PATH, GRAVEL_PATH_CURVE]:
			paths[Vector2i(cell.x, cell.z)] = true
	for cell: Vector2i in paths:
		var ways: Array[String] = []
		for direction: String in ORDER:
			if paths.has(cell + DIR_OFFSET[direction]):
				ways.append(direction)
		if ways.is_empty():
			for direction: String in ORDER:
				var beside := _street_tile(cell + DIR_OFFSET[direction])
				if beside.begins_with("stoep/") or beside.begins_with("plein/") or beside.begins_with("natuur/pad"):
					ways.append(direction)
		if ways.is_empty():
			continue
		if ways.size() == 2 and _ck(ways[0], ways[1]) != "":
			_g(cell.x, cell.y, GRAVEL_PATH_CURVE, _ck(ways[0], ways[1]))
			continue
		var along_x := (ways.has("E") and ways.has("W")) or not (ways.has("N") or ways.has("S"))
		if ways.has("N") and ways.has("S") and not (ways.has("E") and ways.has("W")):
			along_x = false
		_g(cell.x, cell.y, GRAVEL_PATH, "E" if along_x else "S")


## A corner piece of a building (its "_hoek" tiles: a facade on its front and its right
## side, often with a corner pillar) whose side stands against another building (a glass
## hall built on, the next block): its pillar and facade would stand in the other one's wall
## and flicker through it. It becomes the straight piece facing its open side.
func _straighten_hidden_corners() -> void:
	var straightened := 0
	for cell in buildings.get_used_cells():
		var tile_name := buildings.mesh_library.get_item_name(buildings.get_cell_item(cell))
		if not tile_name.ends_with("_hoek"):
			continue
		var straight := tile_name.trim_suffix("_hoek")
		if not _has(straight):
			continue
		var turn := orient.find(buildings.get_cell_item_orientation(cell))
		if turn < 0:
			continue
		var front: String = ORDER[turn]
		var right: String = ORDER[(turn + 1) % 4]
		var style := tile_name.get_slice("/", 0)
		var front_blocked := _other_building(cell, front, style)
		var right_blocked := _other_building(cell, right, style)
		if right_blocked and not front_blocked:
			B(cell.x, cell.y, cell.z, straight, front)
		elif front_blocked and not right_blocked:
			B(cell.x, cell.y, cell.z, straight, right)
		else:
			continue
		straightened += 1
	print("corners against another building made straight: %d" % straightened)


## True if the cell beside `cell` towards `side` holds a building piece of another style
## in the same storey.
func _other_building(cell: Vector3i, side: String, style: String) -> bool:
	var offset: Vector2i = DIR_OFFSET[side]
	var item := buildings.get_cell_item(cell + Vector3i(offset.x, 0, offset.y))
	return item >= 0 and buildings.mesh_library.get_item_name(item).get_slice("/", 0) != style


## Facade pieces that stick out (balconies, bay windows) right beside a viaduct deck or a
## bridge (Grond above street level) at their height would reach into it: they become the
## plain facade of their style.
func _flatten_facades_by_viaducts() -> void:
	var flattened := 0
	for cell in ground.get_used_cells():
		if cell.y < 2:
			continue
		var tile_name := ground.mesh_library.get_item_name(ground.get_cell_item(cell))
		if not (tile_name.begins_with("brug/") or tile_name.begins_with("spoor/") or tile_name.begins_with("tram/")):
			continue
		var storey := floori(cell.y / 3.0)
		for side: String in ORDER:
			var offset: Vector2i = DIR_OFFSET[side]
			for nearby_storey in [storey - 1, storey, storey + 1]:
				if nearby_storey >= 1 and _flatten_facade(Vector3i(cell.x + offset.x, nearby_storey, cell.z + offset.y)):
					flattened += 1
	print("facades beside viaducts made plain: %d" % flattened)


## Trees whose crown would grow into a building (planted too close to a facade) go.
const TREE_CLEARANCE := 0.4


func _remove_trees_in_buildings() -> void:
	var removed := 0
	var boxes := {}
	for cell in props.get_used_cells():
		var item := props.get_cell_item(cell)
		var tile_name := props.mesh_library.get_item_name(item)
		if not tile_name.begins_with("bomen/"):
			continue
		if not boxes.has(item):
			boxes[item] = props.mesh_library.get_item_mesh_transform(item) * props.mesh_library.get_item_mesh(item).get_aabb()
		var turn := props.get_basis_with_orthogonal_index(props.get_cell_item_orientation(cell))
		var box: AABB = (props.transform * Transform3D(turn, props.map_to_local(cell))) * boxes[item]
		box = box.grow(-TREE_CLEARANCE)
		var hits := false
		for x in range(floori(box.position.x / 4.0), floori(box.end.x / 4.0) + 1):
			for z in range(floori(box.position.z / 4.0), floori(box.end.z / 4.0) + 1):
				for storey in range(maxi(1, floori(box.position.y / 3.0)), floori(box.end.y / 3.0) + 1):
					hits = hits or buildings.get_cell_item(Vector3i(x, storey, z)) >= 0
		if hits:
			props.set_cell_item(cell, GridMap.INVALID_CELL_ITEM)
			removed += 1
	print("trees growing into buildings taken away: %d" % removed)


## Keeps every sign and logo on a facade (Details "tekst/...") on its building: where it
## would hang past the end of the facade (a wide name on a narrow front or near a corner)
## it moves along the wall until it lies on it whole, or, wider than the front, to its
## middle.
func _fit_signs_on_facades() -> void:
	var moved := 0
	var signs: Array[Vector3i] = []
	for cell in details.get_used_cells():
		if details.mesh_library.get_item_name(details.get_cell_item(cell)).begins_with("tekst/"):
			signs.append(cell)
	for sign_cell in signs:
		var item := details.get_cell_item(sign_cell)
		var orientation := details.get_cell_item_orientation(sign_cell)
		var half_width := details.mesh_library.get_item_mesh(item).get_aabb().size.x * 0.5
		var turn := details.get_basis_with_orthogonal_index(orientation)
		var out := turn * Vector3(0, 0, 1)
		var across := turn * Vector3(1, 0, 0)
		var wall := Vector3(sign_cell) * 0.5
		var storey := floori(wall.y / 3.0)
		# the facade behind it: from its middle along the wall each way while there is building
		var behind := wall - out * 0.5
		if not _building_at(behind, storey):
			continue
		var left := 0.0
		while left > -40.0 and _building_at(behind + across * (left - 0.5), storey):
			left -= 0.5
		var right := 0.0
		while right < 40.0 and _building_at(behind + across * (right + 0.5), storey):
			right += 0.5
		# the facade runs from left - (the rest of that half metre) to right; the cell centres
		# lie on whole cells, so measure to the cell edges
		var start := _facade_edge(behind, across, left, storey, -1.0)
		var finish := _facade_edge(behind, across, right, storey, 1.0)
		var shift := 0.0
		if finish - start < half_width * 2.0:
			shift = (start + finish) * 0.5
		elif -half_width < start:
			shift = start + half_width
		elif half_width > finish:
			shift = finish - half_width
		var steps := roundi(shift * 2.0)
		if steps == 0:
			continue
		var target := Vector3i((wall + across * steps * 0.5) * 2.0)
		details.set_cell_item(sign_cell, GridMap.INVALID_CELL_ITEM)
		details.set_cell_item(target, item, orientation)
		moved += 1
	print("signs fitted on their facades: %d moved" % moved)


## True if a building piece stands at this point (metres) in this storey.
func _building_at(point: Vector3, storey: int) -> bool:
	return buildings.get_cell_item(Vector3i(floori(point.x / 4.0), storey, floori(point.z / 4.0))) >= 0


## The end of the facade along `across` (metres from the sign's middle), from the last
## offset with building found that way (`direction` -1 or 1): the edge of that cell.
func _facade_edge(behind: Vector3, across: Vector3, last_offset: float, storey: int, direction: float) -> float:
	var point := behind + across * last_offset
	var cell_start := Vector3(floorf(point.x / 4.0) * 4.0, 0.0, floorf(point.z / 4.0) * 4.0)
	# along `across` the cell spans 4 m from its start (across is +-x or +-z)
	var along_start := (cell_start - behind).dot(across)
	var along_end := along_start + 4.0 * (across.x + across.z)
	var low := minf(along_start, along_end)
	var high := maxf(along_start, along_end)
	return high if direction > 0.0 else low


## Two signs or logos (Details "tekst/...") on the same facade that overlap (a wide shop name
## over the hanging sign of the shop next door, a logo over a sign): the smaller one moves
## aside along the wall until it is clear; only without room on the facade does it go.
func _one_sign_per_spot() -> void:
	var signs: Array[Dictionary] = []
	for cell in details.get_used_cells():
		var item := details.get_cell_item(cell)
		if not details.mesh_library.get_item_name(item).begins_with("tekst/"):
			continue
		var box := details.mesh_library.get_item_mesh(item).get_aabb()
		var turn := details.get_basis_with_orthogonal_index(details.get_cell_item_orientation(cell))
		signs.append({"cell": cell, "wall": Vector3(cell) * 0.5, "out": turn * Vector3(0, 0, 1),
			"across": turn * Vector3(1, 0, 0), "width": box.size.x, "height": box.size.y, "gone": false})
	var removed := 0
	var shifted := 0
	for first_index in signs.size():
		var first: Dictionary = signs[first_index]
		for second_index in range(first_index + 1, signs.size()):
			var second: Dictionary = signs[second_index]
			if first.gone or second.gone:
				continue
			var relative: Vector3 = second.wall - first.wall
			# the same wall: facing the same way, (almost) in one plane
			if (first.out as Vector3).dot(second.out) < 0.9 or absf(relative.dot(first.out)) > 0.6:
				continue
			var apart_sideways := absf(relative.dot(first.across))
			var first_top: float = first.wall.y + first.height
			var second_top: float = second.wall.y + second.height
			var overlap_up := minf(first_top, second_top) - maxf(first.wall.y, second.wall.y)
			if apart_sideways >= (first.width + second.width) * 0.5 or overlap_up <= 0.0:
				continue
			var smaller: Dictionary = first if first.width * first.height < second.width * second.height else second
			var bigger: Dictionary = second if smaller == first else first
			if _shift_sign_clear(smaller, bigger, signs):
				shifted += 1
			else:
				details.set_cell_item(smaller.cell, GridMap.INVALID_CELL_ITEM)
				smaller.gone = true
				removed += 1
	print("signs over each other: %d moved aside, %d without room taken away" % [shifted, removed])


## Moves `sign` along its wall away from `other` until it clears every other sign there,
## staying on the facade; false if there is no such spot within SIGN_SHIFT_MOST metres.
const SIGN_SHIFT_MOST := 4.0


func _shift_sign_clear(sign: Dictionary, other: Dictionary, signs: Array[Dictionary]) -> bool:
	var across: Vector3 = sign.across
	var away := signf((sign.wall as Vector3 - other.wall).dot(across))
	if away == 0.0:
		away = 1.0
	var item := details.get_cell_item(sign.cell)
	var orientation := details.get_cell_item_orientation(sign.cell)
	var behind: Vector3 = sign.wall - (sign.out as Vector3) * 0.5
	var storey := floori((sign.wall as Vector3).y / 3.0)
	var step := 0.5
	while step <= SIGN_SHIFT_MOST:
		var spot: Vector3 = sign.wall + across * away * step
		# whole on the facade?
		var on_facade := true
		for edge in [-sign.width * 0.5, sign.width * 0.5]:
			on_facade = on_facade and _building_at(behind + across * (away * step + edge * 0.98), storey)
		if on_facade and not _overlaps_a_sign(spot, sign, signs):
			details.set_cell_item(sign.cell, GridMap.INVALID_CELL_ITEM)
			var target := Vector3i((spot * 2.0).round())
			details.set_cell_item(target, item, orientation)
			sign.cell = target
			sign.wall = Vector3(target) * 0.5
			return true
		step += 0.5
	return false


## True if `sign` put at `spot` would overlap another sign on its wall.
func _overlaps_a_sign(spot: Vector3, sign: Dictionary, signs: Array[Dictionary]) -> bool:
	for other: Dictionary in signs:
		if other == sign or other.gone:
			continue
		var relative: Vector3 = other.wall - spot
		if (sign.out as Vector3).dot(other.out) < 0.9 or absf(relative.dot(sign.out)) > 0.6:
			continue
		var overlap_up := minf(spot.y + sign.height, other.wall.y + other.height) - maxf(spot.y, other.wall.y)
		if absf(relative.dot(sign.across)) < (sign.width + other.width) * 0.5 and overlap_up > 0.0:
			return true
	return false


## Facade parts that stick out (balconies, bay windows, loggias, terraces, awnings) and
## would cover a sign or logo; the plain facade pieces that take their place, the first a
## style has.
const STICKING_OUT := ["balkon", "erker", "loggia", "terras", "luifel"]
const PLAIN_FACADES := ["verd_raam", "verd_glas", "verd_raam_groot", "verd_wand", "verd_dicht"]
## Details that may hang in front of a sign (the signs themselves are "tekst/").
const SIGN_FREE_MARGIN := 0.5
## Advertising boards and banners flat on the wall, kept free like the signs: a balcony,
## bay window or flower box never goes over them, the banner wins.
const BANNERS := ["gevel/reclamebord", "gevel/vlag_regenboog_hangend"]


## A sign, logo or banner on the wall that the facade around it must leave free.
func _keeps_facade_free(detail_name: String) -> bool:
	return detail_name.begins_with("tekst/") or BANNERS.has(detail_name)


## Keeps every sign, logo and banner on a facade (Details items "tekst/...", BANNERS) free:
## the building pieces behind it that stick out (balconies, bay windows) become the plain
## facade of their style, and other details hanging in front of it (flower boxes, flags,
## awnings) go.
func _clear_behind_signs() -> void:
	var flattened := 0
	var removed := 0
	var signs: Array[Vector3i] = []
	for cell in details.get_used_cells():
		if _keeps_facade_free(details.mesh_library.get_item_name(details.get_cell_item(cell))):
			signs.append(cell)
	for sign_cell in signs:
		var item := details.get_cell_item(sign_cell)
		var box := details.mesh_library.get_item_mesh(item).get_aabb()
		var turn := details.get_basis_with_orthogonal_index(details.get_cell_item_orientation(sign_cell))
		var out := turn * Vector3(0, 0, 1)        # the way the sign faces
		var across := turn * Vector3(1, 0, 0)
		var wall := Vector3(sign_cell) * 0.5      # metres: on the wall, mid-width, its bottom
		var half_width := box.size.x * 0.5
		var bottom := wall.y
		var top := wall.y + box.size.y
		# the building pieces behind it
		var offset := -half_width
		while offset <= half_width + 0.01:
			var behind := wall - out * 0.5 + across * offset
			for storey in range(floori(bottom / 3.0), floori((top - 0.01) / 3.0) + 1):
				if _flatten_facade(Vector3i(floori(behind.x / 4.0), storey, floori(behind.z / 4.0))):
					flattened += 1
			offset += 1.0
		# other details in front of it
		for other in details.get_used_cells():
			if other == sign_cell:
				continue
			var other_name := details.mesh_library.get_item_name(details.get_cell_item(other))
			if _keeps_facade_free(other_name) or other_name.begins_with("deuren/"):
				continue
			var relative := Vector3(other) * 0.5 - wall
			var sideways := absf(relative.dot(across))
			var outwards := relative.dot(out)
			var up := Vector3(other).y * 0.5
			if sideways < half_width + SIGN_FREE_MARGIN and outwards > -0.6 and outwards < 1.6 \
					and up > bottom - 1.5 and up < top + SIGN_FREE_MARGIN:
				details.set_cell_item(other, GridMap.INVALID_CELL_ITEM)
				removed += 1
	print("signs kept free: %d facade pieces made plain, %d details taken away" % [flattened, removed])


## Turns a building piece that sticks out (STICKING_OUT) into the plain facade of its
## style, kept facing the same way; true if it did.
func _flatten_facade(cell: Vector3i) -> bool:
	var item := buildings.get_cell_item(cell)
	if item < 0:
		return false
	var tile_name := buildings.mesh_library.get_item_name(item)
	if not STICKING_OUT.any(func(part: String) -> bool: return tile_name.contains(part)):
		return false
	var style := tile_name.get_slice("/", 0)
	var corner := "_hoek" if tile_name.ends_with("_hoek") else ""
	for plain: String in PLAIN_FACADES:
		var replacement := style + "/" + style + "_" + plain + corner
		if _has(replacement):
			buildings.set_cell_item(cell, buildings.mesh_library.find_item_by_name(replacement), buildings.get_cell_item_orientation(cell))
			return true
	return false


## A paved path over the grass from the entrance of every building standing free in the
## grass (a gallery flat, a tower, a school) to the nearest pavement or street.
func _paths_to_lonely_buildings() -> void:
	var footprint := {}
	for cell: Vector3i in buildings.get_used_cells():
		if cell.y == 0:
			footprint[Vector2i(cell.x, cell.z)] = true
	var seen := {}
	for first: Vector2i in footprint:
		if seen.has(first):
			continue
		var group: Array[Vector2i] = [first]
		seen[first] = true
		var index := 0
		var reachable := false
		var doors: Array[Vector2i] = []   # grass cells in front of an entrance
		var beside: Array[Vector2i] = []  # grass cells beside the building
		while index < group.size():
			var here: Vector2i = group[index]
			index += 1
			var piece := buildings.mesh_library.get_item_name(buildings.get_cell_item(Vector3i(here.x, 0, here.y)))
			var front := _front_of(Vector3i(here.x, 0, here.y))
			for side: String in DIR_OFFSET:
				var next: Vector2i = here + DIR_OFFSET[side]
				if footprint.has(next):
					if not seen.has(next):
						seen[next] = true
						group.append(next)
					continue
				var below := _ground_name(next)
				for start: String in ACCESS_GROUND:
					reachable = reachable or below.begins_with(start)
				if below == "natuur/gras":
					beside.append(next)
					for entrance: String in ENTRANCE_PIECES:
						if piece.contains("_" + entrance) and side == front:
							doors.append(next)
		if reachable or beside.is_empty():
			continue
		_lay_path(doors[doors.size() / 2] if not doors.is_empty() else beside[0], footprint)


## The side the ground-floor piece in building cell `cell` faces ("" if not turned square).
func _front_of(cell: Vector3i) -> String:
	var orientation := buildings.get_cell_item_orientation(cell)
	for side: String in DIR:
		if orient[DIR[side]] == orientation:
			return side
	return ""


## The name of the ground tile at street level in map cell `cell` ("" if empty).
func _ground_name(cell: Vector2i) -> String:
	var item := ground.get_cell_item(Vector3i(cell.x, 0, cell.y))
	return ground.mesh_library.get_item_name(item) if item >= 0 else ""


## Paves the shortest way over grass cells from `start` to a cell beside ground that can be
## reached (ACCESS_GROUND), without crossing a building.
func _lay_path(start: Vector2i, footprint: Dictionary) -> void:
	var came_from := {start: start}
	var queue: Array[Vector2i] = [start]
	var index := 0
	var goal := Vector2i(-1, -1)
	while index < queue.size() and goal.x < 0:
		var here: Vector2i = queue[index]
		index += 1
		for side: String in DIR_OFFSET:
			var next: Vector2i = here + DIR_OFFSET[side]
			if came_from.has(next) or footprint.has(next):
				continue
			var below := _ground_name(next)
			var reachable := false
			for access: String in ACCESS_GROUND:
				reachable = reachable or below.begins_with(access)
			if reachable:
				goal = here
				break
			if below == "natuur/gras":
				came_from[next] = here
				queue.append(next)
	if goal.x < 0:
		return
	var step := goal
	while true:
		_clear_props(step.x, step.y)
		_g(step.x, step.y, "stoep/stoep_vol")
		if step == start:
			break
		step = came_from[step]


# ------------------------------------------------------------------ finishing

## Grass on every empty ground cell of the map (not water or a sunk cell); paving under a
## building whose floor can be seen (a glass hall, a canopy, pillars), never grass.
func _fill_grass_all() -> void:
	for x in range(0, MAP_END + 1):
		for z in range(0, Z_END + 1):
			if ground.get_cell_item(Vector3i(x, 0, z)) != GridMap.INVALID_CELL_ITEM:
				continue
			if ground.get_cell_item(Vector3i(x, -2, z)) != GridMap.INVALID_CELL_ITEM:
				continue
			var standing := buildings.get_cell_item(Vector3i(x, 0, z))
			var piece := buildings.mesh_library.get_item_name(standing) if standing >= 0 else ""
			if piece.begins_with("hallen/") or piece.begins_with("overkapping/") or piece.begins_with("pilaren/"):
				G(x, z, "plein/plein_tegels")
			elif not occupied.has(Vector2i(x, z)):
				G(x, z, "natuur/gras")


## Never grass under a building: the grass shader would draw blades no one sees (CPU and
## GPU for nothing). Every grass cell with a building standing on it becomes paving.
func _no_grass_under_buildings() -> void:
	var grass := ground.mesh_library.find_item_by_name("natuur/gras")
	var paved := 0
	for cell in ground.get_used_cells_by_item(grass):
		if cell.y != 0:
			continue
		if buildings.get_cell_item(Vector3i(cell.x, 0, cell.z)) != GridMap.INVALID_CELL_ITEM:
			G(cell.x, cell.z, UNDER_BUILDING_TILE)
			paved += 1
	print("geen gras onder gebouwen: %d cellen bestraat" % paved)


## The camera over the old centre (the follow camera takes it over at the start, see _car)
## and the vignette (node Vignet, scripts/effects/vignette.gd).
func _camera(root: Node3D) -> void:
	# two shadow cascades instead of four: the game looks at the town from close by
	# (following a car), where two are as sharp, and it saves the GPU most of a millisecond
	(root.get_node("Zon") as DirectionalLight3D).directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	var cam: Camera3D = root.get_node("Camera")
	var Iso = load("res://scripts/camera/iso_camera.gd")
	cam.position = Iso.position(Vector3(40 * 4.0, 0, 42 * 4.0), 160.0)
	# the rail traffic: each on its own kind of rails, a tile knows who rides on it
	for rail_start: Array in [["RandstadRail1", "res://scripts/vehicles/randstadrail.gd", Vector2i(VIADUCT_LINK_COLUMNS[1], 70), Vector2i(0, -1)],
			["RandstadRail2", "res://scripts/vehicles/randstadrail.gd", Vector2i(VIADUCT_LINK_COLUMNS[0], 74), Vector2i(0, 1)],
			# two trains, each on its own track (own_track in ns_train.gd)
			["Trein1", "res://scripts/vehicles/ns_train.gd", Vector2i(RAILWAY_COLUMNS[1], 90), Vector2i(0, -1)],
			["Trein2", "res://scripts/vehicles/ns_train.gd", Vector2i(RAILWAY_COLUMNS[0], 75), Vector2i(0, 1)]]:
		var rail_vehicle := Node3D.new()
		rail_vehicle.name = rail_start[0]
		rail_vehicle.set_script(load(rail_start[1]))
		rail_vehicle.set("start_cell", rail_start[2])
		rail_vehicle.set("start_heading", rail_start[3])
		root.add_child(rail_vehicle)
		rail_vehicle.owner = root
	var tunnel_lights := Node.new()
	tunnel_lights.name = "Tunnelverlichting"
	tunnel_lights.set_script(load("res://scripts/world/town/tunnel_lights.gd"))
	root.add_child(tunnel_lights)
	tunnel_lights.owner = root
	var lens := CanvasLayer.new()
	lens.name = "Vignet"
	lens.set_script(load("res://scripts/effects/vignette.gd"))
	root.add_child(lens)
	lens.owner = root


## The car (node Auto, scripts/vehicles/car.gd), an SUV that drives round too (node
## SUV, scripts/vehicles/suv.gd, starting in the Bezuidenhout), the player (node Speler,
## scripts/player/player_controller.gd: the chosen zwerver walking round), the camera that
## follows it (node Volgcamera), the rest of the traffic (node Verkeer,
## scripts/traffic/traffic.gd, spreads it at the start), the pedestrians (node Voetgangers,
## scripts/world/people/pedestrians.gd) and
## the see-through buildings while it follows (node Doorkijk,
## scripts/world/town/building_fade.gd). The car finds its lanes in the ground tiles themselves
## (their "traffic" metadata, scripts/traffic/road_network.gd).
func _car(root: Node3D) -> void:
	var car := Node3D.new()
	car.name = "Auto"
	car.set_script(load("res://scripts/vehicles/car.gd"))
	root.add_child(car)
	car.owner = root
	var suv := Node3D.new()
	suv.name = "SUV"
	suv.set_script(load("res://scripts/vehicles/suv.gd"))
	suv.set("start_cell", Vector2i(XB, ZB + 6))
	suv.set("start_heading", Vector2i(0, 1))
	suv.set("route_seed", 23)
	root.add_child(suv)
	suv.owner = root
	var traffic := Node.new()
	traffic.name = "Verkeer"
	traffic.set_script(load("res://scripts/traffic/traffic.gd"))
	root.add_child(traffic)
	traffic.owner = root
	var player := Node3D.new()
	player.name = "Speler"
	player.set_script(load("res://scripts/player/player_controller.gd"))
	root.add_child(player)
	player.owner = root
	var loose_change := Node3D.new()
	loose_change.name = "Kleingeld"   # coins on the streets (scripts/world/things/loose_change.gd)
	loose_change.set_script(load("res://scripts/world/things/loose_change.gd"))
	root.add_child(loose_change)
	loose_change.owner = root
	var pedestrians := Node3D.new()
	pedestrians.name = "Voetgangers"   # people walking the pavements (scripts/world/people/pedestrians.gd)
	pedestrians.set_script(load("res://scripts/world/people/pedestrians.gd"))
	root.add_child(pedestrians)
	pedestrians.owner = root
	var terraces := Node3D.new()
	terraces.name = "Terrassen"   # people sitting at the café tables (scripts/world/people/terraces.gd)
	terraces.set_script(load("res://scripts/world/people/terraces.gd"))
	root.add_child(terraces)
	terraces.owner = root
	var interiors := Node3D.new()
	interiors.name = "Binnenruimtes"   # the snack bars you walk into (scripts/world/interiors/interiors.gd)
	interiors.set_script(load("res://scripts/world/interiors/interiors.gd"))
	root.add_child(interiors)
	interiors.owner = root
	var story := Node.new()
	story.name = "Verhaal"   # the prologue and the missions (scripts/story/story.gd)
	story.set_script(load("res://scripts/story/story.gd"))
	root.add_child(story)
	story.owner = root
	var characters := Node3D.new()
	characters.name = "Personages"   # the people of the story: Ome Wim and others (scripts/story/characters.gd)
	characters.set_script(load("res://scripts/story/characters.gd"))
	root.add_child(characters)
	characters.owner = root
	var follow := Node.new()
	follow.name = "Volgcamera"
	follow.set_script(load("res://scripts/camera/follow_camera.gd"))
	root.add_child(follow)
	follow.owner = root
	var see_through := Node.new()
	see_through.name = "Doorkijk"
	see_through.set_script(load("res://scripts/world/town/building_fade.gd"))
	root.add_child(see_through)
	see_through.owner = root


## Props a waste bin belongs next to: benches, picnic tables, kiosks, tram shelters.
const BIN_NEAR := ["straat/bank_hout", "straat/bank_beton", "straat/bank_modern", "straat/picknicktafel", "straat/kiosk", "ov/abri"]
## Shopping streets with a bin every few cells on the pavement in front of the shops:
## [first cell, step, count, interval].
const BIN_STREETS := [
	[Vector2i(54, 7), Vector2i(0, 1), 1, 1],         # Denneweg, at its north end
	[Vector2i(9, 44), Vector2i(1, 0), 14, 5],        # Hoogstraat
	[Vector2i(15, 72), Vector2i(0, 1), 12, 5],       # Wagenstraat (Chinatown)
	[Vector2i(35, 63), Vector2i(0, 1), 20, 6],       # Passage
	[Vector2i(XC + 3, ZB - 1), Vector2i(1, 0), 46, 7],   # Theresiastraat, north pavement
	[Vector2i(XC + 6, ZB + 2), Vector2i(1, 0), 46, 7],   # Theresiastraat, south pavement
]


## Waste bins at logical spots: beside benches, picnic tables, kiosks and tram shelters
## (on a free walkable spot 1.5 m away, at most one per 6 m), and at intervals along the
## shopping streets. Lampposts and bins alternate: a lamppost bin on pavements and
## squares, a round bin in parks.
func _bins() -> void:
	var placed: Array[Vector2] = []
	var spots := []
	for c in props.get_used_cells():
		if c.y != 0 and c.y != 1:
			continue
		var nm := props.mesh_library.get_item_name(props.get_cell_item(c))
		if nm in BIN_NEAR:
			spots.append(Vector2(c.x, c.z) * 0.5)
	spots.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	for p in spots:
		for off in [Vector2(1.5, 0), Vector2(-1.5, 0), Vector2(0, 1.5), Vector2(0, -1.5)]:
			if _try_bin(p + off, placed):
				break
	for st in BIN_STREETS:
		for i in range(0, st[2], st[3]):
			var c: Vector2i = st[0] + st[1] * i
			_try_bin(Vector2(c) * 4.0 + Vector2(2.0, 2.0) + Vector2(st[1]) * 1.0, placed)
	print("waste bins: ", placed.size())


## Places a bin at p (metres) if the spot is walkable, free of props within 1 m and no
## bin lies within 6 m; true when placed.
func _try_bin(p: Vector2, placed: Array[Vector2]) -> bool:
	for q in placed:
		if q.distance_to(p) < 6.0:
			return false
	var cell := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	var id := ground.get_cell_item(Vector3i(cell.x, 0, cell.y))
	if id < 0:
		return false
	var g := ground.mesh_library.get_item_name(id)
	var park := g.begins_with("natuur/pad") or g.begins_with("natuur/grind") or g == "natuur/gras"
	if not (g.begins_with("stoep/") or g.begins_with("plein/") or g.begins_with("tram/tram_halte") or park):
		return false
	if g.contains("kade") or g.contains("rand"):
		return false   # not on the quay edge or the kerb
	var pc := Vector2i(roundi(p.x * 2), roundi(p.y * 2))
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			for y in [0, 1]:
				if props.get_cell_item(Vector3i(pc.x + dx, y, pc.y + dz)) != GridMap.INVALID_CELL_ITEM:
					return false
	Pr(p.x, p.y, "straat/prullenbak_rond" if park else "straat/prullenbak_paal")
	placed.append(p)
	return true


## The machines and things to find in the streets (each its own node; scripts in
## scripts/world/): the cash machines (PINPUNT) flush against facades and the OV posts
## (ov_incheckpaal) at tram stops (node Straatautomaten, street_machines.gd: a marker
## Geldautomaat_<n> / OVPaal_<n> each, its +z the way it faces), the cans in the waste
## bins (node Prullenbakken, litter_bins.gd) and the lost bank cards (node Pinpassen,
## lost_bank_cards.gd).
## Cash machines: beside every other supermarket entrance (bg_<chain>_ingang), then the
## other shop fronts (bg_*winkel*) and the facades on squares, spread out (at least
## CASH_MACHINE_SPACING m apart, at most MOST_CASH_MACHINES), each on the pavement in front of
## the facade, 1.3 m to the side of the middle (not before the door). OV posts: beside a
## tram shelter (ov/abri), at most MOST_OV_POSTS, OV_POST_SPACING m apart (cards are bought
## at the machines in the station hall).
const MOST_CASH_MACHINES := 34
const CASH_MACHINE_SPACING := 44.0
const MOST_OV_POSTS := 8
const OV_POST_SPACING := 60.0
## The cash machine's half depth: how far its middle stands before the facade.
const CASH_MACHINE_HALF_DEPTH := 0.27


func _street_machines(root: Node3D) -> void:
	var machines := Node3D.new()
	machines.name = "Straatautomaten"
	machines.set_script(load("res://scripts/world/things/street_machines.gd"))
	root.add_child(machines)
	machines.owner = root
	# the facades: supermarkets first (every other one), then shops, then squares
	var supermarket_fronts: Array = []
	var shop_fronts: Array = []
	var square_fronts: Array = []
	var library := buildings.mesh_library
	for cell in buildings.get_used_cells():
		if cell.y != 0:
			continue
		var tile_name := library.get_item_name(buildings.get_cell_item(cell))
		var front := buildings.get_cell_item_basis(cell) * Vector3(0, 0, 1)
		var step := Vector2i(roundi(front.x), roundi(front.z))
		if step.length_squared() != 1:
			continue
		var before := Vector2i(cell.x, cell.z) + step
		var ground_name := _ground_name(before)
		if not (ground_name.begins_with("stoep/") or ground_name.begins_with("plein/")):
			continue
		if buildings.get_cell_item(Vector3i(before.x, 0, before.y)) != GridMap.INVALID_CELL_ITEM:
			continue
		var entry := [cell, step]
		if tile_name.ends_with("_ingang") and (tile_name.contains("derrek") or tile_name.contains("alfred_steyhn")):
			supermarket_fronts.append(entry)
		elif tile_name.contains("_bg_") and tile_name.contains("winkel"):
			shop_fronts.append(entry)
		elif ground_name.begins_with("plein/") and tile_name.contains("_bg_"):
			square_fronts.append(entry)
	var sort_cells := func(first: Array, second: Array) -> bool:
		var first_cell: Vector3i = first[0]
		var second_cell: Vector3i = second[0]
		return first_cell.z < second_cell.z or (first_cell.z == second_cell.z and first_cell.x < second_cell.x)
	for fronts: Array in [supermarket_fronts, shop_fronts, square_fronts]:
		fronts.sort_custom(sort_cells)
	var placed: Array[Vector2] = []
	var number := 1
	var supermarket_index := 0
	for fronts: Array in [supermarket_fronts, shop_fronts, square_fronts]:
		# spread the shops: every third of them tried first, the others after
		var order: Array = []
		for stride_start in 3:
			for index in range(stride_start, fronts.size(), 3):
				order.append(fronts[index])
		for entry: Array in order:
			if number > MOST_CASH_MACHINES:
				break
			if fronts == supermarket_fronts:
				supermarket_index += 1
				if supermarket_index % 2 == 0:
					continue
			var cell: Vector3i = entry[0]
			var step: Vector2i = entry[1]
			var middle := Vector2(cell.x * 4.0 + 2.0, cell.z * 4.0 + 2.0)
			var outward := Vector2(step)
			var along := Vector2(-outward.y, outward.x)
			for side: float in [1.0, -1.0]:
				var spot := middle + outward * (2.0 + CASH_MACHINE_HALF_DEPTH) + along * 1.3 * side
				if placed.any(func(other: Vector2) -> bool: return other.distance_to(spot) < CASH_MACHINE_SPACING):
					break
				if not _free_of_props(spot):
					continue
				_machine_marker(machines, root, "Geldautomaat_%d" % number, spot, 0.0, outward)
				placed.append(spot)
				number += 1
				break
	print("cash machines: ", number - 1)
	# the OV posts beside tram shelters
	var shelters: Array[Vector3i] = []
	var shelter_item := props.mesh_library.find_item_by_name("ov/abri")
	if shelter_item >= 0:
		shelters.assign(props.get_used_cells_by_item(shelter_item))
	shelters.sort_custom(func(first: Vector3i, second: Vector3i) -> bool:
		return first.z < second.z or (first.z == second.z and first.x < second.x))
	var ov_placed: Array[Vector2] = []
	var ov_number := 1
	for shelter in shelters:
		if ov_number > MOST_OV_POSTS:
			break
		var at := Vector2(shelter.x, shelter.z) * 0.5
		if ov_placed.any(func(other: Vector2) -> bool: return other.distance_to(at) < OV_POST_SPACING):
			continue
		var facing := props.get_cell_item_basis(shelter) * Vector3(0, 0, 1)
		var shelter_front := Vector2(facing.x, facing.z).normalized()
		var shelter_along := Vector2(-shelter_front.y, shelter_front.x)
		for side: float in [1.0, -1.0]:
			var spot := at + shelter_along * 2.5 * side
			if not _free_of_props(spot, shelter.y):
				continue
			_machine_marker(machines, root, "OVPaal_%d" % ov_number, spot, shelter.y * 0.5, shelter_front)
			ov_placed.append(at)
			ov_number += 1
			break
	print("OV posts at tram stops: ", ov_number - 1)
	for finds: Array in [["Prullenbakken", "res://scripts/world/things/litter_bins.gd"], ["Pinpassen", "res://scripts/world/things/lost_bank_cards.gd"],
			["Straatverkopers", "res://scripts/world/things/street_vendors.gd"]]:
		var node := Node3D.new()
		node.name = finds[0]
		node.set_script(load(finds[1]))
		root.add_child(node)
		node.owner = root


## True if no prop stands within a metre of `spot` (metres) at the props level `level`.
func _free_of_props(spot: Vector2, level := 0) -> bool:
	var prop_cell := Vector2i(roundi(spot.x * 2), roundi(spot.y * 2))
	for offset_x in range(-2, 3):
		for offset_z in range(-2, 3):
			for height in [level, level + 1]:
				if props.get_cell_item(Vector3i(prop_cell.x + offset_x, height, prop_cell.y + offset_z)) != GridMap.INVALID_CELL_ITEM:
					return false
	return true


func _machine_marker(parent: Node3D, root: Node3D, marker_name: String, spot: Vector2, height: float, facing: Vector2) -> void:
	var marker := Node3D.new()
	marker.name = marker_name
	marker.position = Vector3(spot.x, height, spot.y)
	marker.rotation.y = atan2(facing.x, facing.y)
	parent.add_child(marker)
	marker.owner = root
