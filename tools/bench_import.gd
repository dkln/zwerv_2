extends SceneTree
func _init():
	var P = load("res://addons/vox_tiles/vox_parser.gd")
	var M = load("res://addons/vox_tiles/vox_mesher.gd")
	var t := Time.get_ticks_msec()
	var vox = P.load_file("res://assets/tiles/grond/weg/weg_vlak.vox")
	print("parse ", Time.get_ticks_msec() - t, "ms size ", vox.size)
	t = Time.get_ticks_msec()
	var mesh = M.build(vox, 0.125, true)
	print("mesh ", Time.get_ticks_msec() - t, "ms surfaces ", mesh.get_surface_count())
	quit()
