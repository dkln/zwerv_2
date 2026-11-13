extends Node
## A view hole through buildings (the "Doorkijk" node): while the follow camera (Volgcamera,
## scripts/camera/follow_camera.gd) follows the player (or a vehicle), every building that
## stands between it and the camera gets a round hole (`hole_radius` metres) in it, along the
## view from the player to the camera, opening and closing in `fade_time`; the rest of the
## building stays.
##
## A building is a group of touching cells of the Gebouwen GridMap (seen from above:
## cells that share a side, at any height). The merged chunk meshes hold many buildings,
## so the fading is done in the voxel shaders (addons/vox_tiles/materials/voxel_fade.gdshaderinc):
## a texture with one pixel per 4 x 4 m cell holds how far the building on that cell has
## opened its hole (global shader parameters `zwervr_fade_map` and `zwervr_fade_area`; the
## last row of the texture holds the hole: pixel 0 = its centre x, y, z and radius), and the
## shaders leave out what of it lies in the hole (a dithered edge). Every cell of a building
## gets the same value, so its hole opens at once (never single faces), and its shadow stays.
##
## Shaders that can leave out pixels are much slower on tile-based GPUs (Apple), so the
## voxel shaders only do it when compiled with ZWERVR_FADE: only the merged chunk meshes
## (Gebouwen_merged*, scripts/world/layer_baker.gd) of a fading building get a copy of
## their materials with that define. The facade details (the Details layer) are baked
## into those chunks too, each with the building cell it hangs on, so they fade with
## their own building (DetailNiveau, merge_with).
##
## Viaducts fade the same way: every column of the Grond layer with a cell high above the
## street (`deck_level`) counts as a small building of its own, so only the part of the deck
## over the vehicle opens up and its shadow stays. A deck fades only when it lies at
## least `deck_clearance` above the vehicle, so a vehicle on the deck keeps the road under it.
## Only the Grond chunks under a fading deck get a fading material, and nothing in them fades
## below `deck_level`: the street and the foundations under buildings stay.
##
## Blocking is tested along the view direction of the camera (also while the follow
## camera swings round for a close-up) from a few points around the vehicle as seen in
## the picture, up to the camera: the Gebouwen cells those lines pass through block it,
## as long as they lie on the camera's side of it (_in_front): a building behind it, which
## you see it standing in front of, stays.

const Iso = preload("res://scripts/camera/iso_camera.gd")

## The follow camera; buildings only fade while it follows.
@export var follow_camera_path := NodePath("../Volgcamera")
## The Gebouwen GridMap whose buildings fade.
@export var buildings_path := NodePath("../Gebouwen")
## The Grond GridMap whose viaducts fade.
@export var ground_path := NodePath("../Grond")
## Lowest level of the Grond layer (metres) that counts as a deck over the street.
@export var deck_level := 3
## How far (metres) a deck has to lie above the vehicle to fade.
@export var deck_clearance := 2.5
## Seconds a building takes to fade out or back in.
@export var fade_time := 0.35
## How far a blocking building fades (1 = gone entirely; lower leaves a faint ghost of
## it, drawn as a screen-door pattern that crawls over the picture as the view moves).
@export_range(0.0, 1.0) var strongest_fade := 1.0
## Half the size (metres) of the square of test points around the vehicle (across the
## picture: the camera's right and up), and the heights (metres above it) of the test
## points: the vehicle and a little room around it should stay in sight.
@export var test_reach := 3.0
## The same for someone on foot (not a Vehicle): only what covers the figure itself fades,
## not a building it stands in front of or beside that only covers the room round it.
@export var walker_reach := 0.5
## Radius (metres) of the view hole round the followed (across the view). Only how big the
## hole is: whether a building gets one depends on the test points (test_reach, walker_reach).
@export var hole_radius := 6.0
@export var test_heights := PackedFloat32Array([0.3, 1.6])
## Highest point (metres above the vehicle) up to which the view lines are followed (and
## never past the camera).
@export var test_height_limit := 90.0

## Size of a map cell in metres (the Gebouwen cell, one texture pixel).
const CELL := 4.0
## Metres between the samples along a view line (less than the 3 m cell height).
const STEP := 1.0
## Looked again at the latest after this many frames, sooner when the followed moved more than
## RETEST_MOVE metres or the camera turned or zoomed (_view_key).
const RETEST_FRAMES := 3
const RETEST_MOVE := 0.25
const LOWEST_CELL := -1000000

var _follow: Node
var _buildings: GridMap
var _ground: GridMap
var _building_of := {}              # Vector2i cell (x, z) -> building index
var _building_cells: Array = []     # building index -> Array[Vector2i] of its cells
var _building_area: Array[Rect2] = []   # building index -> its ground area (x, z metres)
var _chunks: Array = []             # [MeshInstance3D, Rect2 ground area] of the merged buildings
var _chunk_users := {}              # MeshInstance3D -> number of fading buildings on it
var _variants := {}                 # Material or Shader -> its copy with ZWERVR_FADE
var _ground_variants := {}          # the same for the Grond chunks: fading only from deck height
var _is_variant := {}               # the copies themselves (never copied again)
var _with_deck := {}                # building index -> true if a deck fades with it
var _fade := {}                     # building index -> current fade (0..1), only while > 0
var _image: Image
var _texture: ImageTexture
var _origin := Vector2i.ZERO        # cell at the texture's corner
var _top_height := INF               # metres: the highest building or deck top (no line looks above)
var _last_blocking := {}             # what _blocking found the last time it looked
var _last_key := []                  # where the followed and the camera were then (_view_key)
var _frames_since := 0


func _ready() -> void:
	_follow = get_node_or_null(follow_camera_path)
	_buildings = get_node_or_null(buildings_path) as GridMap
	_ground = get_node_or_null(ground_path) as GridMap
	if Engine.is_editor_hint() or _follow == null or _buildings == null or _buildings.get_used_cells().is_empty():
		set_process(false)
		return
	_find_buildings()
	_publish()
	# the chunk meshes come and go (LevelOfDetail: a level in place, the regions of the
	# streamed finest level): look again, the buildings fading now keep their materials
	var detail := get_node_or_null(^"../DetailNiveau")
	if detail and detail.has_signal("chunks_changed"):
		detail.connect("chunks_changed", _chunks_changed)


func _chunks_changed() -> void:
	_find_chunks()
	for index: int in _fade:
		_use_fade_materials(index, true)


## Groups the Gebouwen cells into buildings (touching sides, seen from above) and sets
## up the fade texture over their area.
func _find_buildings() -> void:
	var occupied := {}
	var lowest := Vector2i(1 << 30, 1 << 30)
	var highest := -lowest
	var top_cell := LOWEST_CELL
	for cell in _buildings.get_used_cells():
		top_cell = maxi(top_cell, cell.y)
		var flat := Vector2i(cell.x, cell.z)
		occupied[flat] = true
		lowest = Vector2i(mini(lowest.x, flat.x), mini(lowest.y, flat.y))
		highest = Vector2i(maxi(highest.x, flat.x), maxi(highest.y, flat.y))
	for start in occupied:
		if _building_of.has(start):
			continue
		var index := _building_cells.size()
		var cells: Array[Vector2i] = []
		var open: Array[Vector2i] = [start]
		_building_of[start] = index
		var area := Rect2(Vector2(start) * CELL, Vector2.ONE * CELL)
		while not open.is_empty():
			var cell: Vector2i = open.pop_back()
			cells.append(cell)
			area = area.merge(Rect2(Vector2(cell) * CELL, Vector2.ONE * CELL))
			for side in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var next: Vector2i = cell + side
				if occupied.has(next) and not _building_of.has(next):
					_building_of[next] = index
					open.append(next)
		_building_cells.append(cells)
		_building_area.append(area)
	if _ground:
		for cell in _ground.get_used_cells():
			if cell.y < deck_level:
				continue
			var flat := Vector2i(cell.x, cell.z)
			lowest = Vector2i(mini(lowest.x, flat.x), mini(lowest.y, flat.y))
			highest = Vector2i(maxi(highest.x, flat.x), maxi(highest.y, flat.y))
			if not _building_of.has(flat):
				_building_of[flat] = _building_cells.size()
				_building_cells.append([flat] as Array[Vector2i])
				_building_area.append(Rect2(Vector2(flat) * CELL, Vector2.ONE * CELL))
			_with_deck[_building_of[flat]] = true
	_origin = lowest
	if top_cell > LOWEST_CELL:
		var top_local := _buildings.map_to_local(Vector3i(0, top_cell + 1, 0))
		_top_height = (_buildings.global_transform * top_local).y + _buildings.cell_size.y
	if _ground:
		for cell in _ground.get_used_cells():
			if cell.y >= deck_level:
				_top_height = maxf(_top_height, (_ground.global_transform * _ground.map_to_local(cell)).y + _ground.cell_size.y)
	var size := highest - lowest + Vector2i.ONE
	# floats: the last row holds the centre and radius of the hole in metres
	_image = Image.create(size.x, size.y + 1, false, Image.FORMAT_RGBAF)
	_texture = ImageTexture.create_from_image(_image)


## Buildings and decks on the view lines from around the vehicle to the camera.
func _blocking() -> Dictionary:
	var found := {}
	var vehicle: Node3D = _follow.get("target_node")
	if vehicle == null:
		return found
	var centre: Vector3 = vehicle.call("drawn_position") if vehicle.has_method("drawn_position") else vehicle.global_position
	var to_map := _buildings.global_transform.affine_inverse()
	var to_ground := _ground.global_transform.affine_inverse() if _ground else Transform3D.IDENTITY
	var lowest_deck := centre.y + deck_clearance
	var camera := get_viewport().get_camera_3d()
	var towards_camera: Vector3 = camera.global_basis.z if camera else Iso.DIRECTION
	# across the picture: the camera's own right and up (else the iso camera's)
	var across: Vector3 = camera.global_basis.x if camera else Vector3.RIGHT
	var upwards: Vector3 = camera.global_basis.y if camera else Vector3.UP
	var steps := int(test_height_limit / maxf(towards_camera.y, 0.1) / STEP)
	if camera:
		# no further than the camera: what lies behind it is not in view
		steps = mini(steps, int(centre.distance_to(camera.global_position) / STEP))
	# only what really covers the followed gets a hole (a building it stands in front of, or
	# beside, does not), however big the hole then is
	var reach := test_reach if vehicle is Vehicle else walker_reach
	var flat_towards := Vector2(towards_camera.x, towards_camera.z)
	var corners: Array[Vector2] = []
	for row in 3:
		for column in 3:
			corners.append(Vector2(column - 1, row - 1))
	for corner in corners:
		for height in test_heights:
			# the test points lie round the vehicle as seen in the picture (across the view,
			# not on the ground): only what covers the vehicle and the room round it on the
			# screen blocks it, not the facades beside a narrow street
			var start := centre + Vector3.UP * height + (across * corner.x + upwards * corner.y) * reach
			var last_cell := Vector3i(1 << 30, 0, 0)
			for step in range(1, steps + 1):
				var point := start + towards_camera * (step * STEP)
				if point.y > _top_height:
					break   # above every building and deck: nothing further on can hide it
				var cell := _buildings.local_to_map(to_map * point)
				# the sample itself lies on the camera's side of the followed too: a test point
				# shifted up in the picture starts behind it, inside the building at its back
				# (a cell just looked at is not looked at again: the steps are shorter than a cell)
				if cell != last_cell:
					last_cell = cell
					var ahead := Vector2(point.x - centre.x, point.z - centre.z).dot(flat_towards) > 0.0
					if ahead and _buildings.get_cell_item(cell) != GridMap.INVALID_CELL_ITEM and _in_front(cell, centre, towards_camera):
						found[_building_of[Vector2i(cell.x, cell.z)]] = true
				if _ground and point.y > lowest_deck:
					var ground_cell := _ground.local_to_map(to_ground * point)
					if ground_cell.y >= deck_level and _ground.get_cell_item(ground_cell) != GridMap.INVALID_CELL_ITEM:
						found[_building_of[Vector2i(ground_cell.x, ground_cell.z)]] = true
	return found


## Where the followed and the camera are, coarsely: a test is made again when this changes.
func _view_key() -> Array:
	var followed: Node3D = _follow.get("target_node")
	var camera := get_viewport().get_camera_3d()
	if followed == null or camera == null:
		return []
	var at := followed.global_position
	var view := camera.global_basis.z
	return [Vector3i(roundi(at.x / RETEST_MOVE), roundi(at.y / RETEST_MOVE), roundi(at.z / RETEST_MOVE)),
			Vector3i(roundi(view.x * 100.0), roundi(view.y * 100.0), roundi(view.z * 100.0)),
			roundi(camera.size * 4.0) if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else roundi(camera.fov)]


## True if the middle of building cell `cell` lies on the camera's side of `centre` (seen from
## above): a building behind the one followed never hides it, even when a test point above it
## in the picture lands inside that building.
func _in_front(cell: Vector3i, centre: Vector3, towards_camera: Vector3) -> bool:
	var middle := _buildings.to_global(_buildings.map_to_local(cell))
	var flat_towards := Vector2(towards_camera.x, towards_camera.z)
	return Vector2(middle.x - centre.x, middle.z - centre.z).dot(flat_towards) > 0.0


func _process(delta: float) -> void:
	var following: bool = _follow.call("is_following")
	var blocking := {}
	# a hole only when the camera cannot turn to a view that shows the player (it turns instead):
	# follow_camera.gd view_hole_wanted, from the view table
	if following and _follow.has_method("view_hole_wanted") and not _follow.call("view_hole_wanted"):
		following = false
	if following:
		# looked again only when something changed, or every few frames
		_frames_since += 1
		var key := _view_key()
		if key != _last_key or _frames_since >= RETEST_FRAMES:
			_last_key = key
			_frames_since = 0
			_last_blocking = _blocking()
		blocking = _last_blocking
	var change := delta / maxf(fade_time, 0.01)
	var changed := false
	for index in blocking:
		if not _fade.has(index):
			_fade[index] = 0.0
			_use_fade_materials(index, true)
	for index in _fade.keys():
		var now: float = _fade[index]
		var wanted := strongest_fade if blocking.has(index) else 0.0
		var next := move_toward(now, wanted, change * strongest_fade)
		if next == now:
			continue
		changed = true
		var value := Color(next, 0, 0)
		for cell in _building_cells[index]:
			_image.set_pixelv(cell - _origin, value)
		if next <= 0.0:
			_fade.erase(index)
			_use_fade_materials(index, false)
		else:
			_fade[index] = next
	if not _fade.is_empty():
		_place_hole()
		changed = true
	if changed:
		_texture.update(_image)


## The centre (the middle of the followed, as drawn) and radius of the hole, in the last row.
func _place_hole() -> void:
	var followed: Node3D = _follow.get("target_node")
	if followed == null:
		return
	var centre: Vector3 = followed.call("drawn_position") if followed.has_method("drawn_position") else followed.global_position
	centre += Vector3.UP * 0.9
	_image.set_pixel(0, _image.get_height() - 1, Color(centre.x, centre.y, centre.z, hole_radius))


## Gives the merged chunk meshes on building `index` the materials that can fade (on),
## or their own materials back once no fading building is on them any more (off).
func _use_fade_materials(index: int, on: bool) -> void:
	if _chunks.is_empty() or not is_instance_valid(_chunks[0][0]):
		_find_chunks()
	# a little wider: the facade details of the building stick out into the next chunk
	var area := _building_area[index].grow(2.0)
	for entry in _chunks:
		var chunk: MeshInstance3D = entry[0]
		var is_ground: bool = entry[2]
		if not is_instance_valid(chunk) or not (entry[1] as Rect2).intersects(area) or (is_ground and not _with_deck.has(index)):
			continue
		var users: int = _chunk_users.get(chunk, 0) + (1 if on else -1)
		if users > 0:
			_chunk_users[chunk] = users
		else:
			_chunk_users.erase(chunk)
		if on and users == 1:
			for surface in chunk.mesh.get_surface_count():
				chunk.set_surface_override_material(surface, _variant(chunk.mesh.surface_get_material(surface), is_ground))
		elif not on and users <= 0:
			for surface in chunk.mesh.get_surface_count():
				chunk.set_surface_override_material(surface, null)


## The chunk meshes of the merged Gebouwen and Grond layers (all LOD levels), with their ground area.
func _find_chunks() -> void:
	_chunks.clear()
	_chunk_users.clear()
	for layer in get_parent().get_children():
		var layer_name := str(layer.name)
		var is_ground := _ground != null and layer_name.begins_with(str(_ground.name) + "_merged")
		if not is_ground and not layer_name.begins_with(str(_buildings.name) + "_merged"):
			continue
		# (a streamed level holds its chunks per region: RegionStream)
		for chunk in layer.find_children("*", "MeshInstance3D", true, false):
			# the shadow-only blocks (layer_baker.gd) are never seen, so they don't fade
			if chunk.mesh and chunk.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				var box: AABB = chunk.global_transform * chunk.get_aabb()
				_chunks.append([chunk, Rect2(box.position.x, box.position.z, box.size.x, box.size.z), is_ground])


## Copy of `material` whose shader is compiled with ZWERVR_FADE, made once per material;
## the material itself if its shader has no fading (not a voxel shader). for_ground: it only
## fades from deck height up.
func _variant(material: Material, for_ground := false) -> Material:
	if not material is ShaderMaterial or _is_variant.has(material):
		return material
	var variants := _ground_variants if for_ground else _variants
	if variants.has(material):
		return variants[material]
	var shader: Shader = (material as ShaderMaterial).shader
	var result: Material = material
	if shader and "ZWERVR_FADE" in shader.code:
		if not variants.has(shader):
			var fading := Shader.new()
			var lines := shader.code.split("\n")
			lines.insert(1, "#define ZWERVR_FADE")
			if for_ground:
				lines.insert(2, "#define ZWERVR_FADE_FLOOR %.1f" % float(deck_level))
			fading.code = "\n".join(lines)
			variants[shader] = fading
		result = material.duplicate()
		(result as ShaderMaterial).shader = variants[shader]
		_is_variant[result] = true
	variants[material] = result
	return result


## Hands the fade texture and its area to the voxel shaders.
func _publish() -> void:
	RenderingServer.global_shader_parameter_set("zwervr_fade_map", _texture)
	RenderingServer.global_shader_parameter_set("zwervr_fade_area",
		Vector4(_origin.x * CELL, _origin.y * CELL, _image.get_width() * CELL, _image.get_height() * CELL))


func _exit_tree() -> void:
	if _texture:
		RenderingServer.global_shader_parameter_set("zwervr_fade_area", Vector4.ZERO)
