extends Control
## The minimap of the HUD (the node "Kaartje", top right; behaviour, docs/CODE_LAGEN.md):
## north up, the player in the middle. It builds the picture of the town once from the
## Grond and Gebouwen GridMaps (build; no extra camera), follows the player each frame
## (follow: the vehicle the Volgcamera follows, else the point the camera looks at), marks
## the places of the followed quest and the marker set on the map, lays the shroud of the
## story over what is not open yet (refresh_shroud), and inside a building shows its floor
## plan with its ways out (show_interior_plan, show_town_plan). It asks minimap_rules.gd
## where things land and tells its picture (minimap_view.gd); its sizes: minimap_layout.gd.
##   const Minimap = preload("res://scripts/ui/hud/minimap.gd")

const MinimapRules = preload("res://scripts/ui/hud/minimap_rules.gd")
const MinimapView = preload("res://scripts/ui/hud/minimap_view.gd")
const Layout = preload("res://scripts/ui/hud/minimap_layout.gd")
const Iso = preload("res://scripts/camera/iso_camera.gd")
const InteriorPlan = preload("res://scripts/ui/widgets/interior_plan.gd")

## Its picture.
var view: MinimapView
## Metres across the minimap (in the town; inside a building as much as its plan needs).
var metres := 160.0
## The viewport whose camera looks at the world (the HUD draws in a picture of its own
## without 3D, so it is handed the main one).
var world_viewport: Viewport
## The Volgcamera of the town (its target is the player), if any.
var follow_camera: Node
## The story (scripts/story/story.gd), if any: its shroud hides what is not open yet.
var story: Node

var _origin := Vector2.ZERO           # world x, z of the corner of the map picture
var _metres_per_pixel := 4.0
var _map_lowest := Vector2i.ZERO      # the cell of the first pixel of the town's picture
var _shroud_image: Image              # the same size as the town's picture, opaque where shrouded
var _exit_points: Array[Vector3] = []
var _town_map := {}                   # the town's map while an interior's plan is shown
var _interior_plans := {}             # interior instance id -> its plan (InteriorPlan.build)
var _metres_now := 0.0                # metres across now (0: `metres`)
var _focus := Vector3.ZERO            # where the player is, from the last follow
var _has_focus := false


func _init() -> void:
	name = "Kaartje"
	size = Layout.frame_size()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	view = MinimapView.new()
	add_child(view)


## Builds the picture of the town, one pixel per cell: the kind of ground of the top Grond
## tile at street level, and dark where the Gebouwen GridMap has a building. False when
## there is no ground to draw.
func build(ground: GridMap, buildings: GridMap) -> bool:
	if ground == null or ground.mesh_library == null:
		return false
	var top := MinimapRules.top_cells(ground.get_used_cells())
	if top.is_empty():
		return false
	var map_bounds := MinimapRules.bounds(top.keys())
	var kind_of_item := {}
	var kind_of_column := {}
	for column: Vector2i in top:
		var item := ground.get_cell_item(top[column])
		if not kind_of_item.has(item):
			kind_of_item[item] = MinimapRules.kind_of(ground.mesh_library.get_item_name(item))
		kind_of_column[column] = kind_of_item[item]
	var building_cells: Array = []
	if buildings != null:
		building_cells = buildings.get_used_cells()
	var image := MinimapView.map_image(map_bounds.size, MinimapRules.pixel_kinds(kind_of_column, building_cells, map_bounds))
	var cell_metres := ground.cell_size.x
	show_map(ImageTexture.create_from_image(image),
			MinimapRules.origin(map_bounds.position, cell_metres, MinimapRules.flat(ground.position)), cell_metres)
	_map_lowest = map_bounds.position
	if story and story.has_signal("shroud_changed") and not story.shroud_changed.is_connected(refresh_shroud):
		story.shroud_changed.connect(refresh_shroud)
	refresh_shroud()
	return true


## A map picture of one pixel per `metres_per_pixel` metres, its corner at world x, z
## `map_origin`.
func show_map(map_texture: Texture2D, map_origin: Vector2, metres_per_pixel_of_map: float) -> void:
	view.show_map(map_texture)
	_origin = map_origin
	_metres_per_pixel = metres_per_pixel_of_map


## The picture of the map that shows (the town's, or an interior's plan); null while it
## is not built yet.
func texture() -> Texture2D:
	return view.map_texture()


## World x, z of the corner of that picture.
func origin() -> Vector2:
	return _origin


func metres_per_pixel() -> float:
	return _metres_per_pixel


## Moves the map so the player is in the middle, turns the arrow its way, and marks the
## `targets` (world x, z; the places of the followed quest) and the ways out of an
## interior. False when there is nothing to follow: no map yet, or no player and no camera.
func follow(targets: Array) -> bool:
	if view.map_texture() == null:
		return false
	var heading := Vector3.FORWARD
	var focus := Vector3.ZERO
	var followed: Node3D = null
	if follow_camera != null and follow_camera.has_method("is_following") and follow_camera.is_following():
		followed = follow_camera.get("target_node")
	var viewport := world_viewport if world_viewport else get_viewport()
	var camera := viewport.get_camera_3d() if viewport else null
	if followed != null:
		focus = followed.global_position
		heading = followed.global_basis.z   # vehicles drive along +Z
	elif camera != null:
		focus = Iso.ground_focus(camera)
		heading = -camera.global_basis.z
	else:
		return false
	var pixels_for_a_metre := pixels_per_metre()
	_focus = focus
	_has_focus = true
	view.place_map(MinimapRules.map_position(Layout.centre(), MinimapRules.flat(focus), _origin, pixels_for_a_metre),
			MinimapRules.map_size(view.map_texture().get_size(), pixels_for_a_metre, _metres_per_pixel))
	var indoors := is_indoors()
	view.show_shroud_over_map(not indoors and _shroud_image != null)
	var flat_heading := MinimapRules.flat(heading)
	if MinimapRules.has_heading(flat_heading):
		view.turn_arrow(MinimapRules.arrow_rotation(flat_heading))
	# inside a building: its ways out, not the quest places in the town; only a place in the
	# building itself (the cans of mission 1 in the station, Story)
	var marks := []
	for target: Vector2 in targets:
		var distance := (target - MinimapRules.flat(focus)).length()
		if MinimapRules.is_target_marked(indoors, distance, not indoors and is_shrouded(target)):
			marks.append(mark_position(target))
	view.show_quest_marks(marks)
	var exits := []
	for exit_point in _exit_points:
		exits.append(mark_position(MinimapRules.flat(exit_point)))
	view.show_exit_marks(exits)
	return true


## Where the player is (the last follow), and whether it is known yet.
func focus() -> Vector3:
	return _focus


func is_focus_known() -> bool:
	return _has_focus


## Pixels of the minimap per metre of the world, now.
func pixels_per_metre() -> float:
	return MinimapRules.pixels_per_metre(Layout.map_rect().size.x, MinimapRules.metres_across(_metres_now, metres))


## Where the world point (x, z) lands on the minimap, in the pixels of its map.
func mark_position(world: Vector2) -> Vector2:
	return MinimapRules.mark_position(Layout.centre(), MinimapRules.flat(_focus), world, pixels_per_metre())


## The marker set on the map at `at` (world x, z; Vector2.INF: none): its mark, an arrow on
## the edge while it is further. Not on the floor plan of a building.
func show_waypoint(at: Vector2) -> void:
	var points := []
	if MinimapRules.is_waypoint_marked(at, is_indoors()):
		points.append(mark_position(at))
	view.show_waypoint_marks(points)


## True while the minimap shows the floor plan of a building.
func is_indoors() -> bool:
	return not _town_map.is_empty()


## Inside `interior` (Interiors.enter): the minimap shows its floor plan, read from its
## colliders (InteriorPlan; made once per interior, a physics step after it is live), and
## its ways out (`exits`, world positions) as green marks, or arrows on the edge.
func show_interior_plan(interior: Node3D, exits: Array[Vector3]) -> void:
	_exit_points = exits
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _exit_points != exits or not is_instance_valid(interior):
		return   # out again meanwhile
	# an interior can say which part of it is the plan (the floor you are on in the city hall,
	# the layout of this branch of a supermarket: plan_root); a new part is a new plan
	var plan_source: Node3D = interior.call("plan_root") if interior.has_method("plan_root") else interior
	if plan_source == null:
		plan_source = interior
	var key := plan_source.get_instance_id()
	if not _interior_plans.has(key):
		_interior_plans[key] = InteriorPlan.build(plan_source)
	var plan: Dictionary = _interior_plans[key]
	if plan.is_empty():
		return
	if _town_map.is_empty():
		_town_map = {"texture": view.map_texture(), "origin": _origin, "metres_per_pixel": _metres_per_pixel}
	show_map(plan.texture, plan.origin, plan.metres_per_pixel)
	_metres_now = MinimapRules.interior_metres(plan.extent, metres)


## Back outside: the town's map on the minimap again.
func show_town_plan() -> void:
	_exit_points = []
	_metres_now = 0.0
	if _town_map.is_empty():
		return
	show_map(_town_map.texture, _town_map.origin, _town_map.metres_per_pixel)
	_town_map = {}


## The shroud of the story painted over the town's map: every cell it has not opened in the
## colour of the empty map (opaque), the open ones clear; the minimap and the game menu's
## map use it (shroud_image). Again whenever the story opens more (Story.shroud_changed).
func refresh_shroud() -> void:
	var map_texture: Texture2D = _town_map.get("texture", view.map_texture())
	if story == null or not is_instance_valid(story) or not "shroud" in story or map_texture == null:
		_shroud_image = null
		view.show_shroud(null)
		return
	var map_size := Vector2i(map_texture.get_size())
	_shroud_image = MinimapView.shroud_image(map_size, MinimapRules.shrouded_pixels(map_size, _map_lowest, story.shroud.is_open_cell))
	view.show_shroud(_shroud_image)


## The shroud over the town's map picture (its pixels), null when all is open.
func shroud_image() -> Image:
	return _shroud_image


## Whether the world point (x, z) is under the shroud (hidden on the maps).
func is_shrouded(world: Vector2) -> bool:
	return story != null and is_instance_valid(story) and "shroud" in story and not story.shroud.is_open(world.x, world.y)
