extends Node3D
## The street lights at night (made by DayCycle next to itself, "Straatverlichting";
## behaviour, docs/CODE_LAGEN.md): every lamp in the Props layer (items "verlichting/...")
## gets a real light at its head, so the street round it is lit, warm and yellow-white
## (street_lights_view.gd). They follow the dark of DayCycle (`night`): off by day, fading in
## at dusk (from NIGHT_FROM), full at night.
## Only the MAX_LIGHTS lamps nearest the middle of the view (Iso.ground_focus of the camera)
## within REACH m burn as lights (the lamps' own glow is in their voxels and burns everywhere),
## chosen again every PICK_INTERVAL s, so 800 lamps cost no more than a few dozen lights
## (street_lights_rules.gd). Where the light sits per kind of lamp: street_lights_layout.gd.

const Iso = preload("res://scripts/camera/iso_camera.gd")
const StreetLightsRules = preload("res://scripts/world/town/street_lights_rules.gd")
const StreetLightsLayout = preload("res://scripts/world/town/street_lights_layout.gd")
const StreetLightsView = preload("res://scripts/world/town/street_lights_view.gd")

const LAMP_PREFIX := StreetLightsRules.LAMP_PREFIX
const LAMP_HEADS := StreetLightsLayout.LAMP_HEADS
const DEFAULT_RANGE := StreetLightsLayout.DEFAULT_RANGE
const DEFAULT_COLOUR := StreetLightsView.DEFAULT_COLOUR
const ENERGY := StreetLightsView.ENERGY
const ATTENUATION := StreetLightsView.ATTENUATION
const NIGHT_FROM := StreetLightsRules.NIGHT_FROM
const NIGHT_FULL := StreetLightsRules.NIGHT_FULL
const MAX_LIGHTS := StreetLightsRules.MAX_LIGHTS
const REACH := StreetLightsRules.REACH
const PICK_INTERVAL := StreetLightsRules.PICK_INTERVAL

@export var props_path := NodePath("../Props")
@export var camera_path := NodePath("../Camera")

## Its picture: the lights.
var view := StreetLightsView.new()

var _heads: Array = []           # [world position, range, colour] per lamp head
var _day_cycle: Node
var _pick_clock := 0.0


func _ready() -> void:
	_day_cycle = get_parent().get_node_or_null("Dagcyclus")
	var props := get_node_or_null(props_path) as GridMap
	if props and props.mesh_library:
		_find_heads(props)
	view.build(self, StreetLightsRules.light_count(_heads.size()))


## The heads of every lamp in the Props layer, in the world.
func _find_heads(props: GridMap) -> void:
	var library := props.mesh_library
	for cell in props.get_used_cells():
		var item := props.get_cell_item(cell)
		var item_name := library.get_item_name(item)
		if not item_name.begins_with(LAMP_PREFIX):
			continue
		var basis := props.get_cell_item_basis(cell)
		var origin := props.map_to_local(cell)
		var box := AABB() if StreetLightsLayout.is_known(item_name) else library.get_item_mesh(item).get_aabb()
		for head: Vector3 in StreetLightsLayout.heads_of(item_name, box):
			_heads.append([props.global_transform * (origin + basis * head),
					StreetLightsLayout.range_of(item_name), StreetLightsView.colour_of(item_name)])


func lamp_count() -> int:
	return _heads.size()


func lit_count() -> int:
	return view.lit_count()


func _process(delta: float) -> void:
	var night: float = _day_cycle.night if _day_cycle else 0.0
	var strength := StreetLightsRules.strength(night)
	if strength <= 0.0:
		view.hide_all()
		return
	_pick_clock -= delta
	if _pick_clock <= 0.0:
		_pick_clock = PICK_INTERVAL
		_pick_nearest()
	view.show_strength(strength)


## Puts the lights on the heads nearest the middle of the view.
func _pick_nearest() -> void:
	var camera := get_node_or_null(camera_path) as Camera3D
	if camera == null:
		camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	var near := StreetLightsRules.nearest(_heads, Iso.ground_focus(camera))
	for light_index in view.lights.size():
		if light_index >= near.size():
			view.hide_light(light_index)
			continue
		var head: Array = near[light_index]
		view.show_light(light_index, head[0], head[1], head[2])
