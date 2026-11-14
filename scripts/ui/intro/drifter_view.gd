extends TextureRect
## How what drifts through space behind the story of the intro looks (the graphics layer
## of scripts/ui/intro/drifter.gd, which is the behaviour and has this as its child;
## drifter_rules.gd has the logic, drifter_layout.gd the sizes): a small 3D world of its
## own (a camera, a sun and some ambient light, the character or tractor tumbling in the
## middle) drawn into a picture with a clear background, shown pixel-sharp like the rest.
## It makes the models (a tractor with its wheels and the upside-down protest flag, a
## character flailing as if it swims) and shows what it is handed; it decides nothing.
##   const DrifterView = preload("res://scripts/ui/intro/drifter_view.gd")

const ProtestFlag = preload("res://scripts/vehicles/protest_flag.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")
const GraphicsSettings = preload("res://scripts/ui/graphics_settings.gd")
const DrifterLayout = preload("res://scripts/ui/intro/drifter_layout.gd")

const MODEL_FOLDER := "res://assets/tiles/props/voertuigen/%s.vox"
const SUN_ENERGY := 1.2
const AMBIENT_LIGHT := Color(0.55, 0.6, 0.8)
const AMBIENT_ENERGY := 0.7
## The nearer ones (bigger) a little brighter, the far ones dimmer.
const NEAR_TINT := Color(1, 1, 1)
const FAR_TINT := Color(0.55, 0.6, 0.75)

var _picture: SubViewport
var _spinner: Node3D     # turned as it tumbles
var _model: Node3D       # what drifts: a character or a tractor, swapped per flight


func _init() -> void:
	name = "Trekker"
	_picture = SubViewport.new()
	GraphicsSettings.plain_3d(_picture)
	_picture.name = "Trekkerbeeld"
	_picture.size = Vector2i(DrifterLayout.PICTURE, DrifterLayout.PICTURE)
	_picture.transparent_bg = true
	_picture.own_world_3d = true
	_picture.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_picture)
	var camera := Camera3D.new()
	camera.position = DrifterLayout.CAMERA_AT
	camera.fov = DrifterLayout.CAMERA_FOV
	_picture.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = DrifterLayout.SUN_TURN
	sun.light_energy = SUN_ENERGY
	_picture.add_child(sun)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = AMBIENT_LIGHT
	environment.ambient_light_energy = AMBIENT_ENERGY
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_picture.add_child(world_environment)
	_spinner = Node3D.new()
	_picture.add_child(_spinner)
	texture = _picture.get_texture()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## A tractor of model `model_name` (assets/tiles/props/voertuigen) with its wheels and the
## upside-down protest flag, as scripts/vehicles/tractor.gd puts them, its middle at the
## origin; null if the model is missing.
static func make_tractor(model_name: String) -> Node3D:
	var body_path := MODEL_FOLDER % model_name
	if not ResourceLoader.exists(body_path):
		return null
	var tractor := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = load(body_path)
	body.position = DrifterLayout.TRACTOR_BODY_AT
	tractor.add_child(body)
	for wheel: Array in DrifterLayout.TRACTOR_WHEELS:
		var wheel_path := MODEL_FOLDER % wheel[1]
		if not ResourceLoader.exists(wheel_path):
			continue
		var wheel_instance := MeshInstance3D.new()
		wheel_instance.mesh = load(wheel_path)
		wheel_instance.position = DrifterLayout.wheel_position(wheel)
		tractor.add_child(wheel_instance)
	# the upside-down flag of the protesting farmers on the cab roof, as in the menu
	tractor.add_child(ProtestFlag.new())
	var holder := Node3D.new()
	tractor.position = DrifterLayout.tractor_position()
	holder.add_child(tractor)
	return holder


## One of the characters (`archetype_id`) as the game draws them (PlayerModel), bigger
## (DrifterLayout.CHARACTER_SCALE), flailing its arms and legs as if it swims through space.
static func make_character(archetype_id: String) -> Node3D:
	var holder := Node3D.new()
	var figure := PlayerModel.new()
	figure.archetype_id = archetype_id
	figure.idle = true
	figure.walking = 1.0
	figure.scale = Vector3.ONE * DrifterLayout.CHARACTER_SCALE
	holder.add_child(figure)
	return holder


## Puts the middle of a character (made by make_character, in the tree: its height is
## known once it is built) at the origin, so it tumbles round itself.
static func centre_character(holder: Node3D) -> void:
	var figure := holder.get_child(0) as Node3D
	figure.position = DrifterLayout.character_position(figure.call("height"))


## Puts `drifting` (a tractor or a character) in the picture in place of the one before;
## `centred`: a character, its middle put at the origin once it is there.
func show_model(drifting: Node3D, centred: bool) -> void:
	if _model:
		_model.queue_free()
	_model = drifting
	_spinner.add_child(drifting)
	if centred:
		centre_character(drifting)


## A flight sets off: shown `shown` pixels big, dimmer the further off (`far`: 0 the
## nearest .. 1), lying as `lies` says (euler angles).
func show_setting_off(shown: float, far: float, lies: Vector3) -> void:
	_spinner.basis = Basis.from_euler(lies)
	size = Vector2.ONE * shown
	modulate = NEAR_TINT.lerp(FAR_TINT, far)
	_picture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	visible = true


## On its way: its top left corner at `at`, tumbled on by `turn`.
func show_flying(at: Vector2, turn: Basis) -> void:
	position = at
	_spinner.basis = turn * _spinner.basis


## Across: nothing to see until the next one.
func show_nothing() -> void:
	visible = false
	_picture.render_target_update_mode = SubViewport.UPDATE_DISABLED


## The model that drifts now (null: none yet).
func model() -> Node3D:
	return _model


## How what drifts lies now.
func attitude() -> Basis:
	return _spinner.basis


## Whether the picture is being drawn (only during a flight).
func is_drawing() -> bool:
	return _picture.render_target_update_mode == SubViewport.UPDATE_ALWAYS
