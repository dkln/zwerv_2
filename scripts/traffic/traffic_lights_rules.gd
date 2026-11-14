extends RefCounted
## The logic of the traffic lights (the rules layer of scripts/traffic/traffic_lights.gd, the
## behaviour; traffic_lights_layout.gd groups the lights per intersection,
## traffic_lights_view.gd swaps the props): the cycle
##   north-south green -> amber -> all red -> east-west green -> amber -> all red
## as plain sums. Which stream a light belongs to by the way it faces, where in the cycle a
## stream is, the phase of a light of each kind, the prop that shows it, the repeatable time
## offset of an intersection and which intersections run in step.
##   const TrafficLightsRules = preload("res://scripts/traffic/traffic_lights_rules.gd")

## The phases of a light.
const GREEN := 0
const AMBER := 1
const RED := 2
## No intersection with lights there (car_phase, pedestrian_phase).
const NO_LIGHTS := -1
## Someone on foot: may start crossing, or waits.
const WALK := 0
const WAIT := 1

## The light props are named PREFIX + <kind>_<state>.
const PREFIX := "verkeerslichten/"
## kind -> [green, amber, red] state names in the prop names
const STATES := {
	"auto": ["groen", "oranje", "rood"],
	"fiets": ["groen", "oranje", "rood"],
	"mast": ["groen", "oranje", "rood"],
	"ov": ["rijden", "attentie", "stop"],
	"voetganger": ["groen", "rood", "rood"],
}
const PEDESTRIAN_KIND := "voetganger"


## The kind of light of a prop ("auto", "ov", ...); "" when the prop is no traffic light.
static func kind_of_prop(prop_name: String) -> String:
	if not prop_name.begins_with(PREFIX):
		return ""
	var kind := prop_name.trim_prefix(PREFIX).get_slice("_", 0)
	return kind if STATES.has(kind) else ""


## The prop that shows a light of `kind` in `phase` (GREEN, AMBER, RED).
static func prop_name(kind: String, phase: int) -> String:
	return PREFIX + kind + "_" + STATES[kind][phase]


## True if a light facing `facing` belongs to the north-south stream: one facing south or
## north is seen by the traffic on the north-south road.
static func faces_north_south(facing: Vector3) -> bool:
	return absf(facing.z) > absf(facing.x)


## Seconds one stream takes: its green, its amber and the time all lights are red after it.
static func half_cycle(green_time: float, amber_time: float, clearance_time: float) -> float:
	return green_time + amber_time + clearance_time


## Where a stream is in its own cycle (seconds since its green began) at `time`, at an
## intersection with time offset `offset`: the east-west stream runs the second half.
static func stream_time(time: float, offset: float, north_south: bool, half: float) -> float:
	var in_cycle := fposmod(time + offset, 2.0 * half)
	return in_cycle if north_south else fposmod(in_cycle - half, 2.0 * half)


## The phase of the car lights `own` seconds into their stream's cycle (stream_time).
static func car_phase(own: float, green_time: float, amber_time: float) -> int:
	if own < green_time:
		return GREEN
	if own < green_time + amber_time:
		return AMBER
	return RED


## The phase a light of `kind` shows `own` seconds into its stream's cycle: as the cars, but
## a pedestrian light is only green the first `pedestrian_time` seconds of the green.
static func light_phase(kind: String, own: float, green_time: float, amber_time: float, pedestrian_time: float) -> int:
	var phase := car_phase(own, green_time, amber_time)
	if phase == GREEN and kind == PEDESTRIAN_KIND and own >= pedestrian_time:
		return RED
	return phase


## Whether someone on foot may start crossing `own` seconds into the cycle of the stream
## alongside: WALK the first `pedestrian_time` seconds, WAIT after.
static func walk_phase(own: float, pedestrian_time: float) -> int:
	return WALK if own < pedestrian_time else WAIT


## Repeatable time offset (seconds, within a cycle of 2 x `half`) of an intersection from the
## position of its first light, so they don't all switch together.
static func time_offset(position: Vector3, half: float) -> float:
	var hashed := absi(int(position.x) * 73856093 ^ int(position.z) * 19349663) % 1000
	return hashed / 1000.0 * 2.0 * half


## The time offsets with the intersections close together put in step: those within
## `in_step_within` metres of each other (and on, chained; `centres` their middles) take the
## offset of the first of them.
static func offsets_in_step(offsets: Array, centres: Array, in_step_within: float) -> Array:
	var in_step := offsets.duplicate()
	var done := {}
	for first in centres.size():
		if done.has(first):
			continue
		done[first] = true
		var todo := [first]
		while not todo.is_empty():
			var group: int = todo.pop_back()
			for other in centres.size():
				if done.has(other):
					continue
				var away := Vector2(centres[group].x - centres[other].x, centres[group].z - centres[other].z).length()
				if away <= in_step_within:
					done[other] = true
					in_step[other] = in_step[first]
					todo.append(other)
	return in_step
