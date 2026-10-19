@tool
extends RefCounted
## Builds one MeshLibrary per category from all .vox files in assets/tiles/<category>.
## Item IDs stay stable (by name), so existing maps don't break when you add or
## remove tiles. Alias tiles (a .tile.json with "same_as", see tile_metadata.gd) get
## their own item with the mesh of the tile they point to; the slope variants of a
## tile (its "slopes", see slopes.gd) get items of their own as well.

const TileMetadata = preload("res://addons/vox_tiles/tile_metadata.gd")
const Atlas = preload("res://addons/vox_tiles/atlas.gd")
const Slopes = preload("res://addons/vox_tiles/slopes.gd")

const TILE_ROOT := "res://assets/tiles"
const LIB_ROOT := "res://assets/libraries"
const PREVIEW_SIZE := 96
## Rendered previews, kept on disk per tile and import time stamp, so a library that is
## rebuilt (or rebuilt from scratch) gets its previews back without rendering them again.
const PREVIEW_CACHE := "res://.godot/vox_tiles_previews"

## collision: "trimesh" (exact shape), "box" (bounding box), "none",
## "auto" (buildings: solid blocks get a 4x3x4 m box, hollow/walkable tiles an exact shape)
const CATEGORIES := {
	"grond": {"collision": "trimesh"},
	"gebouwen": {"collision": "auto"},
	"details": {"collision": "none"},
	"props": {"collision": "box"},
}


## res://assets/libraries/<category>.res
static func library_path(cat: String) -> String:
	return LIB_ROOT.path_join(cat + ".res")


## Coarse library of a category: <category>_lod.res or <category>_lod2.res.
static func lod_path(cat: String, level := "lod") -> String:
	return LIB_ROOT.path_join(cat + "_" + level + ".res")


## Tiles lower than this (metres) cast no shadow (roads, pavements, grass, ...).
const SHADOW_MIN_HEIGHT := 0.7


## Appends all tile .vox files below dir_path (recursively) to out; skips the
## coarse `<name>.lod.vox` versions.
static func list_vox(dir_path: String, out: PackedStringArray) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			if not f.begins_with("."):
				list_vox(dir_path.path_join(f), out)
		elif f.get_extension() == "vox" and not TileMetadata.is_lod_file(f):
			out.append(dir_path.path_join(f))
		f = d.get_next()
	d.list_dir_end()


## Appends the vox paths of all alias tiles below dir_path (recursively) to out:
## `<name>.vox` for every `<name>.tile.json` with a "same_as" and no `<name>.vox`.
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
			var vox := path.trim_suffix(".tile.json") + ".vox"
			if not TileMetadata.is_lod_file(vox) and not FileAccess.file_exists(vox) and TileMetadata.read(vox).has("same_as"):
				out.append(vox)
		f = d.get_next()
	d.list_dir_end()


## Brings the library of a category in line with the tiles on disk: adds new
## tiles, updates changed ones, removes deleted ones, keeps item ids stable
## (registry <category>_ids.json, or a pinned "id" in the tile metadata) and
## rebuilds the coarse libraries.
## changed: Dictionary with paths (res://...vox) that were reimported.
## previews: render palette previews (editor only). force: update every item.
## Returns true if the library was modified and saved.
static func build_category(cat: String, changed: Dictionary, previews: bool, force := false) -> bool:
	var cfg: Dictionary = CATEGORIES[cat]
	var root := TILE_ROOT.path_join(cat)
	var files := PackedStringArray()
	list_vox(root, files)
	files.sort()
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
	var need_preview: Array[int] = []
	var stamp_of := {}   # item id -> import time stamp of its source (for the preview cache)
	var sources := {}   # item id -> imported mesh (before the atlas copy)
	# [item name, .vox path, mesh, own tile?]: every tile, then the slope variants
	# its import made (they have no metadata of their own; ids from the registry)
	var entries := []
	for path in files:
		var key := path.trim_prefix(root + "/").get_basename()
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
			if seen.has(slope_key) or files.has(root.path_join(slope_key) + ".vox"):
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
		elif lib.get_item_preview(id) == null:
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
	# any change: rebuild the texture atlases (every tile's UVs depend on the packing)
	var missing_lods := not ResourceLoader.exists(lod_path(cat, "lod")) or not ResourceLoader.exists(lod_path(cat, "lod2"))
	if dirty or force or missing_lods:
		var stamps := {}
		for id in sources:
			stamps[id] = sources[id].get_meta("source_stamp")
		var main := Atlas.build(sources)
		for id in sources:
			var m: Mesh = main.meshes[id]
			m.set_meta("source_stamp", stamps[id])
			lib.set_item_mesh(id, m)
		for level in ["lod", "lod2"]:
			_build_lod(cat, lib, level, sources, aliases)
		dirty = true
	for id in aliases:
		var target_id: int = aliases[id]
		if force or lib.get_item_mesh(id) != lib.get_item_mesh(target_id):
			lib.set_item_mesh(id, lib.get_item_mesh(target_id))
			lib.set_item_shapes(id, _shapes(sources[target_id], cfg.collision, lib.get_item_name(id)))
			_set_shadow(lib, id, sources[target_id])
			dirty = true
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
	if dirty:
		DirAccess.make_dir_recursive_absolute(LIB_ROOT)
		var err := ResourceSaver.save(lib, lib_path)
		if err != OK:
			push_error("Vox Tiles: could not save %s (%s)" % [lib_path, err])
		else:
			print("Vox Tiles: library '%s' updated (%d items)" % [cat, lib.get_item_list().size()])
	return dirty


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


## Tile name fragments that get an exact collision shape in "auto" mode.
const EXACT := ["hallen/", "parkeergarage", "overkapping", "pilaren", "zuilengang", "poort", "luchtboog",
	"toren_beton", "radiotoren", "_dak", "penthouse", "gevel_", "top_", "toren_spits", "toren_pinakels", "bg_portiek", "verd_loggia"]


## Low tiles (roads, grass) don't cast shadows: cheaper and avoids shadow acne.
static func _set_shadow(lib: MeshLibrary, id: int, mesh: Mesh) -> void:
	if not lib.has_method("set_item_mesh_cast_shadow"):
		return
	var height := mesh.get_aabb().size.y
	var mode := RenderingServer.SHADOW_CASTING_SETTING_ON if height >= SHADOW_MIN_HEIGHT else RenderingServer.SHADOW_CASTING_SETTING_OFF
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
	var lod := MeshLibrary.new()
	for id in lib.get_item_list():
		lod.create_item(id)
		lod.set_item_name(id, lib.get_item_name(id))
		var src: int = aliases.get(id, id)
		if packed.meshes.has(src):
			lod.set_item_mesh(id, packed.meshes[src])
			_set_shadow(lod, id, sources[src])
	DirAccess.make_dir_recursive_absolute(LIB_ROOT)
	ResourceSaver.save(lod, lod_path(cat, level))


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
		"box":
			var aabb := mesh.get_aabb()
			var b := BoxShape3D.new()
			b.size = aabb.size
			return [b, Transform3D(Basis(), aabb.get_center())]
	return []
