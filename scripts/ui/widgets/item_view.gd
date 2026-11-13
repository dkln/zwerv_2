extends SubViewportContainer
## An item in a little 3D picture of its own (the reward screen, scripts/ui/reward_screen.gd):
## its voxel model (ItemModels, scripts/world/things/item_models.gd) turning slowly round, a little
## tilted towards you, bobbing; its own world, a transparent background and the plain light
## of the portraits (widgets/player_portrait.gd: a warm key from the front left and above, a
## soft fill, a white rim from behind, a low grey ambient). The camera frames the whole
## model whatever its size. Pixels stay hard (nearest filter), as the rest of the pixel UI.
## It turns while the game is paused (the reward screen pauses it).
##   var view := ItemView.new()
##   view.show_item("kroket")

## How fast it turns (radians a second), how far it leans towards you (degrees), how much
## room there is round it (share of its size), and its bob (metres per metre of model, per second).
const GraphicsSettings = preload("res://scripts/ui/graphics_settings.gd")
const TURN_SPEED := 0.9
const TILT_DEGREES := 18.0
const ROOM := 1.35
const BOB_SHARE := 0.04
const BOB_SPEED := 2.0
const ItemModels = preload("res://scripts/world/things/item_models.gd")

var _viewport: SubViewport
var _camera: Camera3D
var _pivot: Node3D
var _model: MeshInstance3D
var _clock := 0.0
var _model_size := 1.0


func _init() -> void:
	stretch = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_viewport = SubViewport.new()
	GraphicsSettings.plain_3d(_viewport)
	_viewport.name = "Beeld"
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#8C8C94")
	environment.environment.ambient_light_energy = 0.45
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_viewport.add_child(environment)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.5
	key.light_color = Color("#FFF2E0")
	key.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.3
	fill.light_color = Color("#D8E0F0")
	fill.rotation_degrees = Vector3(-10.0, 50.0, 0.0)
	_viewport.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 0.6
	rim.rotation_degrees = Vector3(-20.0, 165.0, 0.0)
	_viewport.add_child(rim)
	_pivot = Node3D.new()
	_pivot.name = "Draaipunt"
	_viewport.add_child(_pivot)
	_model = MeshInstance3D.new()
	_model.name = "Item"
	_pivot.add_child(_model)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_viewport.add_child(_camera)
	resized.connect(_frame)


## Shows the model of `item_id` (ItemModels.mesh_for), turning from the front.
func show_item(item_id: String) -> void:
	var mesh: Mesh = ItemModels.mesh_for(item_id)
	_model.mesh = mesh
	_clock = 0.0
	var box := mesh.get_aabb() if mesh else AABB(Vector3.ZERO, Vector3.ONE * 0.1)
	# turning round its middle
	_model.position = -box.get_center()
	_model_size = maxf(box.size.length(), 0.01)
	_frame()


## The mesh shown now (for the checks).
func mesh() -> Mesh:
	return _model.mesh


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	_pivot.rotation = Vector3(deg_to_rad(TILT_DEGREES), _clock * TURN_SPEED, 0.0)
	_pivot.position.y = sin(_clock * BOB_SPEED) * _model_size * BOB_SHARE


## The camera looking at the middle from the front, the whole model (its diagonal, so every
## turn of it) in view with ROOM round it.
func _frame() -> void:
	if _camera == null:
		return
	var aspect := size.x / maxf(size.y, 1.0)
	_camera.size = _model_size * ROOM / minf(aspect, 1.0)
	_camera.position = Vector3(0.0, 0.0, _model_size * 4.0)
	_camera.near = 0.01
	_camera.far = _model_size * 10.0
	_camera.look_at_from_position(_camera.position, Vector3.ZERO, Vector3.UP)
