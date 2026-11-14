extends Control
## The KAART tab of the game menu (the node "Kaart"; behaviour, docs/CODE_LAGEN.md): it
## keeps the places of the map and which one is chosen, takes the keys of the tab (arrows /
## WASD the next place that way, Enter the marker, T the debug teleport) and the clicks on
## the map (left chooses, right sets the marker, Shift+left the debug teleport), asks
## map_tab_rules.gd what to show of the town (the scene metadata "places", "wijken" and
## "straten", the cash machines under Straatautomaten) and of the HUD (minimap_texture(),
## visited_areas(), quest_targets(), the waypoint, the story's shroud), and hands that to
## map_tab_view.gd. The marker goes through the HUD (set_waypoint / clear_waypoint).
## Made by scripts/ui/game_menu.gd, which refreshes it and passes the keys on.
##   const MapTab = preload("res://scripts/ui/game_menu/map_tab.gd")

const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const LocationRules = preload("res://scripts/ui/hud/location_rules.gd")
const MinimapRules = preload("res://scripts/ui/hud/minimap_rules.gd")
const MenuRules = preload("res://scripts/ui/game_menu/menu_rules.gd")
const MenuPlayer = preload("res://scripts/ui/game_menu/menu_player.gd")
const MapTabRules = preload("res://scripts/ui/game_menu/map_tab_rules.gd")
const MapTabLayout = preload("res://scripts/ui/game_menu/map_tab_layout.gd")
const MapTabView = preload("res://scripts/ui/game_menu/map_tab_view.gd")
## The group of the interiors (no teleport from inside a building), of the story (its
## markers) and the node of the pedestrians (the nearest walkable cell).
const INTERIORS_GROUP := "binnenruimtes"
const STORY_GROUP := "verhaal"
const WALKERS_NODE := "Voetgangers"

## The debug teleport put the player somewhere: the menu closes.
signal teleported

## Its picture.
var view: MapTabView
## The player (where it is and looks; the menu sets it).
var player: MenuPlayer
## The HUD whose map this is (the menu sets it); may be null.
var hud: Node

var _places: Array[Dictionary] = []   # {"key", "name", "position": Vector2 world x, z, "wijk"}
var _selected_place := ""
var _visited := {}                    # wijk name -> true
var _areas: Array = []                # the "wijken" of the town as last shown


func _init() -> void:
	name = "Kaart"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	player = MenuPlayer.new()
	view = MapTabView.new()
	add_child(view)
	var chains: Array = []
	for chain: String in MapTabRules.SUPERMARKET_NAMES:
		chains.append([chain, String(MapTabRules.SUPERMARKET_NAMES[chain]).capitalize()])
	view.show_legend(chains, MapTabRules.CASH_MACHINE_NAME)
	view.map_pressed.connect(_on_map_pressed)


## Shows the map, the fog, the places, the player and the chosen place as they are now.
func refresh() -> void:
	var town := world()
	var player_at := player_position()
	_areas = town.get_meta("wijken", []) if town else []
	_visited = MapTabRules.visited(hud.visited_areas() if hud and hud.has_method("visited_areas") else [],
			MapTabRules.area_at(_areas, player_at))
	_places = MapTabRules.places(town.get_meta("places", {}) if town else {}, _cash_machines(town), _areas, is_shrouded)
	_selected_place = MapTabRules.selected_after_change(_places, _selected_place, player_at)
	view.show_coordinates(MapTabRules.coordinates_text(player_at))
	var heading := player.heading(get_viewport().get_camera_3d())
	view.show_player(player_at, MinimapRules.has_heading(heading), MinimapRules.arrow_rotation(heading))
	view.show_map(_map_texture(), _map_origin(), _metres_per_pixel())
	if town:
		view.show_fog(MapTabRules.fog_areas(_areas, _visited), hud.shroud_image() if hud and hud.has_method("shroud_image") else null)
	else:
		view.show_no_fog()
	var street := LocationRules.street_at(town.get_meta("straten", []), LocationRules.cell_of(player_at)) if town else ""
	view.show_here(MapTabRules.area_at(_areas, player_at).to_upper(), MapTabRules.street_text(street), street != "")
	view.show_area_labels(MapTabRules.area_labels(_areas, _visited, is_shrouded))
	_show_places()


## The line of the tab bar while this tab is open (as of the last refresh).
func header_text() -> String:
	return MapTabRules.header_text(_areas, _visited)


## A key while this tab is open: the arrows, Enter and (debug builds) T.
func handle_key(key: Key) -> void:
	var direction := MenuRules.direction(key)
	if key == MapTabRules.KEY_TELEPORT and OS.is_debug_build():
		var chosen := MapTabRules.place(_places, _selected_place)
		if not chosen.is_empty():
			teleport_to(chosen.position)
		return
	if direction != Vector2i.ZERO:
		move_selection(Vector2(direction))
	elif MenuRules.is_accept(key):
		toggle_marker()


## Chooses the place with this key; nothing for "" or the one chosen already.
func choose_place(place_key: String) -> void:
	if place_key == "" or place_key == _selected_place:
		return
	UiSounds.play(self, "kies")
	_selected_place = place_key
	_show_places()


## The nearest place in this direction (on screen) from the chosen one; without a chosen
## one the place nearest to the player.
func move_selection(direction: Vector2) -> void:
	if MapTabRules.place(_places, _selected_place).is_empty():
		choose_place(MapTabRules.nearest_place(_places, player_position()))
		return
	choose_place(MapTabRules.place_towards(_map_points(), _selected_place, direction))


## The marker on the chosen place (GameHud.set_waypoint: on the minimap and as a beam of
## light in the town), or off again when it is there already.
func toggle_marker() -> void:
	var chosen := MapTabRules.place(_places, _selected_place)
	if chosen.is_empty() or hud == null or not hud.has_method("set_waypoint"):
		return
	if _marker_on(chosen):
		hud.clear_waypoint()
		UiSounds.play(self, "terug")
	else:
		hud.set_waypoint(chosen.position, MapTabRules.marker_name(chosen))
		UiSounds.play(self, "doe")
	_show_places()


## Debug (debug builds: T on the chosen place, Shift+click anywhere on the map): the player to
## `spot` (world x, z), on the nearest walkable cell there (not into a building or the water).
## Not from inside a building. Emits `teleported` (the menu closes).
func teleport_to(spot: Vector2) -> void:
	var interiors := get_tree().get_first_node_in_group(INTERIORS_GROUP)
	if not player.can_teleport() or (interiors and interiors.has_method("is_inside") and interiors.is_inside()):
		return
	var town := world()
	var walkers: Node = town.get_node_or_null(WALKERS_NODE) if town else null
	var ground: Variant = null
	if walkers and walkers.has_method("nearest_walkable"):
		ground = walkers.cell_middle(walkers.nearest_walkable(walkers.cell_of(Vector3(spot.x, 0.0, spot.y))))
	var at := MapTabRules.teleport_point(spot, player.height(), ground)
	player.teleport(at)
	print("debug: naar %.0f, %.0f" % [at.x, at.z])
	UiSounds.play(self, "doe")
	teleported.emit()


## The scene the HUD belongs to (its metadata: "places", "wijken", "straten"); without a
## HUD the current scene.
func world() -> Node:
	if hud:
		return hud.owner if hud.owner else hud.get_parent()
	return get_tree().current_scene


## Where the player is (world x, z).
func player_position() -> Vector2:
	return player.position(get_viewport().get_camera_3d())


## Whether the world point is still under the story's shroud (GameHud.is_shrouded).
func is_shrouded(world_point: Vector2) -> bool:
	return hud != null and hud.has_method("is_shrouded") and hud.is_shrouded(world_point)


## The places of the map as of the last refresh: {"key", "name", "position", "wijk"} each.
func places() -> Array[Dictionary]:
	return _places


## The key of the chosen place ("" none).
func selected_place() -> String:
	return _selected_place


## The neighbourhoods that count as visited (name -> true), as of the last refresh.
func visited() -> Dictionary:
	return _visited


## The marks and the panel of the chosen place, and what lies over the marks.
func _show_places() -> void:
	view.show_marks(MapTabRules.marks(_places, _selected_place, _visited, is_shrouded))
	var has_waypoint: bool = hud != null and hud.has_method("has_waypoint") and hud.has_waypoint()
	var targets: Array = hud.quest_targets() if hud and hud.has_method("quest_targets") else []
	view.show_pointers(_story_markers(), has_waypoint, hud.waypoint() if has_waypoint else Vector2.ZERO,
			targets.filter(func(target: Vector2) -> bool: return not is_shrouded(target)))
	var chosen := MapTabRules.place(_places, _selected_place)
	if chosen.is_empty():
		view.show_no_place()
	else:
		view.show_place(MapTabRules.place_panel(chosen, _visited, player_position(), _marker_on(chosen)))


func _marker_on(a_place: Dictionary) -> bool:
	var has_waypoint: bool = hud != null and hud.has_method("has_waypoint") and hud.has_waypoint()
	return MapTabRules.is_marker_on(a_place, has_waypoint, hud.waypoint() if has_waypoint else Vector2.ZERO)


## Where each place lies on the map now: key -> point of the map.
func _map_points() -> Dictionary:
	var points := {}
	for a_place: Dictionary in _places:
		points[a_place.key] = view.world_to_map(a_place.position)
	return points


## The spots (world x, z) of the cash machines in the streets of `town`, in their order.
func _cash_machines(town: Node) -> Array:
	var spots: Array = []
	var machines := town.get_node_or_null(MapTabRules.CASH_MACHINE_NODE) if town else null
	if machines:
		for marker in machines.get_children():
			if marker is Node3D and MapTabRules.is_cash_machine_marker(String(marker.name)):
				spots.append(MinimapRules.flat((marker as Node3D).global_position))
	return spots


## The places the missions marked for good (Story.markers), world x, z.
func _story_markers() -> Array:
	var story := get_tree().get_first_node_in_group(STORY_GROUP)
	return story.markers().values() if story and story.has_method("markers") else []


func _map_texture() -> Texture2D:
	if hud and hud.has_method("minimap_texture"):
		return hud.minimap_texture()
	return null


func _map_origin() -> Vector2:
	if hud and hud.has_method("minimap_origin"):
		return hud.minimap_origin()
	return Vector2.ZERO


func _metres_per_pixel() -> float:
	if hud and hud.has_method("minimap_metres_per_pixel"):
		return maxf(hud.minimap_metres_per_pixel(), 0.01)
	return MapTabRules.CELL_METRES


## A click on the map: the place under it chosen; a right click also sets the marker on it;
## Shift+left click (debug builds) puts the player there.
func _on_map_pressed(point: Vector2, button: int, with_shift: bool) -> void:
	if button == MOUSE_BUTTON_LEFT and with_shift and OS.is_debug_build():
		teleport_to(view.map_to_world(point))
		return
	var picked := MapTabRules.picked_place(_map_points(), point, MapTabLayout.MARKER_PICK_RADIUS)
	choose_place(picked)
	if button == MOUSE_BUTTON_RIGHT and picked != "":
		toggle_marker()
