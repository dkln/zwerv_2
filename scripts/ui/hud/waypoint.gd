extends Control
## The marker set on the map (the node "Marker", its chip under the minimap; behaviour,
## docs/CODE_LAGEN.md): the place you chose on the map of the game menu (set_at), one at a
## time. It keeps where it is and its name, stands a beam of light on it in the town
## (WaypointBeacon, on the ground there), says in its chip how far it is (follow;
## waypoint_rules.gd, waypoint_view.gd), and is gone once the player is there (`arrived`)
## or with clear. Inside a building it waits, its beam hidden. Its mark on the minimap is
## the minimap's (Minimap.show_waypoint).
##   const Waypoint = preload("res://scripts/ui/hud/waypoint.gd")

const WaypointRules = preload("res://scripts/ui/hud/waypoint_rules.gd")
const WaypointView = preload("res://scripts/ui/hud/waypoint_view.gd")
const WaypointBeacon = preload("res://scripts/world/town/waypoint_beacon.gd")
## The ground is looked for from just over street level, not from the sky: a place often
## lies against a facade, whose roof would be hit first.
const GROUND_QUERY_FROM := 1.5
const GROUND_QUERY_TO := -20.0

## The player reached the marker `place_name`, standing at `focus` (the marker is gone).
signal arrived(place_name: String, focus: Vector3)

## Its picture.
var view: WaypointView
## The town the beam stands in (the node the HUD hangs under).
var town: Node
## The viewport of the world (its physics give the height of the ground).
var world_viewport: Viewport

var _at := WaypointRules.NONE    # where it is (world x, z)
var _place_name := ""
var _beacon: Node3D              # its beam of light in the town


func _init() -> void:
	name = "Marker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	view = WaypointView.new()
	add_child(view)


## A marker on `at` (world x, z), named `place_name`: its name in the chip, a beam of light
## on it in the town. In place of the one before.
func set_at(at: Vector2, place_name: String) -> void:
	_at = at
	_place_name = place_name
	if _beacon == null or not is_instance_valid(_beacon):
		_beacon = WaypointBeacon.new()
		if town:
			town.add_child(_beacon)
	if _beacon.is_inside_tree():
		_beacon.place(Vector3(at.x, _ground_height(at), at.y))
	visible = true
	view.show_text(WaypointRules.chip_text(place_name))


## Takes the marker away, its beam with it.
func clear() -> void:
	_at = WaypointRules.NONE
	_place_name = ""
	if _beacon and is_instance_valid(_beacon):
		_beacon.queue_free()
	_beacon = null
	visible = false


func is_set() -> bool:
	return _at != WaypointRules.NONE


## Where the marker is (world x, z); Vector2.INF when there is none.
func at() -> Vector2:
	return _at


func place_name() -> String:
	return _place_name


## Its beam in the town; null when there is no marker.
func beacon() -> Node3D:
	return _beacon


## The player is at `focus`: how far the marker is, in its chip; there: `arrived` and it is
## gone. Not `outdoors` (the minimap a floor plan): it waits, its beam hidden.
func follow(focus: Vector3, outdoors: bool) -> void:
	if not is_set():
		return
	if _beacon and is_instance_valid(_beacon):
		_beacon.visible = outdoors
	if not outdoors:
		return
	var distance := _at.distance_to(Vector2(focus.x, focus.z))
	view.show_text(WaypointRules.distance_text(_place_name, distance))
	if WaypointRules.has_arrived(distance):
		var reached := _place_name
		clear()
		arrived.emit(reached, focus)


## The height of the ground at `at` (world x, z), for the foot of the beam; 0 when unknown.
func _ground_height(at: Vector2) -> float:
	var viewport := world_viewport if world_viewport else get_viewport()
	var world := viewport.world_3d if viewport else null
	if world == null:
		return 0.0
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, GROUND_QUERY_FROM, at.y), Vector3(at.x, GROUND_QUERY_TO, at.y), 1)
	var hit := world.direct_space_state.intersect_ray(query)
	return (hit.position as Vector3).y if not hit.is_empty() else 0.0
