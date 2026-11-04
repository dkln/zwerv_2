extends Node
## See-through buildings (the "Doorkijk" node): while the follow camera (Volgcamera,
## scripts/camera/follow_camera.gd) follows a vehicle, every building that stands between
## the vehicle and the camera fades out, as a whole, and fades back in once the view is
## clear again.
##
## A building is a group of touching cells of the Gebouwen GridMap (seen from above:
## cells that share a side, at any height). The merged chunk meshes hold many buildings,
## so the fading is done in the voxel shaders (addons/vox_tiles/materials/voxel_fade.gdshaderinc):
## a texture with one pixel per 4 x 4 m cell holds how far the building on that cell has
## faded (global shader parameters `zwervr_fade_map` and `zwervr_fade_area`), and the
## shaders leave out that share of its pixels in an even screen-door pattern. Every cell
## of a building gets the same value, so the whole building fades at once (never single
## faces), and its shadow stays.
##
## Shaders that can leave out pixels are much slower on tile-based GPUs (Apple), so the
## voxel shaders only do it when compiled with ZWERVR_FADE: only the merged chunk meshes
## (Gebouwen_merged*, scripts/world/layer_baker.gd) of a fading building get a copy of
## their materials with that define. The facade details (the Details layer) are baked
## into those chunks too, each with the building cell it hangs on, so they fade with
## their own building (DetailNiveau, merge_with).
##
## Blocking is tested along the view direction of the camera (also while the follow
## camera swings round for a close-up) from a few points around the vehicle: the
## Gebouwen cells those lines pass through block it.

const Iso = preload("res://scripts/camera/iso_camera.gd")

## The follow camera; buildings only fade while it follows.
@export var follow_camera_path := NodePath("../Volgcamera")
## The Gebouwen GridMap whose buildings fade.
@export var buildings_path := NodePath("../Gebouwen")
## Seconds a building takes to fade out or back in.
@export var fade_time := 0.35
## How far a blocking building fades (1 = gone entirely; lower leaves a faint ghost of
## it, drawn as a screen-door pattern that crawls over the picture as the view moves).
@export_range(0.0, 1.0) var strongest_fade := 1.0
## Half the size (metres) of the square of test points around the vehicle, and the
## heights (metres above it) of the test points: the vehicle and a little room around it
## should stay in sight.
@export var test_reach := 4.0
@export var test_heights := PackedFloat32Array([0.3, 1.6])
## Highest point (metres above the vehicle) up to which the view lines are followed.
@export var test_height_limit := 90.0

## Size of a map cell in metres (the Gebouwen cell, one texture pixel).
const CELL := 4.0
## Metres between the samples along a view line (less than the 3 m cell height).
const STEP := 1.0

var _follow: Node
var _buildings: GridMap
var _building_of := {}              # Vector2i cell (x, z) -> building index
var _building_cells: Array = []     # building index -> Array[Vector2i] of its cells
var _building_area: Array[Rect2] = []   # building index -> its ground area (x, z metres)
var _chunks: Array = []             # [MeshInstance3D, Rect2 ground area] of the merged buildings
var _chunk_users := {}              # MeshInstance3D -> number of fading buildings on it
var _variants := {}                 # Material or Shader -> its copy with ZWERVR_FADE
var _is_variant := {}               # the copies themselves (never copied again)
var _fade := {}                     # building index -> current fade (0..1), only while > 0
var _image: Image
var _texture: ImageTexture
var _origin := Vector2i.ZERO        # cell at the texture's corner


func _ready() -> void:
	_follow = get_node_or_null(follow_camera_path)
	_buildings = get_node_or_null(buildings_path) as GridMap
	if Engine.is_editor_hint() or _follow == null or _buildings == null or _buildings.get_used_cells().is_empty():
		set_process(false)
		return
	_find_buildings()
	_publish()


## Groups the Gebouwen cells into buildings (touching sides, seen from above) and sets
## up the fade texture over their area.
func _find_buildings() -> void:
	var occupied := {}
	var lowest := Vector2i(1 << 30, 1 << 30)
	var highest := -lowest
	for cell in _buildings.get_used_cells():
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
	_origin = lowest
	var size := highest - lowest + Vector2i.ONE
	_image = Image.create(size.x, size.y, false, Image.FORMAT_R8)
	_texture = ImageTexture.create_from_image(_image)


## Buildings on the view lines from around the vehicle to the camera.
func _blocking() -> Dictionary:
	var found := {}
	var vehicle: Node3D = _follow.get("target_node")
	if vehicle == null:
		return found
	var centre: Vector3 = vehicle.call("drawn_position") if vehicle.has_method("drawn_position") else vehicle.global_position
	var to_map := _buildings.global_transform.affine_inverse()
	var camera := get_viewport().get_camera_3d()
	var towards_camera: Vector3 = camera.global_basis.z if camera else Iso.DIRECTION
	var steps := int(test_height_limit / maxf(towards_camera.y, 0.1) / STEP)
	var corners: Array[Vector2] = []
	for row in 3:
		for column in 3:
			corners.append(Vector2(column - 1, row - 1))
	for corner in corners:
		for height in test_heights:
			var start := centre + Vector3(corner.x * test_reach, height, corner.y * test_reach)
			for step in range(1, steps + 1):
				var point := start + towards_camera * (step * STEP)
				var cell := _buildings.local_to_map(to_map * point)
				if _buildings.get_cell_item(cell) != GridMap.INVALID_CELL_ITEM:
					found[_building_of[Vector2i(cell.x, cell.z)]] = true
	return found


func _process(delta: float) -> void:
	var following: bool = _follow.call("is_following")
	var blocking := _blocking() if following else {}
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
	if changed:
		_texture.update(_image)


## Gives the merged chunk meshes on building `index` the materials that can fade (on),
## or their own materials back once no fading building is on them any more (off).
func _use_fade_materials(index: int, on: bool) -> void:
	if _chunks.is_empty() or not is_instance_valid(_chunks[0][0]):
		_find_chunks()
	# a little wider: the facade details of the building stick out into the next chunk
	var area := _building_area[index].grow(2.0)
	for entry in _chunks:
		var chunk: MeshInstance3D = entry[0]
		if not is_instance_valid(chunk) or not (entry[1] as Rect2).intersects(area):
			continue
		var users: int = _chunk_users.get(chunk, 0) + (1 if on else -1)
		if users > 0:
			_chunk_users[chunk] = users
		else:
			_chunk_users.erase(chunk)
		if on and users == 1:
			for surface in chunk.mesh.get_surface_count():
				chunk.set_surface_override_material(surface, _variant(chunk.mesh.surface_get_material(surface)))
		elif not on and users <= 0:
			for surface in chunk.mesh.get_surface_count():
				chunk.set_surface_override_material(surface, null)


## The chunk meshes of the merged Gebouwen layer (all LOD levels), with their ground area.
func _find_chunks() -> void:
	_chunks.clear()
	_chunk_users.clear()
	for layer in get_parent().get_children():
		if not str(layer.name).begins_with(str(_buildings.name) + "_merged"):
			continue
		for chunk in layer.get_children():
			# the shadow-only blocks (layer_baker.gd) are never seen, so they don't fade
			if chunk is MeshInstance3D and chunk.mesh and chunk.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				var box: AABB = chunk.global_transform * chunk.get_aabb()
				_chunks.append([chunk, Rect2(box.position.x, box.position.z, box.size.x, box.size.z)])


## Copy of `material` whose shader is compiled with ZWERVR_FADE, made once per material;
## the material itself if its shader has no fading (not a voxel shader).
func _variant(material: Material) -> Material:
	if not material is ShaderMaterial or _is_variant.has(material):
		return material
	if _variants.has(material):
		return _variants[material]
	var shader: Shader = (material as ShaderMaterial).shader
	var result: Material = material
	if shader and "ZWERVR_FADE" in shader.code:
		if not _variants.has(shader):
			var fading := Shader.new()
			var lines := shader.code.split("\n")
			lines.insert(1, "#define ZWERVR_FADE")
			fading.code = "\n".join(lines)
			_variants[shader] = fading
		result = material.duplicate()
		(result as ShaderMaterial).shader = _variants[shader]
		_is_variant[result] = true
	_variants[material] = result
	return result


## Hands the fade texture and its area to the voxel shaders.
func _publish() -> void:
	RenderingServer.global_shader_parameter_set("zwervr_fade_map", _texture)
	RenderingServer.global_shader_parameter_set("zwervr_fade_area",
		Vector4(_origin.x * CELL, _origin.y * CELL, _image.get_width() * CELL, _image.get_height() * CELL))


func _exit_tree() -> void:
	if _texture:
		RenderingServer.global_shader_parameter_set("zwervr_fade_area", Vector4.ZERO)
