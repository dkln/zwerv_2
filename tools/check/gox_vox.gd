extends SceneTree
## Checks tools/voxgen/convert_gox.py: every tile below assets/tiles that has both a .gox and
## a .vox is read both ways by the importer (voxel_model.gd load_file, with its tile metadata)
## and compared: the model size and every voxel with its colour and material must be the
## same. Prints the tiles that differ and a summary; exit code 1 when one does.
##   tools/godot.sh --headless --script tools/check/gox_vox.gd

const Model = preload("res://addons/vox_tiles/importer/voxel_model.gd")
const TileMetadata = preload("res://addons/vox_tiles/importer/tile_metadata.gd")
const TILES := "res://assets/tiles/"

var _checked := 0
var _differ := 0


func _init() -> void:
	_walk(TILES)
	print("gox_vox: %d tiles vergeleken, %d verschillend" % [_checked, _differ])
	quit(1 if _differ > 0 else 0)


func _walk(folder: String) -> void:
	for file_name in DirAccess.get_files_at(folder):
		if file_name.ends_with(".vox") and FileAccess.file_exists(folder + file_name.get_basename() + ".gox"):
			_compare(folder + file_name.get_basename())
	for sub in DirAccess.get_directories_at(folder):
		_walk(folder + sub + "/")


func _compare(base: String) -> void:
	_checked += 1
	var meta: Dictionary = TileMetadata.read(base + ".vox")
	# a palette index in "materials" only means something to the .vox
	var gox_meta := meta.duplicate(true)
	var mats = gox_meta.get("materials", {})
	if mats is Dictionary:
		for key in (mats as Dictionary).keys():
			if str(key).is_valid_int():
				(mats as Dictionary).erase(key)
	var gox = Model.load_file(base + ".gox", gox_meta)
	var vox = Model.load_file(base + ".vox", meta)
	if gox == null or vox == null:
		print("  NIET TE LEZEN: ", base)
		_differ += 1
		return
	var why := ""
	if gox.size != vox.size:
		why = "maat %s tegen %s" % [gox.size, vox.size]
	else:
		var a := _rows(gox)
		var b := _rows(vox)
		if a.size() != b.size():
			why = "%d tegen %d voxels" % [a.size(), b.size()]
		elif a != b:
			for index in a.size():
				if a[index] != b[index]:
					why = "%s tegen %s" % [a[index], b[index]]
					break
	if why != "":
		_differ += 1
		print("  VERSCHIL: %s: %s" % [base, why])


## Every voxel as "x,y,z,rrggbb,material", sorted.
func _rows(model) -> PackedStringArray:
	var rows := PackedStringArray()
	var voxels: PackedByteArray = model.voxels
	for i in range(0, voxels.size(), 4):
		var slot := voxels[i + 3]
		rows.append("%d,%d,%d,%s,%d" % [voxels[i], voxels[i + 1], voxels[i + 2], (model.palette[slot] as Color).to_html(false), model.materials[slot]])
	rows.sort()
	return rows
