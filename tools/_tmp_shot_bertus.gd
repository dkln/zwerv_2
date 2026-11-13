extends SceneTree
## Blikken Bertus close up and from the iso angle: his figure, trolley and smoke. args: <outdir>

const Common = preload("res://tools/tool_common.gd")
const Characters = preload("res://scripts/story/characters.gd")
const Conversations = preload("res://scripts/story/conversations.gd")
const CigaretteSmoke = preload("res://scripts/effects/cigarette_smoke.gd")


func _init() -> void:
	Common.watchdog(self, 120)
	var out := "C:/Users/micro/AppData/Local/Temp/claude/2be1af0fdf43bb27/be3092eb-a291-445e-a813-3f407fbd8d7a/scratchpad/cans_task"
	Common.render_size(self, Vector2i(1280, 720))
	await process_frame
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.75)
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.42, 0.44, 0.48)
	get_root().add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	get_root().add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	ground.mesh = plane
	get_root().add_child(ground)
	var person := Node3D.new()
	get_root().add_child(person)
	var look := Characters._look(Conversations.characters().bertus.uiterlijk)
	var figure := TownsfolkFigure.create(look)
	person.add_child(figure)
	var characters: Node3D = Characters.new()
	get_root().add_child(characters)
	characters._trolley_full_of_cans(person)
	var handle := person.to_global(Vector3(0.0, Characters.HANDLE.y, Characters.HANDLE.z))
	figure.aim_arm("left", figure.to_local(handle) - Vector3(0.17, 0, 0))
	figure.aim_arm("right", figure.to_local(handle) + Vector3(0.17, 0, 0))
	var smoke := CigaretteSmoke.new()
	figure.add_child(smoke)
	smoke.position = TownsfolkFigure.cell_point(Vector3(7.0, 28.5, -4.5))
	var cam := Camera3D.new()
	get_root().add_child(cam)
	cam.current = true
	await Common.wait_frames(self, 60)
	smoke.exhale()
	await Common.wait_frames(self, 40)
	await _shot(cam, Vector3(1.3, 1.7, 2.6), Vector3(0.0, 1.1, 0.4), out + "/bertus_dichtbij.png")
	await _shot(cam, Vector3(-1.8, 1.6, 1.6), Vector3(0.0, 1.2, 0.3), out + "/bertus_zij.png")
	cam.fov = 30.0
	await _shot(cam, Vector3(9.0, 11.0, 9.0), Vector3(0.0, 0.8, 0.4), out + "/bertus_iso.png")
	quit()


func _shot(cam: Camera3D, from: Vector3, to: Vector3, path: String) -> void:
	cam.look_at_from_position(from, to)
	await Common.wait_frames(self, 8)
	Common.save_screenshot(self, path)
	print("saved ", path)
