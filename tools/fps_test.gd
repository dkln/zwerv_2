extends SceneTree
## Meet de framerate van de voorbeeldkaart.
## gebruik: Godot --script tools/fps_test.gd -- <seconden> <zoom|rondleiding> [focus_x focus_z]
var _t := 0.0
var _frames := 0
var _metingen := []
var _duur := 20.0

func _init():
	var a := OS.get_cmdline_user_args()
	_duur = float(a[0]) if a.size() > 0 else 20.0
	var modus: String = a[1] if a.size() > 1 else "rondleiding"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_root().size = Vector2i(1920, 1080)
	var sc: Node = load("res://scenes/wereld.tscn").instantiate()
	if modus != "rondleiding":
		sc.get_node("Rondleiding").set("actief", false)
		var cam: Camera3D = sc.get_node("Camera")
		cam.set("iso_grootte", float(modus))
		if a.size() > 3:
			var focus := Vector3(float(a[2]), 0, float(a[3]))
			cam.position = focus + Vector3(1, 1, 1).normalized() * 300.0
	var vlaggen: String = a[4] if a.size() > 4 else ""
	if "s" in vlaggen:
		sc.get_node("Zon").shadow_enabled = false
		if sc.has_node("Dagcyclus"):
			sc.get_node("Dagcyclus").queue_free()
	for o in [4, 8]:
		if ("o%d" % o) in vlaggen:
			for n in ["Grond", "Gebouwen", "Props", "Details"]:
				sc.get_node(n).cell_octant_size = o
	if "p" in vlaggen:
		sc.get_node("Props").queue_free()
	if "g" in vlaggen:
		sc.get_node("Gebouwen").queue_free()
	if "e" in vlaggen:
		var env: Environment = sc.get_node("Omgeving").environment
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.glow_enabled = false
	if "w" in vlaggen:
		sc.get_node("Omgeving").environment.ssr_enabled = false
	if "2" in vlaggen:
		sc.get_node("Zon").directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if "1" in vlaggen:
		sc.get_node("Zon").directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	if "d" in vlaggen:
		sc.get_node("DetailNiveau").queue_free()
	get_root().add_child(sc)

func _process(delta: float) -> bool:
	if _frames == 0 and _t == 0.0 and delta > 1.0:
		return false   # eerste frame na het laden/samenvoegen telt niet mee
	_t += delta
	if _t < 8.0:
		return false   # opwarmen: shaders compileren, LOD-kopieën maken
	_frames += 1
	_metingen.append(delta)
	if _t > _duur + 8.0:
		_metingen.sort()
		var gem := 0.0
		for d in _metingen: gem += d
		gem /= _metingen.size()
		var p99: float = _metingen[int(_metingen.size() * 0.99)]
		print("FPS gemiddeld %.1f, 1%%-laag %.1f  | draw calls %d, primitieven %d" % [1.0 / gem, 1.0 / p99,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
		quit()
	return false
