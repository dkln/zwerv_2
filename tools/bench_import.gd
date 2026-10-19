extends SceneTree
## Times parsing and meshing of one .vox tile (import performance check).
## usage: Godot --headless --script tools/bench_import.gd

const Parser = preload("res://addons/vox_tiles/vox_parser.gd")
const Mesher = preload("res://addons/vox_tiles/vox_mesher.gd")
const TILE := "res://assets/tiles/grond/weg/weg_vlak.vox"


func _init() -> void:
	var t := Time.get_ticks_msec()
	var vox = Parser.load_file(TILE)
	print("parse ", Time.get_ticks_msec() - t, "ms size ", vox.size)
	t = Time.get_ticks_msec()
	# 0.125 m voxels, with ambient occlusion
	var mesh = Mesher.build(vox, 0.125, true)
	print("mesh ", Time.get_ticks_msec() - t, "ms surfaces ", mesh.get_surface_count())
	quit()
