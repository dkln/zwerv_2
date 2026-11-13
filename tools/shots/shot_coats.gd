extends SceneTree
## The six zwervers with and without their coat (PlayerModel.coat, _take_off_coat): a row
## each, from the front at an angle and from behind; in a T-shirt the way every game starts,
## in the coat once Ome Wim has given his. Needs a window.
## usage: Godot --script tools/shots/shot_coats.gd -- <output.png>

const Common = preload("res://tools/tool_common.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")
const SIZE := Vector2i(2400, 1000)
const BACKGROUND := Color("#2B3044")
const WHO := ["jos", "martin", "ufo_piloot", "willem", "sjaan", "gerrit"]


func _init() -> void:
	Common.watchdog(self, 120)
	var out := Common.arg(0, "user://jassen.png")
	Common.render_size(self, SIZE)
	var screen := VBoxContainer.new()
	screen.size = SIZE
	screen.add_theme_constant_override("separation", 0)
	get_root().add_child.call_deferred(screen)
	for coat in [false, true]:
		var row := HBoxContainer.new()
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 0)
		screen.add_child(row)
		for who: String in WHO:
			for behind in [false, true]:
				var shown := _show(who, coat, behind)
				row.add_child(shown)
				if not behind:
					var label := Label.new()
					label.text = "%s %s" % [who, "met jas" if coat else "T-shirt"]
					label.add_theme_font_size_override("font_size", 22)
					label.add_theme_color_override("font_color", Color("#FFE9B8"))
					label.position = Vector2(10, 8)
					shown.add_child(label)
	for frame_index in 40:
		await process_frame
	Common.save_screenshot(self, out)
	print("opgeslagen: ", ProjectSettings.globalize_path(out))
	quit()


func _show(who: String, coat: bool, behind: bool) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var view := SubViewport.new()
	view.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	container.add_child(view)
	var model := PlayerModel.new()
	model.archetype_id = who
	model.coat = coat
	model.idle = false
	view.add_child(model)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	var world := WorldEnvironment.new()
	world.environment = environment
	view.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30 + (180 if behind else 0), 0)
	view.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.9
	view.add_child(camera)
	var middle := Vector3(0.0, 1.15, 0.0)
	var direction := Vector3(0.45, 0.2, -1.0 if behind else 1.0).normalized()
	camera.look_at_from_position(middle + direction * 10.0, middle, Vector3.UP)
	return container
