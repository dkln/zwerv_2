extends Node3D
## What a coin on the streets looks like (graphics; docs/CODE_LAGEN.md; loose_change.gd):
## a gold coin on its edge, glinting, with the pulsing rim of things to pick up
## (QuestOutline), the big one (a euro) a little larger. It shows what loose_change.gd hands
## it (show_turn: how far it has turned and how high it stands) and decides nothing.
##   const LooseChangeView = preload("res://scripts/world/things/loose_change_view.gd")
##   var coin := LooseChangeView.create(false)

const QuestOutline = preload("res://scripts/effects/quest_outline.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const COIN_GOLD := Color("#E8B83A")
## How high the middle of a coin on its edge stands above the ground.
const LIFT := 0.32
## The coin: its radius and thickness (metres), how much larger the big one is, how wide
## its rim is.
const RADIUS := 0.16
const THICKNESS := 0.045
const BIG_SCALE := 1.25
const OUTLINE := 0.03
## How far above a coin its value rises when it is picked up, and how loud the chime is.
const NUMBER_ABOVE := 0.6
const CHIME := "munt"
const CHIME_VOLUME := -2.0

static var _coin_mesh: CylinderMesh


## A coin (the node "Munt", its disc the child "Schijf"); `big`: the larger one.
static func create(big: bool) -> Node3D:
	var view: Node3D = (load("res://scripts/world/things/loose_change_view.gd") as GDScript).new()
	view.name = "Munt"
	var coin := MeshInstance3D.new()
	coin.name = "Schijf"
	coin.mesh = mesh()
	coin.rotation_degrees.x = 90.0   # on its edge
	coin.scale = Vector3.ONE * (BIG_SCALE if big else 1.0)
	view.add_child(coin)
	QuestOutline.add(coin, OUTLINE)
	return view


## The coin turned `angle` radians, its middle `height` metres above its parent.
func show_turn(angle: float, height: float) -> void:
	rotation.y = angle
	position.y = height


## The chime of a coin picked up, played from `from` (a node in the tree).
static func play_chime(from: Node) -> void:
	UiSounds.play(from, CHIME, CHIME_VOLUME)


## Where the value of a coin lying at `at` rises from.
static func number_place(at: Vector3) -> Vector3:
	return at + Vector3.UP * NUMBER_ABOVE


## The mesh of a coin (made once, shared): a flat gold cylinder that glints.
static func mesh() -> CylinderMesh:
	if _coin_mesh == null:
		_coin_mesh = CylinderMesh.new()
		_coin_mesh.top_radius = RADIUS
		_coin_mesh.bottom_radius = RADIUS
		_coin_mesh.height = THICKNESS
		_coin_mesh.radial_segments = 10
		_coin_mesh.rings = 1
		var material := StandardMaterial3D.new()
		material.albedo_color = COIN_GOLD
		material.metallic = 0.8
		material.roughness = 0.35
		material.emission_enabled = true
		material.emission = COIN_GOLD
		material.emission_energy_multiplier = 0.35
		_coin_mesh.material = material
	return _coin_mesh
