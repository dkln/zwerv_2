extends Node
## Working traffic lights (the "Verkeerslichten" node): the traffic light props of the
## Props layer (verkeerslichten/<kind>_<state>, one prop per light state) switch between
## their states while the game runs, so the lights of every intersection go round a
## real cycle.
##
## At start-up all cells of the Props layer holding a verkeerslichten/ prop are found
## and grouped per intersection (lights closer than CLUSTER metres to each other). A
## light belongs to the north-south or the east-west stream by the way it faces: a
## light facing south or north is seen by traffic on the north-south road (pedestrian
## lights the same way: they face the people crossing alongside that stream). Every
## intersection then runs the cycle
##   north-south green -> amber -> all red -> east-west green -> amber -> all red
## with its own time offset (intersections close together in step, `in_step_within`). Cars, bicycles and masts show groen / oranje / rood, public
## transport rijden / attentie / stop, pedestrians groen during the first part of their
## stream's green and rood otherwise.
##
## Changing a cell swaps the prop for the one with the other state; the LOD copies of the
## layer (Props_lod, see level_of_detail.gd) are updated as well. In the
## editor nothing moves: the scene keeps the states it was built with.

## Seconds of green per stream.
@export var green_time := 8.0
## Seconds of amber.
@export var amber_time := 2.5
## Seconds that all lights are red between the streams.
@export var clearance_time := 1.5
## Seconds of the green during which pedestrians may start crossing.
@export var pedestrian_time := 5.0
## Lights closer than this (metres) belong to the same intersection.
@export var cluster := 14.0
## Intersections closer than this (metres, between their middles) run in step (the same
## time offset): with crossings close after each other a stream that has green at one has
## it at the next too, so no one gets green there and red a few metres on (and stops on
## the crossing it just came over).
@export var in_step_within := 40.0
## Name of the layer with the light props.
@export var layer := "Props"

const PREFIX := "verkeerslichten/"
## kind -> [green, amber, red] state names in the prop names
const STATES := {
	"auto": ["groen", "oranje", "rood"],
	"fiets": ["groen", "oranje", "rood"],
	"mast": ["groen", "oranje", "rood"],
	"ov": ["rijden", "attentie", "stop"],
	"voetganger": ["groen", "rood", "rood"],
}

var _lights := []        # {cell, kind, ns, group, shown}
var _groups := []        # per intersection: time offset
var _centres := []       # per intersection: mean position of its lights (metres)
var _walk_lights := {}   # intersection -> true if it has pedestrian lights
var _ids := {}           # prop name -> item id
var _time := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var gm := _layer()
	if gm == null or gm.mesh_library == null:
		set_process(false)
		return
	var lib := gm.mesh_library
	for id in lib.get_item_list():
		var nm := lib.get_item_name(id)
		if nm.begins_with(PREFIX):
			_ids[nm] = id
	var found := []
	for c: Vector3i in gm.get_used_cells():
		var nm := lib.get_item_name(gm.get_cell_item(c))
		if not nm.begins_with(PREFIX):
			continue
		var kind := nm.trim_prefix(PREFIX).get_slice("_", 0)
		if not STATES.has(kind):
			continue
		var facing := gm.get_basis_with_orthogonal_index(gm.get_cell_item_orientation(c)) * Vector3(0, 0, 1)
		found.append({"cell": c, "kind": kind, "ns": absf(facing.z) > absf(facing.x), "group": -1, "shown": nm,
			"pos": gm.map_to_local(c)})
	# group the lights per intersection (connected within `cluster` metres)
	for i in found.size():
		if found[i].group >= 0:
			continue
		var g := _groups.size()
		_groups.append(_offset(found[i].pos))
		var todo := [i]
		found[i].group = g
		while not todo.is_empty():
			var a: Dictionary = found[todo.pop_back()]
			for b in found:
				if b.group < 0 and Vector2(a.pos.x - b.pos.x, a.pos.z - b.pos.z).length() <= cluster:
					b.group = g
					todo.append(found.find(b))
	_lights = found
	for light in found:
		if light.kind == "voetganger":
			_walk_lights[light.group] = true
	for g in _groups.size():
		var sum := Vector3.ZERO
		var n := 0
		for l in found:
			if l.group == g:
				sum += l.pos
				n += 1
		_centres.append(sum / maxi(n, 1))
	_put_in_step()
	if _lights.is_empty():
		set_process(false)
		return
	_update()


func _process(delta: float) -> void:
	_time += delta
	_update()


## Sets every light to the state of its stream at the current time.
func _update() -> void:
	var cycle := 2.0 * (green_time + amber_time + clearance_time)
	var changed := []
	for l in _lights:
		var t := fposmod(_time + _groups[l.group], cycle)
		var half := green_time + amber_time + clearance_time
		# the east-west stream runs the second half of the cycle
		var own := t if l.ns else fposmod(t - half, cycle)
		var phase := 2   # red
		if own < green_time:
			phase = 0
			if l.kind == "voetganger" and own >= pedestrian_time:
				phase = 2
		elif own < green_time + amber_time:
			phase = 1
		var nm: String = PREFIX + l.kind + "_" + STATES[l.kind][phase]
		if nm != l.shown and _ids.has(nm):
			l.shown = nm
			changed.append(l)
	if changed.is_empty():
		return
	for gm in _layers():
		for l in changed:
			gm.set_cell_item(l.cell, _ids[l.shown], gm.get_cell_item_orientation(l.cell))


## Phase of the car lights for traffic on the north-south (or east-west) road at the
## intersection nearest to `pos` (metres): 0 green, 1 amber, 2 red; -1 when no
## intersection with lights lies within `radius` metres (for cars, scripts/vehicles/car.gd).
func car_phase(pos: Vector3, north_south: bool, radius := 14.0) -> int:
	var best := -1
	var best_d := radius
	for g in _centres.size():
		var d := Vector2(_centres[g].x - pos.x, _centres[g].z - pos.z).length()
		if d <= best_d:
			best_d = d
			best = g
	if best < 0:
		return -1
	var half := green_time + amber_time + clearance_time
	var t := fposmod(_time + _groups[best], 2.0 * half)
	var own := t if north_south else fposmod(t - half, 2.0 * half)
	if own < green_time:
		return 0
	if own < green_time + amber_time:
		return 1
	return 2


## Whether someone on foot at `pos` (metres), crossing along z (`along_z`, beside the
## north-south stream) or along x, may start crossing at the nearest intersection with
## pedestrian lights within `radius` metres: 0 green (in the first `pedestrian_time` seconds
## of its stream's green), 1 red (wait), -1 no pedestrian lights there (scripts/world/people/pedestrian.gd).
func pedestrian_phase(pos: Vector3, along_z: bool, radius := 16.0) -> int:
	var best := -1
	var best_distance := radius
	for group in _centres.size():
		if not _walk_lights.has(group):
			continue
		var distance := Vector2(_centres[group].x - pos.x, _centres[group].z - pos.z).length()
		if distance <= best_distance:
			best_distance = distance
			best = group
	if best < 0:
		return -1
	var half := green_time + amber_time + clearance_time
	var time_in_cycle := fposmod(_time + _groups[best], 2.0 * half)
	var own := time_in_cycle if along_z else fposmod(time_in_cycle - half, 2.0 * half)
	return 0 if own < pedestrian_time else 1


## Intersections within `in_step_within` of each other (and on, chained) take the time
## offset of the first of them.
func _put_in_step() -> void:
	var done := {}
	for first in _centres.size():
		if done.has(first):
			continue
		done[first] = true
		var todo := [first]
		while not todo.is_empty():
			var group: int = todo.pop_back()
			for other in _centres.size():
				if done.has(other):
					continue
				var away := Vector2(_centres[group].x - _centres[other].x, _centres[group].z - _centres[other].z).length()
				if away <= in_step_within:
					done[other] = true
					_groups[other] = _groups[first]
					todo.append(other)


## Repeatable time offset of an intersection from its position, so they don't all switch together.
func _offset(p: Vector3) -> float:
	var h := absi(int(p.x) * 73856093 ^ int(p.z) * 19349663) % 1000
	return h / 1000.0 * 2.0 * (green_time + amber_time + clearance_time)


func _layer() -> GridMap:
	return get_parent().get_node_or_null(layer) as GridMap


## The layer and its LOD copy (Props_lod), whichever exist.
func _layers() -> Array[GridMap]:
	var out: Array[GridMap] = []
	for n in get_parent().get_children():
		if n is GridMap and (n.name == layer or String(n.name).begins_with(layer + "_lod")):
			out.append(n)
	return out
