extends Control
## Where the player is, over the minimap of the HUD (the node "Locatie"; behaviour,
## docs/CODE_LAGEN.md): every half second (tick) it looks (look) which neighbourhood,
## street and named place the player is at (location_rules.gd, from the metadata of the
## town) and hands them to its picture (location_view.gd). It keeps the neighbourhoods
## visited; one entered for the first time (not the one the game starts in) is a new area
## (new_area_entered: the HUD shows the notice). Inside a building: the neighbourhood the
## building counts as (set_indoor).
##   const Location = preload("res://scripts/ui/hud/location.gd")

const LocationRules = preload("res://scripts/ui/hud/location_rules.gd")
const LocationView = preload("res://scripts/ui/hud/location_view.gd")
## Seconds between looks at where the player is.
const INTERVAL := 0.5

## A neighbourhood entered for the first time: the name it is shown by.
signal new_area_entered(shown_name: String)

## Its picture.
var view: LocationView
## Metres within which the nearest named place shows under the neighbourhood.
var place_near := 45.0

var _clock := 0.0
var _current_wijk := ""
var _indoor_wijk := ""           # inside a building: the neighbourhood it counts as
var _visited := {}               # key of a neighbourhood -> true


func _init() -> void:
	name = "Locatie"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	view = LocationView.new()
	add_child(view)


## `delta` seconds on. True when it is time to look again (every INTERVAL).
func tick(delta: float) -> bool:
	_clock -= delta
	if _clock > 0.0:
		return false
	_clock = INTERVAL
	return true


## Seconds until the next look.
func seconds_to_look() -> float:
	return _clock


## Shows where the player is: at the world point `at` (x, z) of `world` (the scene with
## the metadata "wijken", "straten" and "places"). A neighbourhood entered for the first
## time is announced (new_area_entered).
func look(world: Node, at: Vector2) -> void:
	if world == null:
		return
	var here := LocationRules.where(world.get_meta("wijken", []), world.get_meta("straten", []),
			world.get_meta("places", {}), at, place_near, _indoor_wijk)
	var wijk: String = here.wijk
	var area_text: String = here.shown_name.to_upper()
	view.show_location(area_text, here.street, here.place, LocationRules.is_place_shown(here.place, wijk, here.shown_name, here.street))
	var room := view.area_room()
	if room > 0.0:
		view.show_area_font_size(LocationRules.fitting_font_size(room, func(font_size: int) -> float: return view.area_width(area_text, font_size)))
	if wijk != _current_wijk:
		if LocationRules.is_new_area(wijk, _current_wijk, _visited.keys()):
			new_area_entered.emit(here.shown_name)
		_current_wijk = wijk
		_visited[wijk] = true


## Inside a building (Interiors): the location is `wijk` (a key of the "wijken" metadata,
## e.g. "Centraal Station") in place of the spot far off the map; "" when going out again.
## Shown at the next tick.
func set_indoor(wijk: String) -> void:
	_indoor_wijk = wijk
	_clock = 0.0


## The neighbourhood of the building the player is in ("" outside).
func indoor_area() -> String:
	return _indoor_wijk


## The neighbourhood the player is in (its key; "" before the first look).
func current_area() -> String:
	return _current_wijk


## The neighbourhoods the player has been in (names as in the "wijken" metadata).
func visited_areas() -> Array:
	return _visited.keys()


## Counts `wijk` as visited (a saved game, a test).
func mark_visited(wijk: String) -> void:
	_visited[wijk] = true
