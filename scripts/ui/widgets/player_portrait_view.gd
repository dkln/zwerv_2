extends SubViewport
## The picture of a portrait (graphics; docs/CODE_LAGEN.md): a little 3D world of its own
## (the node "Beeld") with a transparent background and plain light: a warm white key from
## the front left and above that casts shadows (on the figure itself and on an invisible
## floor that shows only the shadow), a soft fill, a white rim from behind and a low grey
## ambient, so the figure has light and shade without a tint over its colours. In it the
## player figure (PlayerModel) or a townsperson (TownsfolkFigure, with a mouth and eyelids)
## and the camera. It shows what player_portrait.gd hands it; its sizes come from
## player_portrait_layout.gd.
##   const PlayerPortraitView = preload("res://scripts/ui/widgets/player_portrait_view.gd")

## The player figure reaches the moment for its shout (PlayerModel.gesture_cue).
signal gesture_cue

const GraphicsSettings = preload("res://scripts/ui/graphics_settings.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")
const PlayerPortraitLayout = preload("res://scripts/ui/widgets/player_portrait_layout.gd")
## No silhouette: the figure in its own colours.
const NO_SILHOUETTE := Color(0, 0, 0, 0)

var _camera: Camera3D
var _model: Node3D
var _townsfolk: TownsfolkFigure
var _townsfolk_scale := 1.0
var _townsfolk_face := 1.6           # the height of its face in this picture (metres)


func _init() -> void:
	GraphicsSettings.plain_3d(self)
	name = "Beeld"
	own_world_3d = true
	transparent_bg = true
	msaa_3d = Viewport.MSAA_DISABLED
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_environment())
	_add_lights()
	add_child(_shadow_floor())
	_model = PlayerModel.new()
	_model.gesture_cue.connect(func() -> void: gesture_cue.emit())
	add_child(_model)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(_camera)


## The player figure of archetype `archetype_id`, facing the front.
func show_archetype(archetype_id: String) -> void:
	_model.archetype_id = archetype_id
	_model.face_front_now()


## The player figure as it starts: this archetype, turning `spin` degrees a second.
func show_player(archetype_id: String, spin: float) -> void:
	_model.archetype_id = archetype_id
	_model.spin = spin


## The player figure turns `spin` degrees a second; 0 turns it back to face the front.
func show_spin(spin: float) -> void:
	_model.spin = spin
	if spin == 0.0:
		_model.face_front()


## With alpha: the player figure only as an outline in `colour`.
func show_silhouette(colour: Color) -> void:
	_model.silhouette = colour


## How much the player figure walks (0 = stands, 1 = walks on the spot).
func show_walking(walking: float) -> void:
	_model.walking = walking


## The player figure with or without its coat.
func show_coat(coat: bool) -> void:
	_model.coat = coat


## The player figure does its own move; `gesture_cue` fires at the moment for its shout.
func play_gesture() -> void:
	_model.play_gesture()


## The townsperson of `look` in place of the player figure, as big as a player figure is
## here, with a face; an empty look: the player figure again.
func show_townsfolk(look: Dictionary) -> void:
	if _townsfolk:
		_townsfolk.queue_free()
		_townsfolk = null
	_model.visible = look.is_empty()
	if look.is_empty():
		return
	_townsfolk = TownsfolkFigure.create(look)
	add_child(_townsfolk)
	var bounds := _bounds_of(_townsfolk)
	var grow := PlayerPortraitLayout.townsfolk_grow(float(_model.height()), bounds.size.y)
	_townsfolk.scale = Vector3.ONE * grow
	_townsfolk_scale = grow
	_townsfolk.add_face()
	_townsfolk_face = PlayerPortraitLayout.townsfolk_face(bounds.end.y, grow)


## The townsperson takes the pose of `source` (the one in the world).
func show_pose(source: TownsfolkFigure) -> void:
	_townsfolk.copy_pose_from(source)


## The townsperson scaled `figure_scale` (its size and its breath), moved `moved` from where
## it stands.
func show_stance(figure_scale: Vector3, moved: Transform3D) -> void:
	_townsfolk.transform = Transform3D(Basis.from_scale(figure_scale), Vector3.ZERO) * moved


## The mouth of the townsperson `opening` open (0 shut .. 1 wide).
func show_mouth(opening: float) -> void:
	_townsfolk.set_mouth(opening)


## The eyes of the townsperson shut or open.
func show_blink(shut: bool) -> void:
	_townsfolk.set_blink(shut)


## The camera at `eye` looking at `target`, showing `metres` metres (orthogonal).
func show_frame(metres: float, eye: Vector3, target: Vector3) -> void:
	_camera.size = metres
	_camera.transform = Transform3D(Basis(), eye).looking_at(target)


## Where the top of the player figure's head is in the picture (its own pixels).
func head_point() -> Vector2:
	return _camera.unproject_position(Vector3(0.0, _model.height(), 0.0))


## The player figure (a PlayerModel).
func model() -> Node3D:
	return _model


func camera() -> Camera3D:
	return _camera


## The townsperson shown, or null: the player figure.
func townsfolk() -> TownsfolkFigure:
	return _townsfolk


## How many times its own size the townsperson is here.
func townsfolk_scale() -> float:
	return _townsfolk_scale


## The height of the face of the townsperson in this picture (metres).
func townsfolk_face() -> float:
	return _townsfolk_face


func _environment() -> WorldEnvironment:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#8C8C94")
	environment.environment.ambient_light_energy = 0.35
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# a plain sky only for what metal and glass reflect (the background stays clear)
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#5A6A9A")
	sky_material.sky_horizon_color = Color("#C8C8D0")
	sky_material.ground_bottom_color = Color("#2A2A30")
	sky_material.ground_horizon_color = Color("#8A8A90")
	sky.sky_material = sky_material
	environment.environment.sky = sky
	environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	return environment


func _add_lights() -> void:
	# the key light from the front left and above, casting shadows (the brim on the face,
	# the arms on the body, the figure on the floor)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.5
	key.light_color = Color("#FFF2E0")
	key.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	key.shadow_enabled = true
	key.shadow_bias = 0.02
	key.shadow_normal_bias = 0.6
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 12.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.25
	fill.light_color = Color("#D8E0F0")
	fill.rotation_degrees = Vector3(-10.0, 50.0, 0.0)
	add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 0.55
	rim.rotation_degrees = Vector3(-20.0, 165.0, 0.0)
	add_child(rim)


## An invisible floor that only shows the shadow on it.
func _shadow_floor() -> MeshInstance3D:
	var shadow_floor := MeshInstance3D.new()
	shadow_floor.name = "Schaduwvloer"
	var plane := PlaneMesh.new()
	plane.size = PlayerPortraitLayout.SHADOW_FLOOR
	shadow_floor.mesh = plane
	var catcher := StandardMaterial3D.new()
	catcher.shadow_to_opacity = true
	catcher.albedo_color = Color(0.0, 0.0, 0.0, 0.55)
	catcher.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_floor.material_override = catcher
	shadow_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return shadow_floor


## The box round the meshes under `node`, in its own space (it need not be in the tree).
static func _bounds_of(node: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var box: AABB = _transform_to(node, mesh_instance) * mesh_instance.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


## The transform of `child` in the space of `ancestor` (without the tree).
static func _transform_to(ancestor: Node3D, child: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var node: Node = child
	while node != null and node != ancestor:
		if node is Node3D:
			result = (node as Node3D).transform * result
		node = node.get_parent()
	return result
