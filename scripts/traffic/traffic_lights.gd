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
##
## This is the behaviour (the node the vehicles and the people ask: car_phase,
## pedestrian_phase; the clock of the cycle). The cycle itself is traffic_lights_rules.gd,
## the grouping per intersection traffic_lights_layout.gd, the props traffic_lights_view.gd.

const TrafficLightsRules = preload("res://scripts/traffic/traffic_lights_rules.gd")
const TrafficLightsLayout = preload("res://scripts/traffic/traffic_lights_layout.gd")
const TrafficLightsView = preload("res://scripts/traffic/traffic_lights_view.gd")

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

const PREFIX := TrafficLightsRules.PREFIX
## kind -> [green, amber, red] state names in the prop names
const STATES := TrafficLightsRules.STATES

var view: TrafficLightsView
var _lights := []        # {cell, kind, ns, group, shown}
var _groups := []        # per intersection: time offset
var _centres := []       # per intersection: mean position of its lights (metres)
var _walk_lights := {}   # intersection -> true if it has pedestrian lights
var _all_groups: Array[int] = []    # every intersection
var _walk_groups: Array[int] = []   # the intersections with pedestrian lights
var _time := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	view = TrafficLightsView.new(get_parent(), layer)
	if not view.has_layer():
		set_process(false)
		return
	var positions := []
	for prop: Dictionary in view.light_props(PREFIX):
		var kind := TrafficLightsRules.kind_of_prop(prop.prop)
		if kind == "":
			continue
		_lights.append({"cell": prop.cell, "kind": kind, "ns": TrafficLightsRules.faces_north_south(prop.facing),
			"group": -1, "shown": prop.prop, "pos": prop.pos})
		positions.append(prop.pos)
	var group_of := TrafficLightsLayout.groups(positions, cluster)
	for light_index in _lights.size():
		_lights[light_index].group = group_of[light_index]
		if _lights[light_index].kind == TrafficLightsRules.PEDESTRIAN_KIND:
			_walk_lights[group_of[light_index]] = true
	for first_light in TrafficLightsLayout.first_lights(group_of):
		_groups.append(TrafficLightsRules.time_offset(positions[first_light], _half_cycle()))
	_centres = TrafficLightsLayout.centres(positions, group_of)
	_groups = TrafficLightsRules.offsets_in_step(_groups, _centres, in_step_within)
	for group in _groups.size():
		_all_groups.append(group)
		if _walk_lights.has(group):
			_walk_groups.append(group)
	if _lights.is_empty():
		set_process(false)
		return
	_update()


func _process(delta: float) -> void:
	_time += delta
	_update()


## Sets every light to the state of its stream at the current time.
func _update() -> void:
	var half := _half_cycle()
	var cells := []
	var props := []
	for light in _lights:
		var own := TrafficLightsRules.stream_time(_time, _groups[light.group], light.ns, half)
		var phase := TrafficLightsRules.light_phase(light.kind, own, green_time, amber_time, pedestrian_time)
		var prop := TrafficLightsRules.prop_name(light.kind, phase)
		if prop != light.shown and view.has_prop(prop):
			light.shown = prop
			cells.append(light.cell)
			props.append(prop)
	if not cells.is_empty():
		view.show_props(cells, props)


## Phase of the car lights for traffic on the north-south (or east-west) road at the
## intersection nearest to `pos` (metres): 0 green, 1 amber, 2 red; -1 when no
## intersection with lights lies within `radius` metres (for cars, scripts/vehicles/car.gd).
func car_phase(pos: Vector3, north_south: bool, radius := 14.0) -> int:
	var nearest := TrafficLightsLayout.nearest(_centres, _all_groups, pos, radius)
	if nearest == TrafficLightsLayout.NONE:
		return TrafficLightsRules.NO_LIGHTS
	var own := TrafficLightsRules.stream_time(_time, _groups[nearest], north_south, _half_cycle())
	return TrafficLightsRules.car_phase(own, green_time, amber_time)


## Whether someone on foot at `pos` (metres), crossing along z (`along_z`, beside the
## north-south stream) or along x, may start crossing at the nearest intersection with
## pedestrian lights within `radius` metres: 0 green (in the first `pedestrian_time` seconds
## of its stream's green), 1 red (wait), -1 no pedestrian lights there (scripts/world/people/pedestrian.gd).
func pedestrian_phase(pos: Vector3, along_z: bool, radius := 16.0) -> int:
	var nearest := TrafficLightsLayout.nearest(_centres, _walk_groups, pos, radius)
	if nearest == TrafficLightsLayout.NONE:
		return TrafficLightsRules.NO_LIGHTS
	var own := TrafficLightsRules.stream_time(_time, _groups[nearest], along_z, _half_cycle())
	return TrafficLightsRules.walk_phase(own, pedestrian_time)


## Seconds one stream takes (green, amber, all red).
func _half_cycle() -> float:
	return TrafficLightsRules.half_cycle(green_time, amber_time, clearance_time)
