extends SubViewportContainer
## An item in a little 3D picture of its own (the reward screen, scripts/ui/reward_screen.gd):
## its voxel model (ItemModels, scripts/world/things/item_models.gd) turning slowly round, a little
## tilted towards you, bobbing; its own world, a transparent background and the plain light
## of the portraits (widgets/player_portrait.gd: a warm key from the front left and above, a
## soft fill, a white rim from behind, a low grey ambient). The camera frames the whole
## model whatever its size. Pixels stay hard (nearest filter), as the rest of the pixel UI.
## It turns while the game is paused (the reward screen pauses it). Graphics
## (docs/CODE_LAGEN.md): a picture on its own, nothing to decide; how it is framed and moves
## comes from item_view_layout.gd.
##   const ItemView = preload("res://scripts/ui/widgets/item_view.gd")
##   var view := ItemView.new()
##   view.show_item("kroket")

const GraphicsSettings = preload("res://scripts/ui/graphics_settings.gd")
const ItemViewLayout = preload("res://scripts/ui/widgets/item_view_layout.gd")
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
	var box := mesh.get_aabb() if mesh else ItemViewLayout.NO_MODEL_BOX
	# turning round its middle
	_model.position = ItemViewLayout.model_position(box)
	_model_size = ItemViewLayout.model_size(box)
	_frame()


## The mesh shown now (for the checks).
func mesh() -> Mesh:
	return _model.mesh


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	_pivot.rotation = ItemViewLayout.turn(_clock)
	_pivot.position.y = ItemViewLayout.bob(_clock, _model_size)


## The camera looking at the middle from the front, the whole model (its diagonal, so every
## turn of it) in view with ROOM round it.
func _frame() -> void:
	if _camera == null:
		return
	_camera.size = ItemViewLayout.camera_size(_model_size, size)
	_camera.position = ItemViewLayout.camera_position(_model_size)
	_camera.near = ItemViewLayout.CAMERA_NEAR
	_camera.far = _model_size * ItemViewLayout.CAMERA_FAR
	_camera.look_at_from_position(_camera.position, Vector3.ZERO, Vector3.UP)
