@tool
extends RefCounted
## Builds one MeshLibrary per category from all tile models (.gox, or .vox) in
## assets/tiles/<category>.
## Item IDs stay stable (by name), so existing maps don't break when you add or
## remove tiles. Alias tiles (a .tile.json with "same_as", see tile_metadata.gd) get
## their own item with the mesh of the tile they point to; the slope variants of a
## tile (its "slopes", see slopes.gd) get items of their own as well.

const TileMetadata = preload("res://addons/vox_tiles/importer/tile_metadata.gd")
const Model = preload("res://addons/vox_tiles/importer/voxel_model.gd")
const Atlas = preload("res://addons/vox_tiles/library/atlas.gd")
## Categories whose window tiles get a faked room behind the glass (_set_interior).
const INTERIOR_CATEGORIES := ["gebouwen", "details"]
## Tiles with at least this share of glass (of their surface) stay see-through.
const INTERIOR_MAX_GLASS := 0.3
const Slopes = preload("res://addons/vox_tiles/importer/slopes.gd")
const Progress = preload("res://tools/progress.gd")

const TILE_ROOT := "res://assets/tiles"
const LIB_ROOT := "res://assets/libraries"
const PREVIEW_SIZE := 96
## Rendered previews, kept on disk per tile and import time stamp, so a library that is
## rebuilt (or rebuilt from scratch) gets its previews back without rendering them again.
const PREVIEW_CACHE := "res://.godot/vox_tiles_previews"

## collision: "trimesh" (exact shape), "box" (bounding box; trees (TRUNK_TILES) only their
## trunk, so you can walk under the crown), "blocks" (a few boxes that follow the model
## coarsely: a lamppost a thin post with its head, a tree its trunk and its crown; _block_shapes),
## "none",
## "auto" (buildings: solid blocks get a 4x3x4 m box, hollow/walkable tiles an exact shape)
const CATEGORIES := {
	"grond": {"collision": "trimesh"},
	"gebouwen": {"collision": "auto"},
	"details": {"collision": "none"},
	"props": {"collision": "blocks"},
	# the interiors (scenes/binnen/): floors, walls and furniture, blocks as the props
	"binnen": {"collision": "blocks"},
}


## res://assets/libraries/<category>.res
static func library_path(cat: String) -> String:
	return LIB_ROOT.path_join(cat + ".res")


## Coarse library of a category: <category>_lod.res or <category>_lod2.res.
static func lod_path(cat: String, level := "lod") -> String:
	return LIB_ROOT.path_join(cat + "_" + level + ".res")


## Tiles lower than this (metres) cast no shadow (roads, pavements, grass, ...).
const SHADOW_MIN_HEIGHT := 0.7


## Appends all tile models below dir_path (recursively) to out; skips the coarse
## `<name>.lod.gox` versions. A tile with both a .gox and a .vox counts once, as .gox.
static func list_tiles(dir_path: String, out: PackedStringArray) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			if not f.begins_with("."):
				list_tiles(dir_path.path_join(f), out)
		elif Model.is_model_file(f) and not TileMetadata.is_lod_file(f):
			var path := dir_path.path_join(f)
			if TileMetadata.model_path(path.get_basename()) == path:
				out.append(path)
			else:
				push_warning("Vox Tiles: %s skipped, %s has the same name" % [path, TileMetadata.model_path(path.get_basename())])
		f = d.get_next()
	d.list_dir_end()


## Appends the model paths of all alias tiles below dir_path (recursively) to out:
## `<name>.gox` for every `<name>.tile.json` with a "same_as" and no model of its own.
static func list_aliases(dir_path: String, out: PackedStringArray) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var path := dir_path.path_join(f)
		if d.current_is_dir():
			if not f.begins_with("."):
				list_aliases(path, out)
		elif f.ends_with(".tile.json"):
			var base := path.trim_suffix(".tile.json")
			var model := base + "." + Model.EXTENSIONS[0]
			if not TileMetadata.is_lod_file(model) and TileMetadata.model_path(base) == "" and TileMetadata.read(model).has("same_as"):
				out.append(model)
		f = d.get_next()
	d.list_dir_end()


## Brings the library of a category in line with the tiles on disk: adds new
## tiles, updates changed ones, removes deleted ones, keeps item ids stable
## (registry <category>_ids.json, or a pinned "id" in the tile metadata) and
## rebuilds the coarse libraries.
## changed: Dictionary with paths (res://...gox) that were reimported.
## previews: render palette previews (editor only). force: update every item.
## Returns true if the library was modified and saved.
static func build_category(cat: String, changed: Dictionary, previews: bool, force := false) -> bool:
	var cfg: Dictionary = CATEGORIES[cat]
	var root := TILE_ROOT.path_join(cat)
	var files := PackedStringArray()
	list_tiles(root, files)
	files.sort()
	var progress := Progress.new("bibliotheek %s: tiles laden" % cat, files.size())
	var lib_path := library_path(cat)
	var lib: MeshLibrary = null
	if ResourceLoader.exists(lib_path):
		lib = load(lib_path) as MeshLibrary
	if lib == null:
		lib = MeshLibrary.new()
	var by_name := {}
	var next_id := 0
	for id in lib.get_item_list():
		by_name[lib.get_item_name(id)] = id
		next_id = maxi(next_id, id + 1)
	# fixed name -> id registry: a tile that is briefly missing (e.g. while
	# regenerating) gets the same id when it comes back, so maps stay correct
	var registry := _read_registry(cat)
	for item_name in registry:
		next_id = maxi(next_id, int(registry[item_name]) + 1)
	var registry_changed := false
	var seen := {}
	var dirty := false
	var shapes_outdated := int(lib.get_meta("collision_version", 1)) != COLLISION_VERSION
	var shapes_updated := false
	var need_preview: Array[int] = []
	var stamp_of := {}   # item id -> import time stamp of its source (for the preview cache)
	var sources := {}   # item id -> imported mesh (before the atlas copy)
	# [item name, model path, mesh, own tile?]: every tile, then the slope variants
	# its import made (they have no metadata of their own; ids from the registry)
	var entries := []
	for path in files:
		var key := path.trim_prefix(root + "/").get_basename()
		progress.step(key)
		seen[key] = true
		if not ResourceLoader.exists(path):
			continue # not imported yet
		var mesh := load(path) as Mesh
		if mesh == null:
			continue
		entries.append([key, path, mesh, true])
		var slopes: Dictionary = mesh.get_meta("slopes", {})
		for shape in slopes:
			var slope_key := Slopes.item_name(key, shape)
			if seen.has(slope_key) or TileMetadata.model_path(root.path_join(slope_key)) != "":
				push_warning("Vox Tiles: slope %s of %s already exists as a tile, skipped" % [slope_key, key])
				continue
			seen[slope_key] = true
			entries.append([slope_key, path, slopes[shape], false])
	for entry in entries:
		var key: String = entry[0]
		var path: String = entry[1]
		var mesh: Mesh = entry[2]
		var id: int
		var is_new := not by_name.has(key)
		# an "id" in the tile metadata pins the item id (see tile_metadata.gd)
		var wanted := _wanted_id(path, key, lib, registry) if entry[3] else -1
		if is_new:
			if wanted >= 0:
				id = wanted
			elif registry.has(key) and not lib.get_item_list().has(int(registry[key])):
				id = int(registry[key])
			else:
				id = next_id
			lib.create_item(id)
			lib.set_item_name(id, key)
		else:
			id = by_name[key]
			if wanted >= 0 and wanted != id:
				# move the item; cells in maps that used the old id now show nothing
				lib.remove_item(id)
				id = wanted
				lib.create_item(id)
				lib.set_item_name(id, key)
				is_new = true
				print("Vox Tiles: %s moved to id %d (from metadata)" % [key, id])
			by_name[key] = id
		next_id = maxi(next_id, id + 1)
		if int(registry.get(key, -1)) != id:
			registry[key] = id
			registry_changed = true
		if wanted < 0 and entry[3]:
			TileMetadata.store_id(path, id)
		sources[id] = mesh
		# the library holds atlas copies; a reimport outside the editor shows in the
		# time stamp of the .import file, which is written on every import
		var stamp := FileAccess.get_modified_time(path + ".import")
		mesh.set_meta("source_stamp", stamp)
		stamp_of[id] = stamp
		var current := lib.get_item_mesh(id)
		if force or is_new or changed.has(path) or current == null or current.get_meta("source_stamp", -1) != stamp:
			lib.set_item_shapes(id, _shapes(mesh, cfg.collision, key))
			_set_shadow(lib, id, mesh)
			dirty = true
			need_preview.append(id)
		else:
			if shapes_outdated:
				lib.set_item_shapes(id, _shapes(mesh, cfg.collision, key))
				shapes_updated = true
			if lib.get_item_preview(id) == null:
				need_preview.append(id)
	# alias tiles: an item of their own (name, id) that shares the mesh of their tile
	var aliases := {}   # alias item id -> item id of the tile it points to
	var alias_files := PackedStringArray()
	list_aliases(root, alias_files)
	alias_files.sort()
	for path in alias_files:
		var key := path.trim_prefix(root + "/").get_basename()
		var target := str(TileMetadata.read(path).get("same_as"))
		var target_id := int(registry.get(target, -1))
		if not sources.has(target_id):
			push_warning("Vox Tiles: %s: same_as \"%s\" is not a tile of '%s'" % [TileMetadata.path_for(path), target, cat])
			continue
		seen[key] = true
		var id: int = by_name.get(key, -1)
		var wanted := _wanted_id(path, key, lib, registry)
		if wanted >= 0 and wanted != id:
			if id >= 0:
				lib.remove_item(id)
			id = wanted
		elif id < 0:
			var reserved := int(registry.get(key, -1))
			id = reserved if reserved >= 0 and not lib.get_item_list().has(reserved) else next_id
		if not lib.get_item_list().has(id):
			lib.create_item(id)
			lib.set_item_name(id, key)
		if lib.get_item_mesh(id) != lib.get_item_mesh(target_id):
			dirty = true   # new or changed alias: the coarse libraries need it too
		next_id = maxi(next_id, id + 1)
		if int(registry.get(key, -1)) != id:
			registry[key] = id
			registry_changed = true
		if wanted < 0:
			TileMetadata.store_id(path, id)
		aliases[id] = target_id
	for k in by_name:
		if not seen.has(k):
			lib.remove_item(by_name[k])
			dirty = true
	# the lanes of every item (metadata "traffic", tile_metadata.gd), for the road network
	# (scripts/traffic/road_network.gd); on the coarse libraries as well, without rebuilding them
	var traffic := _traffic_of(root, files, alias_files)
	if traffic != lib.get_meta("traffic", {}):
		lib.set_meta("traffic", traffic)
		dirty = true
		for level in ["lod", "lod2"]:
			if ResourceLoader.exists(lod_path(cat, level)):
				var coarse_library := load(lod_path(cat, level)) as MeshLibrary
				coarse_library.set_meta("traffic", traffic)
				ResourceSaver.save(coarse_library, lod_path(cat, level))
	# their shadow and how they are baked (metadata "bake"), without reimporting them
	var platforms := _metadata_of("platform", files, alias_files, root)
	if platforms != lib.get_meta("platforms", {}):
		lib.set_meta("platforms", platforms)
		dirty = true
	var bake_rules := _metadata_of("bake", files, alias_files, root)
	if bake_rules != lib.get_meta("bake", {}):
		lib.set_meta("bake", bake_rules)
		dirty = true
		for id in lib.get_item_list():
			if sources.has(aliases.get(id, id)):
				_set_shadow(lib, id, sources[aliases.get(id, id)])
	# any change: rebuild the texture atlases (every tile's UVs depend on the packing)
	var missing_lods := not ResourceLoader.exists(lod_path(cat, "lod")) or not ResourceLoader.exists(lod_path(cat, "lod2"))
	if dirty or force or missing_lods:
		var stamps := {}
		for id in sources:
			stamps[id] = sources[id].get_meta("source_stamp")
		progress.stage("textuuratlas maken (%d tiles)" % sources.size())
		var main := Atlas.build(sources)
		_set_interior(main.meshes, cat)
		for id in sources:
			var m: Mesh = main.meshes[id]
			m.set_meta("source_stamp", stamps[id])
			lib.set_item_mesh(id, m)
		for level in ["lod", "lod2"]:
			progress.stage("grove versie %s maken" % level)
			_build_lod(cat, lib, level, sources, aliases)
		dirty = true
	for id in aliases:
		var target_id: int = aliases[id]
		if force or lib.get_item_mesh(id) != lib.get_item_mesh(target_id):
			lib.set_item_mesh(id, lib.get_item_mesh(target_id))
			lib.set_item_shapes(id, _shapes(sources[target_id], cfg.collision, lib.get_item_name(id)))
			_set_shadow(lib, id, sources[target_id])
			dirty = true
		elif shapes_outdated:
			lib.set_item_shapes(id, _shapes(sources[target_id], cfg.collision, lib.get_item_name(id)))
	# previews: from the cache where possible, the rest rendered (editor only) and cached
	var render: Array[int] = []
	for id in need_preview:
		var cached := _cached_preview(cat, lib.get_item_name(id), stamp_of.get(id, 0))
		if cached:
			lib.set_item_preview(id, cached)
			dirty = true
		else:
			render.append(id)
	if previews and render.size() > 0 and Engine.is_editor_hint():
		var meshes: Array[Mesh] = []
		for id in render:
			meshes.append(lib.get_item_mesh(id))
		progress.stage("%d previews maken" % meshes.size())
		var tex: Array = EditorInterface.make_mesh_previews(meshes, PREVIEW_SIZE)
		for i in render.size():
			if i < tex.size() and tex[i] != null:
				lib.set_item_preview(render[i], tex[i])
				_cache_preview(cat, lib.get_item_name(render[i]), stamp_of.get(render[i], 0), tex[i])
		dirty = true
	for id in aliases:
		var preview := lib.get_item_preview(aliases[id])
		if lib.get_item_preview(id) != preview:
			lib.set_item_preview(id, preview)
			dirty = true
	if registry_changed:
		_write_registry(cat, registry)
	if shapes_outdated:
		lib.set_meta("collision_version", COLLISION_VERSION)
		shapes_updated = true
	if dirty or shapes_updated:
		progress.stage("opslaan")
		DirAccess.make_dir_recursive_absolute(LIB_ROOT)
		var err := ResourceSaver.save(lib, lib_path)
		if err != OK:
			push_error("Vox Tiles: could not save %s (%s)" % [lib_path, err])
		else:
			print("Vox Tiles: library '%s' updated (%d items)" % [cat, lib.get_item_list().size()])
	progress.finish()
	return dirty


## Item name -> "traffic" metadata of every tile and alias tile that has it.
## Item name -> the value of metadata `field`, of every tile that has it.
static func _metadata_of(field: String, files: PackedStringArray, alias_files: PackedStringArray, root: String) -> Dictionary:
	var values := {}
	for path in files + alias_files:
		var value = TileMetadata.read(path).get(field)
		if value != null:
			values[path.trim_prefix(root + "/").get_basename()] = value
	return values


static func _traffic_of(root: String, files: PackedStringArray, alias_files: PackedStringArray) -> Dictionary:
	var traffic := {}
	for path in files + alias_files:
		var metadata: Dictionary = TileMetadata.read(path)
		var key := path.trim_prefix(root + "/").get_basename()
		var data = metadata.get("traffic")
		if data is Dictionary:
			traffic[key] = data
		# straight tiles say what drives on the steep ramps made of them (1 m per tile); a
		# gentle ramp starts half a level up, which the road network has no way to say
		var for_ramps = metadata.get("ramp_traffic")
		if for_ramps is Dictionary:
			for shape: String in metadata.get("slopes", []):
				if shape in ["steil", "brug", "brug_rand", "brug_rand_rechts"]:
					traffic[Slopes.item_name(key, shape)] = for_ramps
	return traffic


## File of the cached preview of item `key` of a category for an import time stamp.
static func _preview_file(cat: String, key: String, stamp: int) -> String:
	return PREVIEW_CACHE.path_join(cat).path_join("%s_%d.png" % [key.replace("/", "__"), stamp])


## The cached preview of an item, or null.
static func _cached_preview(cat: String, key: String, stamp: int) -> Texture2D:
	var path := _preview_file(cat, key, stamp)
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null or is_blank(img):
		return null   # an empty render does not count
	return ImageTexture.create_from_image(img)


## True if a rendered preview shows nothing: transparent, or (nearly) every pixel the
## colour of the background (a thin pole still covers more than 0.5 % of the pixels).
static func is_blank(img: Image) -> bool:
	if img.is_invisible():
		return true
	var grey := img.duplicate() as Image
	grey.convert(Image.FORMAT_L8)
	var data := grey.get_data()
	return data.is_empty() or data.count(data[0]) >= data.size() * 0.995


## Stores a rendered preview in the cache, replacing those of older imports of the item.
static func _cache_preview(cat: String, key: String, stamp: int, tex: Texture2D) -> void:
	var dir := PREVIEW_CACHE.path_join(cat)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var prefix := key.replace("/", "__") + "_"
	for f in DirAccess.get_files_at(dir):
		var rest := f.trim_prefix(prefix).trim_suffix(".png")
		if f.begins_with(prefix) and rest.is_valid_int():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(f)))
	var img := tex.get_image()
	if img:
		img.save_png(_preview_file(cat, key, stamp))


## The id from the tile metadata, or -1 if there is none or it is already taken.
static func _wanted_id(path: String, key: String, lib: MeshLibrary, registry: Dictionary) -> int:
	var wanted = TileMetadata.read(path).get("id")
	if wanted == null:
		return -1
	if not (wanted is float or wanted is int) or int(wanted) < 0:
		push_warning("Vox Tiles: %s: \"id\" must be a number >= 0" % TileMetadata.path_for(path))
		return -1
	var id := int(wanted)
	for other in registry:
		if other != key and int(registry[other]) == id:
			push_warning("Vox Tiles: %s wants id %d, but %s already has it" % [key, id, other])
			return -1
	if lib.get_item_list().has(id) and lib.get_item_name(id) != key:
		push_warning("Vox Tiles: %s wants id %d, but %s already has it" % [key, id, lib.get_item_name(id)])
		return -1
	return id


## The name -> id registry of a category.
static func registry_path(cat: String) -> String:
	return LIB_ROOT.path_join(cat + "_ids.json")


static func _read_registry(cat: String) -> Dictionary:
	var f := FileAccess.open(registry_path(cat), FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


static func _write_registry(cat: String, registry: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(LIB_ROOT)
	var names := registry.keys()
	names.sort()
	var ordered := {}
	for n in names:
		ordered[n] = int(registry[n])
	var f := FileAccess.open(registry_path(cat), FileAccess.WRITE)
	f.store_string(JSON.stringify(ordered, "\t"))


## Tiles that collide only with their trunk ("box" mode): the box round everything in their
## lowest TRUNK_HEIGHT metres (the trunk, a planter round it), standing TRUNK_COLLIDER_HEIGHT high.
const TRUNK_TILES := ["bomen/"]
## Raise it when the way colliders are made changes: a library made with an older version gets
## its colliders made again (only those: the meshes, atlases and coarse versions stay).
## 2: trees collide with their trunk only.
const COLLISION_VERSION := 3
const TRUNK_HEIGHT := 1.6
const TRUNK_COLLIDER_HEIGHT := 2.5


## Tile name fragments that get an exact collision shape in "auto" mode.
const EXACT := ["hallen/", "parkeergarage", "overkapping", "pilaren", "zuilengang", "poort", "luchtboog",
	"toren_beton", "radiotoren", "_dak", "penthouse", "gevel_", "top_", "toren_spits", "toren_pinakels", "bg_portiek", "verd_loggia"]


## Low tiles (roads, grass) don't cast shadows: cheaper and avoids shadow acne. The tile's
## metadata "bake" can say otherwise ("shadow").
static func _set_shadow(lib: MeshLibrary, id: int, mesh: Mesh) -> void:
	if not lib.has_method("set_item_mesh_cast_shadow"):
		return
	var height := mesh.get_aabb().size.y
	var mode := RenderingServer.SHADOW_CASTING_SETTING_ON if height >= SHADOW_MIN_HEIGHT else RenderingServer.SHADOW_CASTING_SETTING_OFF
	var rule: Dictionary = lib.get_meta("bake", {}).get(lib.get_item_name(id), {})
	if rule.has("shadow"):
		mode = RenderingServer.SHADOW_CASTING_SETTING_ON if rule.shadow else RenderingServer.SHADOW_CASTING_SETTING_OFF
	lib.set_item_mesh_cast_shadow(id, mode)


## Coarse library with the same item IDs; meshes from the import's "lod"/"lod2" meta
## of `sources` (item id -> imported mesh), with their own texture atlas. Alias items
## (`aliases`: item id -> id of their tile) share the mesh of their tile.
static func _build_lod(cat: String, lib: MeshLibrary, level: String, sources: Dictionary, aliases: Dictionary) -> void:
	var coarse := {}
	for id in sources:
		var m: Mesh = sources[id]
		coarse[id] = m.get_meta(level) if m.has_meta(level) else m
	var packed := Atlas.build(coarse)
	_set_interior(packed.meshes, cat)
	var lod := MeshLibrary.new()
	lod.set_meta("traffic", lib.get_meta("traffic", {}))
	lod.set_meta("bake", lib.get_meta("bake", {}))
	lod.set_meta("platforms", lib.get_meta("platforms", {}))
	for id in lib.get_item_list():
		lod.create_item(id)
		lod.set_item_name(id, lib.get_item_name(id))
		var src: int = aliases.get(id, id)
		if packed.meshes.has(src):
			lod.set_item_mesh(id, packed.meshes[src])
			_set_shadow(lod, id, sources[src])
	DirAccess.make_dir_recursive_absolute(LIB_ROOT)
	ResourceSaver.save(lod, lod_path(cat, level))


## Windows: in these categories, tiles of which less than INTERIOR_MAX_GLASS of the
## surface is glass get a copy of their glass material with `interior` on
## (voxel_glass.gdshader: opaque, with a faked room behind it), so you don't look into the
## hollow building; tiles that are mostly glass (halls, canopies) stay see-through.
static func _set_interior(meshes: Dictionary, cat: String) -> void:
	if not cat in INTERIOR_CATEGORIES:
		return
	var variants := {}   # glass material -> its interior copy
	for key in meshes:
		var m: ArrayMesh = meshes[key]
		if m == null:
			continue
		var glass := 0.0
		var total := 0.0
		for s in m.get_surface_count():
			var area := _area(m, s)
			total += area
			if m.surface_get_name(s) == "glass":
				glass += area
		if glass <= 0.0 or glass >= total * INTERIOR_MAX_GLASS:
			continue
		for s in m.get_surface_count():
			var mat := m.surface_get_material(s) as ShaderMaterial
			if m.surface_get_name(s) != "glass" or mat == null:
				continue
			if not variants.has(mat):
				var copy := mat.duplicate() as ShaderMaterial
				copy.set_meta("base_path", mat.get_meta("base_path", mat.resource_path))
				copy.set_shader_parameter("interior", 1.0)
				variants[mat] = copy
			m.surface_set_material(s, variants[mat])


## Surface area of surface `s` of `mesh` (non-indexed triangles).
static func _area(mesh: ArrayMesh, s: int) -> float:
	var v: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
	var a := 0.0
	for i in range(0, v.size() - 2, 3):
		a += (v[i + 1] - v[i]).cross(v[i + 2] - v[i]).length() * 0.5
	return a


static func _shapes(mesh: Mesh, mode: String, key := "") -> Array:
	if mode == "auto":
		mode = "block"
		for k in EXACT:
			if key.contains(k):
				mode = "trimesh"
				break
	match mode:
		"block":
			var b := BoxShape3D.new()
			b.size = Vector3(4, 3, 4)
			return [b, Transform3D(Basis(), Vector3(0, 1.5, 0))]
		"trimesh":
			var s := mesh.create_trimesh_shape()
			return [s, Transform3D()] if s else []
		"blocks":
			return _block_shapes(mesh)
		"box":
			for trunk_tile in TRUNK_TILES:
				if key.begins_with(trunk_tile):
					return _trunk_shape(mesh)
			var aabb := mesh.get_aabb()
			var b := BoxShape3D.new()
			b.size = aabb.size
			return [b, Transform3D(Basis(), aabb.get_center())]
	return []


## The blocks of a prop (see CATEGORIES): the model cut in layers BLOCK_LAYER m high, in each
## layer the rectangle round what is in it (the triangles of a voxel model are square to the
## axes, so their boxes are exact), and layers whose rectangles differ less than BLOCK_SLACK m
## on every side merged into one box; no more than MOST_BLOCKS boxes (then the two touching
## blocks whose merge adds the least volume go together, so a thin trunk stays thin).
## Coarse, not the exact shape: a post is a thin column, a lamp head a box on it.
const BLOCK_LAYER := 0.25
const BLOCK_SLACK := 0.12
const MOST_BLOCKS := 7
## Smaller than this (metres, across) a block is still this wide, so nothing slips through.
const THINNEST_BLOCK := 0.12


static func _block_shapes(mesh: Mesh) -> Array:
	var aabb := mesh.get_aabb()
	if aabb.size.y <= 0.0:
		return []
	var layer_count := maxi(1, ceili(aabb.size.y / BLOCK_LAYER))
	var lows: Array[Vector2] = []
	var highs: Array[Vector2] = []
	lows.resize(layer_count)
	highs.resize(layer_count)
	lows.fill(Vector2(INF, INF))
	highs.fill(Vector2(-INF, -INF))
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var corner_count := indices.size() if not indices.is_empty() else vertices.size()
		for first in range(0, corner_count - 2, 3):
			var low := Vector3(INF, INF, INF)
			var high := -low
			for corner in 3:
				var vertex := vertices[indices[first + corner] if not indices.is_empty() else first + corner]
				low = low.min(vertex)
				high = high.max(vertex)
			var from_layer := clampi(floori((low.y - aabb.position.y) / BLOCK_LAYER + 0.001), 0, layer_count - 1)
			var to_layer := clampi(ceili((high.y - aabb.position.y) / BLOCK_LAYER - 0.001) - 1, from_layer, layer_count - 1)
			for layer in range(from_layer, to_layer + 1):
				lows[layer] = lows[layer].min(Vector2(low.x, low.z))
				highs[layer] = highs[layer].max(Vector2(high.x, high.z))
	var blocks := _merge_layers(lows, highs, BLOCK_SLACK)
	while blocks.size() > MOST_BLOCKS:
		var best := -1
		var best_cost := INF
		for index in blocks.size() - 1:
			var lower: Array = blocks[index]
			var upper: Array = blocks[index + 1]
			if int(lower[3]) + 1 != int(upper[2]):
				continue   # a gap between them: not merged
			var cost := _block_volume(_merged(lower, upper)) - _block_volume(lower) - _block_volume(upper)
			if cost < best_cost:
				best_cost = cost
				best = index
		if best < 0:
			break
		blocks[best] = _merged(blocks[best], blocks[best + 1])
		blocks.remove_at(best + 1)
	var shapes := []
	for block: Array in blocks:
		var low: Vector2 = block[0]
		var high: Vector2 = block[1]
		var bottom := aabb.position.y + int(block[2]) * BLOCK_LAYER
		var top := minf(aabb.position.y + (int(block[3]) + 1) * BLOCK_LAYER, aabb.end.y)
		var size := Vector3(maxf(high.x - low.x, THINNEST_BLOCK), top - bottom, maxf(high.y - low.y, THINNEST_BLOCK))
		var box := BoxShape3D.new()
		box.size = size
		shapes.append(box)
		shapes.append(Transform3D(Basis(), Vector3((low.x + high.x) * 0.5, (bottom + top) * 0.5, (low.y + high.y) * 0.5)))
	return shapes


static func _merged(lower: Array, upper: Array) -> Array:
	return [(lower[0] as Vector2).min(upper[0]), (lower[1] as Vector2).max(upper[1]), lower[2], upper[3]]


## The volume of a block, in layers times square metres.
static func _block_volume(block: Array) -> float:
	var footprint: Vector2 = (block[1] as Vector2) - (block[0] as Vector2)
	return footprint.x * footprint.y * (int(block[3]) - int(block[2]) + 1)


## Runs of layers (from the bottom) whose rectangles differ less than `slack` on each side,
## each [low, high (the rectangle round them all), first layer, last layer]; empty layers end
## a run and are left out.
static func _merge_layers(lows: Array[Vector2], highs: Array[Vector2], slack: float) -> Array:
	var blocks := []
	for layer in lows.size():
		if lows[layer].x == INF:
			continue
		if not blocks.is_empty():
			var last: Array = blocks[-1]
			var low: Vector2 = last[0]
			var high: Vector2 = last[1]
			var touching := int(last[3]) == layer - 1
			var alike := absf(lows[layer].x - low.x) < slack and absf(lows[layer].y - low.y) < slack \
					and absf(highs[layer].x - high.x) < slack and absf(highs[layer].y - high.y) < slack
			if touching and alike:
				last[0] = low.min(lows[layer])
				last[1] = high.max(highs[layer])
				last[3] = layer
				continue
		blocks.append([lows[layer], highs[layer], layer, layer])
	return blocks


## The collider of a tree: a box round its vertices in the lowest TRUNK_HEIGHT m (the trunk),
## from the ground up TRUNK_COLLIDER_HEIGHT m; the whole bounding box if it has none there.
static func _trunk_shape(mesh: Mesh) -> Array:
	var aabb := mesh.get_aabb()
	var below := aabb.position.y + TRUNK_HEIGHT
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for surface in mesh.get_surface_count():
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			if vertex.y <= below:
				low = Vector2(minf(low.x, vertex.x), minf(low.y, vertex.z))
				high = Vector2(maxf(high.x, vertex.x), maxf(high.y, vertex.z))
	var box := BoxShape3D.new()
	if low.x == INF:
		box.size = aabb.size
		return [box, Transform3D(Basis(), aabb.get_center())]
	box.size = Vector3(high.x - low.x, TRUNK_COLLIDER_HEIGHT, high.y - low.y)
	var centre := Vector3((low.x + high.x) * 0.5, aabb.position.y + TRUNK_COLLIDER_HEIGHT * 0.5, (low.y + high.y) * 0.5)
	return [box, Transform3D(Basis(), centre)]
