extends SubViewportContainer
## A player figure (PlayerModel) in a little 3D picture of its own: its own world, a
## transparent background, plain light: a warm white key from the front left and above that
## casts shadows (on the figure itself and on an invisible floor that shows only the
## shadow), a soft fill, a white rim from behind and a low grey ambient, so the figure has
## light and shade without a tint over its colours.
## `zoom` runs from the whole figure (0) to its face (1, the face height per archetype,
## PlayerModel.face_height); tween it to zoom in. `face_view` is how many metres the face
## framing shows (the HUD portrait a little wider than the creation screen). Pixels are
## kept hard (nearest filter, rendered at PIXEL_SCALE of the size and scaled up), as the
## rest of the pixel UI.

## `townsfolk_look` (a TownsfolkFigure look; empty: the player figure) shows a townsperson
## instead: someone in the street you talk to (the story box), framed the same way.
## play_gesture() makes the figure do its own move (PlayerModel.play_gesture); `gesture_cue`
## fires at the moment for its shout. `silhouette` (a colour with alpha) draws only its outline.

signal gesture_cue

const PlayerModel = preload("res://scripts/player/player_model.gd")

## Share of the size the picture is rendered at (smaller = blockier).
const PIXEL_SCALE := 1.0
## Metres the full framing shows (the tallest figure, Jos with his hat, fits with room).
const FULL_HEIGHT := 2.9

var archetype_id := "jos":
	set(value):
		archetype_id = value
		if _model:
			_model.archetype_id = value
			_model.face_front_now()
			_frame()
## 0 = the whole figure, 1 = the face.
var zoom := 0.0:
	set(value):
		zoom = clampf(value, 0.0, 1.0)
		_frame()
var face_view := 0.85:
	set(value):
		face_view = value
		_frame()
## Degrees a second the figure turns; 0 turns it back to face the front.
var spin := 0.0:
	set(value):
		spin = value
		if _model:
			_model.spin = value
			if value == 0.0:
				_model.face_front()

## With alpha: the figure only as an outline in this colour (PlayerModel.silhouette).
var silhouette := Color(0, 0, 0, 0):
	set(value):
		silhouette = value
		if _model:
			_model.silhouette = value

## How much the figure walks (0 = stands, 1 = walks on the spot); tween it.
var walking := 0.0:
	set(value):
		walking = value
		if _model:
			_model.walking = value

var townsfolk_look := {}:
	set(value):
		townsfolk_look = value
		_show_townsfolk()

var _viewport: SubViewport
var _camera: Camera3D
var _model: Node3D
var _townsfolk: Node3D
var _townsfolk_face := 1.6           # the height of its face in this picture (metres)


func _init() -> void:
	stretch = true
	stretch_shrink = int(round(1.0 / PIXEL_SCALE))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
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
	_viewport.add_child(environment)
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
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.25
	fill.light_color = Color("#D8E0F0")
	fill.rotation_degrees = Vector3(-10.0, 50.0, 0.0)
	_viewport.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 0.55
	rim.rotation_degrees = Vector3(-20.0, 165.0, 0.0)
	_viewport.add_child(rim)
	# an invisible floor that only shows the shadow on it
	var shadow_floor := MeshInstance3D.new()
	shadow_floor.name = "Schaduwvloer"
	var plane := PlaneMesh.new()
	plane.size = Vector2(6.0, 6.0)
	shadow_floor.mesh = plane
	var catcher := StandardMaterial3D.new()
	catcher.shadow_to_opacity = true
	catcher.albedo_color = Color(0.0, 0.0, 0.0, 0.55)
	catcher.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_floor.material_override = catcher
	shadow_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_viewport.add_child(shadow_floor)
	_model = PlayerModel.new()
	_model.archetype_id = archetype_id
	_model.spin = spin
	_model.gesture_cue.connect(func() -> void: gesture_cue.emit())
	_viewport.add_child(_model)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_viewport.add_child(_camera)
	resized.connect(_frame)


func _ready() -> void:
	_frame()


## The townsperson of `townsfolk_look` in place of the player figure (or back to it), as
## big as a player figure is here.
func _show_townsfolk() -> void:
	if _viewport == null:
		return
	if _townsfolk:
		_townsfolk.queue_free()
		_townsfolk = null
	_model.visible = townsfolk_look.is_empty()
	if not townsfolk_look.is_empty():
		_townsfolk = TownsfolkFigure.create(townsfolk_look)
		_viewport.add_child(_townsfolk)
		var bounds := _bounds_of(_townsfolk)
		var grow: float = (float(_model.height()) / maxf(bounds.size.y, 0.1)) * 0.92
		_townsfolk.scale = Vector3.ONE * grow
		# the face a little under the top of the head
		_townsfolk_face = (bounds.end.y - 0.17) * grow
	_frame()


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


## Where the top of the figure's head is in this picture (local pixels), for a speech balloon.
func head_point() -> Vector2:
	if _model == null or _camera == null:
		return Vector2(size.x * 0.5, 0.0)
	var head := Vector3(0.0, _model.height(), 0.0)
	return _camera.unproject_position(head) * float(stretch_shrink)


## The figure does its own move; `gesture_cue` fires at the moment for its shout.
func play_gesture() -> void:
	if _model:
		_model.play_gesture()


## The camera between the whole figure (a little from above) and the face (straight on),
## orthogonal, by `zoom` (eased).
func _frame() -> void:
	if _camera == null:
		return
	var aspect := size.x / size.y if size.y > 0.0 else 1.0
	var full_view := FULL_HEIGHT * 1.08
	if aspect < 0.75:
		full_view *= 0.75 / aspect
	var full_target := Vector3(0.0, FULL_HEIGHT * 0.5, 0.0)
	var full_eye := Vector3(0.0, FULL_HEIGHT * 0.5 + 0.9, 4.0)
	var face := PlayerModel.face_height(archetype_id) if _townsfolk == null else _townsfolk_face
	var face_target := Vector3(0.0, face, 0.0)
	var face_eye := Vector3(0.0, face + 0.3, 3.0)
	var eased := zoom * zoom * (3.0 - 2.0 * zoom)
	_camera.size = lerpf(full_view, face_view, eased)
	var target := full_target.lerp(face_target, eased)
	var eye := full_eye.lerp(face_eye, eased)
	_camera.transform = Transform3D(Basis(), eye).looking_at(target)
