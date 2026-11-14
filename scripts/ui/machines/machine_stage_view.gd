extends SubViewportContainer
## The 3D scene of a machine's close-up (a graphics layer of
## scripts/ui/machines/machine_screen.gd; machine_screen_view.gd has this as its child,
## machine_stage_layout.gd says where everything stands): a world of its own behind
## everything, the wall and the ground (machine_backdrop_view.gd), the machine's model with
## the picture of its screen on it as on a little CRT (machine_display.gdshader) and its
## glow, the plain light of the portraits, you standing at it (PlayerModel) and the camera
## over your shoulder. It shows what it is told: the camera sliding in close
## (play_camera_in), the light of a key pressed (show_press), what slides out of the slot
## (show_slip). It also tells where things are in the window (ray_origin, ray_way,
## window_corners), for whoever handles the mouse. It decides nothing.
##   const MachineStageView = preload("res://scripts/ui/machines/machine_stage_view.gd")

const GraphicsSettings = preload("res://scripts/ui/graphics_settings.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")
const MachineStageLayout = preload("res://scripts/ui/machines/machine_stage_layout.gd")
const MachineBackdropView = preload("res://scripts/ui/machines/machine_backdrop_view.gd")
## The look of the machine's screen: a little CRT (no scanlines).
const DISPLAY_SHADER := preload("res://scripts/ui/machines/machine_display.gdshader")
const NODE_NAME := "Scene"
const HOLDER_NAME := "Automaat"
const MODEL_NAME := "Model"
const DISPLAY_NAME := "Scherm"
const PRESS_LIGHT_NAME := "Toetslicht"
const STAND_IN_NAME := "Speler"
const SKY := Color("#101220")
const AMBIENT := Color("#9A9AA4")
const AMBIENT_ENERGY := 0.4
const KEY_LIGHT := Color("#FFF2E0")
const KEY_LIGHT_ENERGY := 1.3
const FILL_LIGHT := Color("#D8E0F0")
const FILL_LIGHT_ENERGY := 0.3
const GLOW_ENERGY := 0.5
const GLOW_RANGE := 1.4
## The light of a key pressed: how bright, how far, how much of white is in it, and how long
## it shines (seconds).
const PRESS_ENERGY := 1.6
const PRESS_RANGE := 0.35
const PRESS_WHITE := 0.4
const PRESS_SECONDS := 0.18
## What slides out of the slot takes so long (seconds).
const SLIDE_SECONDS := 0.6
## The camera sliding in takes so long (seconds), and how far into the slide you (the
## stand-in) are no longer shown.
const CAMERA_SLIDE_SECONDS := 0.8 * 1.4
const STAND_IN_GONE_AT := 0.45

var _stage: SubViewport
var _camera: Camera3D
var _holder: Node3D
var _machine: MeshInstance3D
var _display: MeshInstance3D
var _press_light: OmniLight3D
var _stand_in: Node3D
var _backdrop: MachineBackdropView
var _came_out: Array[Node3D] = []      # what slid out of the slot (show_slip)
var _parts := {}


func _init() -> void:
	name = NODE_NAME
	stretch = true
	size = MachineStageLayout.VIEW_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Builds the scene (this node in the tree already) for a machine with `parts` (its "mesh"
## and where its parts are: machine_screen_view.gd machine_parts): the wall and ground of
## `backdrop` (of `tiles` when they are there), the model, `picture` (`picture_size` px) on
## its screen glowing in `screen_colour`, the light of its keys in `trim_colour`, and you
## (`stand_in`: {"archetype_id", "figure_scale", "coat"}).
func build(parts: Dictionary, picture: Texture2D, picture_size: Vector2, screen_colour: Color, trim_colour: Color,
		backdrop: String, tiles: Dictionary, stand_in: Dictionary) -> void:
	_parts = parts
	_stage = SubViewport.new()
	GraphicsSettings.plain_3d(_stage)
	_stage.own_world_3d = true
	_stage.msaa_3d = Viewport.MSAA_DISABLED
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_stage)
	_build_light()
	_backdrop = MachineBackdropView.new()
	_stage.add_child(_backdrop)
	_backdrop.build(backdrop, tiles, MachineStageLayout.front_of(parts))
	_build_machine(picture, picture_size, screen_colour, trim_colour)
	_build_stand_in(stand_in)
	_camera = Camera3D.new()
	_camera.fov = MachineStageLayout.CAMERA_FOV
	_stage.add_child(_camera)
	_camera.position = MachineStageLayout.CAMERA_AT
	_camera.look_at_from_position(MachineStageLayout.CAMERA_AT, MachineStageLayout.LOOK_AT, Vector3.UP)
	_camera.make_current()


func _build_light() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = SKY
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = AMBIENT
	environment.environment.ambient_light_energy = AMBIENT_ENERGY
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.light_energy = KEY_LIGHT_ENERGY
	key.light_color = KEY_LIGHT
	key.rotation_degrees = MachineStageLayout.KEY_LIGHT_TURN
	key.shadow_enabled = true
	key.shadow_bias = 0.02
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 8.0
	_stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = FILL_LIGHT_ENERGY
	fill.light_color = FILL_LIGHT
	fill.rotation_degrees = MachineStageLayout.FILL_LIGHT_TURN
	_stage.add_child(fill)


## The machine, its back against the wall, its front at z = 0; its screen: the picture of
## the display, lit by itself, and its glow on you; the light of its keys.
func _build_machine(picture: Texture2D, picture_size: Vector2, screen_colour: Color, trim_colour: Color) -> void:
	_holder = Node3D.new()
	_holder.name = HOLDER_NAME
	_holder.position = MachineStageLayout.holder_at(_parts)
	_stage.add_child(_holder)
	_machine = MeshInstance3D.new()
	_machine.name = MODEL_NAME
	_machine.mesh = _parts.get("mesh")
	_holder.add_child(_machine)
	_display = MeshInstance3D.new()
	_display.name = DISPLAY_NAME
	var quad := QuadMesh.new()
	quad.size = MachineStageLayout.screen_of(_parts).size
	_display.mesh = quad
	# as on a little CRT: bulging, rounded corners, a glow (machine_display.gdshader)
	var display_material := ShaderMaterial.new()
	display_material.shader = DISPLAY_SHADER
	display_material.set_shader_parameter("picture", picture)
	display_material.set_shader_parameter("picture_size", picture_size)
	_display.material_override = display_material
	_display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_display.position = MachineStageLayout.display_at(_parts)
	_holder.add_child(_display)
	var glow := OmniLight3D.new()
	glow.light_color = screen_colour
	glow.light_energy = GLOW_ENERGY
	glow.omni_range = GLOW_RANGE
	glow.position = MachineStageLayout.glow_at(_parts)
	_holder.add_child(glow)
	_press_light = OmniLight3D.new()
	_press_light.name = PRESS_LIGHT_NAME
	_press_light.light_color = trim_colour.lerp(Color.WHITE, PRESS_WHITE)
	_press_light.light_energy = 0.0
	_press_light.omni_range = PRESS_RANGE
	_press_light.position = MachineStageLayout.press_light_at(_parts)
	_holder.add_child(_press_light)


## You, standing at the machine, turned to it (as the lift's stand-in).
func _build_stand_in(stand_in: Dictionary) -> void:
	var model := PlayerModel.new()
	model.name = STAND_IN_NAME
	model.archetype_id = String(stand_in.get("archetype_id", model.archetype_id))
	model.figure_scale = float(stand_in.get("figure_scale", model.figure_scale))
	model.coat = bool(stand_in.get("coat", model.coat))
	model.idle = true
	_stage.add_child(model)
	model.position = MachineStageLayout.STAND_AT
	model.rotation.y = MachineStageLayout.STAND_TURN
	_stand_in = model


# ------------------------------------------------------------------ showing

## A key of the machine pressed: the light at its keypad shines a moment (`animated`: it
## fades; else it is off again at once).
func show_press(animated: bool) -> void:
	if _press_light == null:
		return
	_press_light.light_energy = PRESS_ENERGY
	if animated:
		var fade := _press_light.create_tween()
		fade.tween_property(_press_light, "light_energy", 0.0, PRESS_SECONDS)
	else:
		_press_light.light_energy = 0.0


## The camera from a little back, over your shoulder, in close on the part you use
## (MachineStageLayout.close_up); not `animated`: there at once, you out of the way.
func play_camera_in(animated: bool) -> void:
	if _camera == null:
		return
	var close: Array = MachineStageLayout.close_up(_parts)
	var close_at: Vector3 = close[0]
	var close_look: Vector3 = close[1]
	if not animated:
		_camera.look_at_from_position(close_at, close_look, Vector3.UP)
		if _stand_in:
			_stand_in.visible = false
		return
	_camera.look_at_from_position(MachineStageLayout.CAMERA_FROM, MachineStageLayout.LOOK_AT, Vector3.UP)
	var slide := _camera.create_tween()
	slide.tween_method(func(share: float) -> void:
		_camera.look_at_from_position(MachineStageLayout.CAMERA_FROM.lerp(close_at, share), MachineStageLayout.LOOK_AT.lerp(close_look, share), Vector3.UP)
		# over your shoulder at first; close in, the camera is where you stand: you out of the way
		if _stand_in:
			_stand_in.visible = share < STAND_IN_GONE_AT,
		0.0, 1.0, CAMERA_SLIDE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Something slides out of the slot (a slip in `colour`: the bon, the notes, the card), the
## one before it gone; `animated`: it slides, else it is out at once.
func show_slip(colour: Color, animated: bool) -> void:
	clear_slips()
	if _holder == null:
		return
	var slip := MachineBackdropView.box_of(MachineStageLayout.SLIP_SIZE, MachineStageLayout.slip_from(_parts), colour)
	_holder.add_child(slip)
	_came_out.append(slip)
	var out_z := MachineStageLayout.slip_out_z(_parts)
	if animated:
		var slide := slip.create_tween()
		slide.tween_property(slip, "position:z", out_z, SLIDE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		slip.position.z = out_z


## What slid out of the slot is gone.
func clear_slips() -> void:
	for earlier in _came_out:
		if is_instance_valid(earlier):
			earlier.queue_free()
	_came_out.clear()


## Puts `piece` (a card going into the reader, a can into the hole) in the scene, in the
## space of the machine's model. False (and nothing done) when there is no machine.
func add_piece(piece: Node3D) -> bool:
	if _holder == null:
		return false
	_holder.add_child(piece)
	return true


# ------------------------------------------------------------------ where things are

## The parts of the machine in the scene (see build).
func parts() -> Dictionary:
	return _parts


## The scene (for the checks): the machine's model, the stand-in, what came out, the camera.
func stage_parts() -> Dictionary:
	return {"machine": _machine, "stand_in": _stand_in, "came_out": _came_out, "camera": _camera}


func press_light() -> OmniLight3D:
	return _press_light


func backdrop() -> MachineBackdropView:
	return _backdrop


## Where the ray of the camera through `point` (of the window, design px) starts.
func ray_origin(point: Vector2) -> Vector3:
	return _camera.project_ray_origin(point) if _camera else Vector3.ZERO


## The way that ray goes; zero without a camera.
func ray_way(point: Vector2) -> Vector3:
	return _camera.project_ray_normal(point) if _camera else Vector3.ZERO


## Where the machine's model stands in the scene (the origin of its space).
func model_origin() -> Vector3:
	return _holder.global_position if _holder else Vector3.ZERO


## The z (the scene's metres) of the glass the screen's picture lies on.
func display_z() -> float:
	return _display.global_position.z if _display else 0.0


## How much the glass of the screen bulges (machine_display.gdshader "curvature").
func curvature() -> float:
	return float((_display.material_override as ShaderMaterial).get_shader_parameter("curvature")) if _display else 0.0


## Where the corners of `rect` (on the machine's front, metres) are in the window (design px).
func window_corners(rect: Rect2) -> Array[Vector2]:
	var corners: Array[Vector2] = []
	if _camera == null or _holder == null:
		return corners
	for corner in MachineStageLayout.corners_of(rect, _parts):
		corners.append(_camera.unproject_position(_holder.global_position + corner))
	return corners
