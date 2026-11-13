@tool
extends Node3D
## Overhead lines of trams and trains (the "Bovenleiding" node the builders add): a contact
## wire over every track, made from the rails of the ground tiles (RoadNetwork, metadata
## "rails"), so it works on any map, also one built by hand. The wire follows the track
## through curves, over crossings and switches and up and down ramps. From every overhead
## line mast in the props (`MAST_TILES`) a span runs across the tracks beside it, with a
## dropper down to each wire. As on a real line the contact wire itself stays level, so
## the pantographs (tools/voxgen/tiles/rail_vehicles.py) touch it everywhere; above it a
## carrier wire hangs from the spans and sags between them, deepest halfway (`sag` over a
## span of `typical_span`), with droppers down to the contact wire every
## `DROPPER_SPACING`. Where a building stands over the track (`buildings`) only the contact
## wire runs on. Tunnels get no wires (their open ramps do). In the editor the wires
## follow when tiles are placed, turned or removed (checked every second).

## The ground GridMap with the rail tiles.
@export var ground: NodePath = ^"../Grond"
## The props GridMap with the masts.
@export var props: NodePath = ^"../Props"
## The buildings GridMap: no carrier wire where a building stands over the track.
@export var buildings: NodePath = ^"../Gebouwen"
## Height of a tram's contact wire above the rails (metres).
@export var tram_wire_height := 5.5
## Height of a train's contact wire above the rails (metres).
@export var train_wire_height := 5.6
## How far a mast's span reaches across the tracks (metres).
@export var span_reach := 10.0
@export var wire_color := Color(0.16, 0.16, 0.17)
## Height of the carrier wire above the contact wire at a span (metres).
@export var carrier_rise := 1.0
## How far the carrier wire sags halfway between two spans `typical_span` apart (metres);
## a longer span sags more (with the square of its length), never nearer than
## CARRIER_CLEARANCE to the contact wire.
@export var sag := 0.45
@export var typical_span := 20.0
## In the game, from this zoom size (metres in view) the wires are hidden: further out
## they are thinner than a pixel and only flicker.
@export var shown_until := 220.0

const Iso = preload("res://scripts/camera/iso_camera.gd")
## Thickness of a wire (metres): thinner than a voxel, so it reads as a wire.
const WIRE := 0.07
## Straight pieces a curved wire is made of, per cell.
const CURVE_PIECES := 8
## Longest straight piece of a wire (metres): short enough for the sag to look round.
const PIECE_LENGTH := 1.0
## The nearest the carrier wire comes to the contact wire (metres).
const CARRIER_CLEARANCE := 0.25
## Metres between the droppers from the carrier wire to the contact wire.
const DROPPER_SPACING := 3.0
## How far along the wire a support is looked for (metres).
const SUPPORT_SEARCH := 40.0
## The overhead line masts among the props.
const MAST_TILES := ["ov/tram_bovenleiding_mast", "ov/tram_bovenleiding_dubbel", "spoor/bovenleidingmast"]
## Ground tiles of a tunnel that get wires after all: the open ramps.
const OPEN_TUNNEL_TILES := ["tunnel/tramtunnel_toerit_"]
## Seconds between checks in the editor whether the tiles changed.
const CHECK_INTERVAL := 1.0

var _wires: MeshInstance3D
var _signature := 0
var _since_check := 0.0


func _ready() -> void:
	_wires = MeshInstance3D.new()
	_wires.name = "Draden"
	_wires.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wires)   # not owned: never saved with the scene
	_refresh()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		var camera := get_viewport().get_camera_3d()
		if camera:
			_wires.visible = Iso.view_size(camera) < shown_until
		return
	_since_check += delta
	if _since_check < CHECK_INTERVAL:
		return
	_since_check = 0.0
	if _signature_of_maps() != _signature:
		_refresh()


## Rebuilds the wires from the tiles as they are now.
func _refresh() -> void:
	var ground_map := get_node_or_null(ground) as GridMap
	var props_map := get_node_or_null(props) as GridMap
	if ground_map == null or ground_map.mesh_library == null:
		return
	_signature = _signature_of_maps()
	var network := RoadNetwork.of(owner if owner else get_parent()) if not Engine.is_editor_hint() else RoadNetwork.new(ground_map)
	_wires.mesh = build_mesh(network, props_map)
	_wires.global_transform = Transform3D.IDENTITY


## The mesh of all wires, spans and droppers (world positions).
func build_mesh(network: RoadNetwork, props_map: GridMap) -> ArrayMesh:
	var wire_lines := {}   # rail cell -> Array of [from, to] straight pieces of its wire
	for cell: Vector3i in network.rail_cells():
		if not _has_wire(network, cell):
			continue
		var lines := []
		for rail: Array in network.rails(cell):
			lines.append_array(_rail_wire(network, cell, rail))
		wire_lines[cell] = lines
	var span_lines := []
	var supports := []   # points on the wires where a span carries them
	if props_map != null and props_map.mesh_library != null:
		_spans(props_map, wire_lines, span_lines, supports)
	var pieces: Array[PackedVector3Array] = []
	for line: Array in _hang(wire_lines, supports) + span_lines:
		pieces.append(PackedVector3Array(line))
	return _wire_mesh(pieces)


## True if the rails of `cell` get a wire: not in a tunnel (its open ramps do).
func _has_wire(network: RoadNetwork, cell: Vector3i) -> bool:
	var tile := network.tile_name(cell)
	if not tile.begins_with("tunnel/"):
		return true
	for start: String in OPEN_TUNNEL_TILES:
		if tile.begins_with(start):
			return true
	return false


## Height of the contact wire above the rails of `cell`.
func _wire_height(network: RoadNetwork, cell: Vector3i) -> float:
	return train_wire_height if network.allows(cell, "trein") else tram_wire_height


## The straight pieces of the wire over one rail of `cell` ([side, side] it joins): from
## the middle of one side over the centre to the middle of the other, rounded through a
## curve, at the wire height above the rails (rising with a ramp).
func _rail_wire(network: RoadNetwork, cell: Vector3i, rail: Array) -> Array:
	var middle := Vector2(cell.x + 0.5, cell.z + 0.5) * RoadNetwork.CELL
	var half := RoadNetwork.CELL * 0.5
	var start: Vector2 = middle + Vector2(rail[0]) * half
	var end: Vector2 = middle + Vector2(rail[1]) * half
	var lift := _wire_height(network, cell)
	var spots: Array[Vector2] = []
	if rail[0] == -rail[1]:
		var count := ceili(RoadNetwork.CELL / PIECE_LENGTH)
		for index in count + 1:
			spots.append(start.lerp(end, float(index) / count))
	else:
		for index in CURVE_PIECES + 1:
			var share := float(index) / CURVE_PIECES
			spots.append(start.lerp(middle, share).lerp(middle.lerp(end, share), share))
	var lines := []
	for index in spots.size() - 1:
		var from := spots[index]
		var to := spots[index + 1]
		lines.append([Vector3(from.x, network.height(cell, from) + lift, from.y), Vector3(to.x, network.height(cell, to) + lift, to.y)])
	return lines


## The spans of the masts: from the mast, `carrier_rise` above the highest contact wire it
## carries, straight across the tracks on the side where they lie, to just past the
## farthest wire within `span_reach`, with a dropper from the span down to each wire. Adds the spans and droppers
## to `lines` and the points where the droppers hold the wires to `supports`.
func _spans(props_map: GridMap, wire_lines: Dictionary, lines: Array, supports: Array) -> void:
	var library := props_map.mesh_library
	for prop_cell: Vector3i in props_map.get_used_cells():
		var tile := library.get_item_name(props_map.get_cell_item(prop_cell))
		if not MAST_TILES.has(tile):
			continue
		var foot := props_map.to_global(props_map.map_to_local(prop_cell))
		var best: Array = []
		var best_direction := Vector2.ZERO
		for direction: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var crossings := _crossings(Vector2(foot.x, foot.z), direction, foot.y, wire_lines)
			if crossings.size() > best.size():
				best = crossings
				best_direction = direction
		if best.is_empty():
			continue
		var farthest := 0.0
		var top := -INF
		for crossing: Vector3 in best:
			farthest = maxf(farthest, Vector2(crossing.x - foot.x, crossing.z - foot.z).length())
			top = maxf(top, crossing.y + carrier_rise)
		var tip := Vector2(foot.x, foot.z) + best_direction * (farthest + 0.4)
		lines.append([Vector3(foot.x, top, foot.z), Vector3(tip.x, top, tip.y)])
		for crossing: Vector3 in best:
			supports.append(crossing)
			if crossing.y < top:
				lines.append([Vector3(crossing.x, top, crossing.z), crossing])


## Where a span from `from` in `direction` would cross the wires within `span_reach`: the
## points on the wires (with their height), only wires running across the span and not far
## above or below the mast's foot.
func _crossings(from: Vector2, direction: Vector2, foot_height: float, wire_lines: Dictionary) -> Array:
	var crossings := []
	var across := Vector2(-direction.y, direction.x)
	for cell: Vector3i in wire_lines:
		var middle := Vector2(cell.x + 0.5, cell.z + 0.5) * RoadNetwork.CELL
		var along := (middle - from).dot(direction)
		if along <= 0.0 or along > span_reach + RoadNetwork.CELL or absf((middle - from).dot(across)) > RoadNetwork.CELL:
			continue
		for line: Array in wire_lines[cell]:
			var start: Vector3 = line[0]
			var end: Vector3 = line[1]
			var flat_start := Vector2(start.x, start.z)
			var flat_end := Vector2(end.x, end.z)
			# the span's line through `from` crosses this piece (sides of `across` differ)
			var side_start := (flat_start - from).dot(across)
			var side_end := (flat_end - from).dot(across)
			if side_start * side_end > 0.0 or is_equal_approx(side_start, side_end):
				continue
			if absf((flat_end - flat_start).normalized().dot(direction)) > 0.5:
				continue   # runs along the span, not across it
			var share := side_start / (side_start - side_end)
			var point := start.lerp(end, share)
			var reach := (Vector2(point.x, point.z) - from).dot(direction)
			if reach <= 0.0 or reach > span_reach or absf(point.y - foot_height) > 8.0:
				continue
			crossings.append(point)
	return crossings


## The straight pieces of the wires: the level contact wire, cut where a support holds it,
## and over it the carrier wire between two supports, each point of it `carrier_rise`
## above the contact wire less a sag from how far it lies along the wire from the two
## nearest supports (d1 and d2: a parabola, 0 at a support, deepest halfway), with a
## dropper every DROPPER_SPACING. No carrier wire past the last support of a wire or
## where a building stands over it.
func _hang(wire_lines: Dictionary, supports: Array) -> Array:
	var positions := {}     # point key -> position
	var neighbours := {}    # point key -> Array of [point key, metres]
	var pieces := []        # [point key, point key]
	var support_keys := {}
	var supports_in_cell := {}   # Vector2i map cell -> supports in it
	for support: Vector3 in supports:
		support_keys[_point_key(support)] = true
		var map_cell := Vector2i(floori(support.x / RoadNetwork.CELL), floori(support.z / RoadNetwork.CELL))
		supports_in_cell.get_or_add(map_cell, []).append(support)
	for cell: Vector3i in wire_lines:
		var near_supports: Array = supports_in_cell.get(Vector2i(cell.x, cell.z), [])
		for line: Array in wire_lines[cell]:
			var points: Array = [line[0]]
			var cuts := []
			for support: Vector3 in near_supports:
				var share := _share_along(line[0], line[1], support)
				if share > 0.001 and share < 0.999:
					cuts.append(share)
			cuts.sort()
			for share: float in cuts:
				points.append((line[0] as Vector3).lerp(line[1], share))
			points.append(line[1])
			for index in points.size() - 1:
				var from_key := _point_key(points[index])
				var to_key := _point_key(points[index + 1])
				if from_key == to_key:
					continue
				positions[from_key] = points[index]
				positions[to_key] = points[index + 1]
				var metres: float = (points[index] as Vector3).distance_to(points[index + 1])
				neighbours.get_or_add(from_key, []).append([to_key, metres])
				neighbours.get_or_add(to_key, []).append([from_key, metres])
				pieces.append([from_key, to_key])
	var support_distances := {}   # [support key, support key] -> metres along the wires
	var nearest := _two_nearest_supports(support_keys.keys(), neighbours, support_distances)
	var bend := 4.0 * sag / (typical_span * typical_span)
	var buildings_map := get_node_or_null(buildings) as GridMap
	var carrier := {}   # point key -> where the carrier wire is above it
	for key: Vector3i in positions:
		var found: Array = nearest.get(key, [])
		if found.size() < 2 or not _between(found, support_distances):
			continue
		var lift := maxf(carrier_rise - bend * found[0][0] * found[1][0], CARRIER_CLEARANCE)
		var point: Vector3 = positions[key] + Vector3.UP * lift
		if not _under_building(buildings_map, point):
			carrier[key] = point
	var lines := []
	for piece: Array in pieces:
		lines.append([positions[piece[0]], positions[piece[1]]])
		if carrier.has(piece[0]) and carrier.has(piece[1]):
			lines.append([carrier[piece[0]], carrier[piece[1]]])
	for key: Vector3i in carrier:
		var found: Array = nearest[key]
		var from_support: float = found[0][0]
		if from_support > 1.0 and found[1][0] > 1.0 and fmod(from_support + 0.5, DROPPER_SPACING) < PIECE_LENGTH:
			lines.append([carrier[key], positions[key]])
	return lines


## True if `point` lies in a cell of the buildings GridMap (a building over the track).
static func _under_building(buildings_map: GridMap, point: Vector3) -> bool:
	if buildings_map == null:
		return false
	return buildings_map.get_cell_item(buildings_map.local_to_map(buildings_map.to_local(point))) >= 0


## Where `point` lies on the piece from `start` to `end` (0..1), or -1 if it is not on it.
static func _share_along(start: Vector3, end: Vector3, point: Vector3) -> float:
	var along := end - start
	var length_squared := along.length_squared()
	if length_squared < 0.000001:
		return -1.0
	var share := (point - start).dot(along) / length_squared
	if share < 0.0 or share > 1.0 or start.lerp(end, share).distance_to(point) > 0.05:
		return -1.0
	return share


## A key for a point on a wire: the same for the ends of the pieces that meet there.
static func _point_key(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x * 50.0), floori(point.y), roundi(point.z * 50.0))


## True if a point lies between its two nearest supports (`found`: [metres, support key] twice):
## from one support to the other along the wires is as far as from the point to both. Past
## the last support both lie on the same side: no carrier wire there.
static func _between(found: Array, support_distances: Dictionary) -> bool:
	var span: float = support_distances.get([found[0][1], found[1][1]], -1.0)
	return span >= 0.0 and absf(span - (float(found[0][0]) + float(found[1][0]))) < 0.05


## For every point the distances along the wires to its two nearest supports (two
## different ones), within SUPPORT_SEARCH: point key -> Array of [metres, support key]; and
## into `support_distances` how far each support lies from each other one it reaches
## ([support key, support key] -> metres).
func _two_nearest_supports(sources: Array, neighbours: Dictionary, support_distances := {}) -> Dictionary:
	var found := {}
	var is_support := {}
	for source: Vector3i in sources:
		is_support[source] = true
	for source: Vector3i in sources:
		if not neighbours.has(source):
			continue
		# walk out from this support along the wires, nearest first
		var reached := {source: 0.0}
		var frontier := [source]
		while not frontier.is_empty():
			var closest_index := 0
			for index in frontier.size():
				if reached[frontier[index]] < reached[frontier[closest_index]]:
					closest_index = index
			var key: Vector3i = frontier[closest_index]
			frontier.remove_at(closest_index)
			var metres: float = reached[key]
			if key != source and is_support.has(key):
				support_distances[[source, key]] = metres
			var labels: Array = found.get_or_add(key, [])
			labels.append([metres, source])
			labels.sort_custom(func(first: Array, second: Array) -> bool: return first[0] < second[0])
			if labels.size() > 2:
				labels.resize(2)
			for next: Array in neighbours[key]:
				var further: float = metres + next[1]
				if further > SUPPORT_SEARCH or (reached.has(next[0]) and reached[next[0]] <= further):
					continue
				if not reached.has(next[0]):
					frontier.append(next[0])
				reached[next[0]] = further
	return found


## One mesh of square wires (WIRE thick) along the given straight pieces.
func _wire_mesh(pieces: Array[PackedVector3Array]) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if pieces.is_empty():
		return mesh
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for piece in pieces:
		_add_bar(surface, piece[0], piece[1])
	surface.generate_normals()
	var material := StandardMaterial3D.new()
	material.albedo_color = wire_color
	material.roughness = 0.5
	material.metallic = 0.4
	surface.set_material(material)
	return surface.commit(mesh)


## A square bar from `from` to `to`, its sides square to the world's up where it can.
func _add_bar(surface: SurfaceTool, from: Vector3, to: Vector3) -> void:
	var along := to - from
	if along.length() < 0.001:
		return
	var forward := along.normalized()
	var side := forward.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized() * WIRE * 0.5
	var up := side.cross(forward).normalized() * WIRE * 0.5
	var corners := [side + up, -side + up, -side - up, side - up]
	for index in 4:
		var first: Vector3 = corners[index]
		var second: Vector3 = corners[(index + 1) % 4]
		surface.add_vertex(from + first)
		surface.add_vertex(to + first)
		surface.add_vertex(to + second)
		surface.add_vertex(from + first)
		surface.add_vertex(to + second)
		surface.add_vertex(from + second)
	for end_spot: Vector3 in [from, to]:
		surface.add_vertex(end_spot + corners[0])
		surface.add_vertex(end_spot + corners[1])
		surface.add_vertex(end_spot + corners[2])
		surface.add_vertex(end_spot + corners[0])
		surface.add_vertex(end_spot + corners[2])
		surface.add_vertex(end_spot + corners[3])


## A hash of the ground and props tiles, to see whether they changed.
func _signature_of_maps() -> int:
	var values := []
	for path: NodePath in [ground, props]:
		var gridmap := get_node_or_null(path) as GridMap
		if gridmap == null:
			continue
		var cells := gridmap.get_used_cells()
		var numbers := PackedInt32Array()
		numbers.resize(cells.size() * 5)
		for index in cells.size():
			var cell: Vector3i = cells[index]
			numbers[index * 5] = cell.x
			numbers[index * 5 + 1] = cell.y
			numbers[index * 5 + 2] = cell.z
			numbers[index * 5 + 3] = gridmap.get_cell_item(cell)
			numbers[index * 5 + 4] = gridmap.get_cell_item_orientation(cell)
		values.append(numbers)
	return hash(values)
