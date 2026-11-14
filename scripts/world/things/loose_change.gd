extends "res://scripts/world/things/street_finds.gd"
## Loose change on the streets (the node "Kleingeld" of scenes/stad.tscn): none until the story
## unlocks it ("kleingeld", a later mission), then a very rare find, only a
## coin (`count`: one) of 10, 20 or 50 cents (now and then a euro) in the whole town, on squares and
## pavements well away from where the player starts (between `near` and `reach` metres;
## `near_count` of them closer by, none by default: the first mission pays for its kroket
## with cans, not coins). Where they lie and walking over them: StreetFinds.
## A coin stands on its edge, turns and bobs a little, glinting gold; walking over it (within
## `pick_up_distance`) picks it up: PlayerController.add_money, a chime ("munt") and its
## value rising from where it lay ("+€ 0,50", GameHud.show_floating_number). A pulsing rim
## (QuestOutline) makes them stand out from the street.

const QuestOutline = preload("res://scripts/effects/quest_outline.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const MoneyText = preload("res://scripts/common/money_text.gd")
## Values (euros) and how often each comes.
const VALUES := [0.1, 0.2, 0.5, 1.0]
const VALUE_WEIGHTS := [3.0, 3.0, 3.0, 1.0]
const COIN_GOLD := Color("#E8B83A")
## How high the middle of a coin on its edge stands above the ground.
const LIFT := 0.32
const TURN_SPEED := 2.4
const BOB_SPEED := 2.0
const BOB_HEIGHT := 0.05

static var _coin_mesh: CylinderMesh


func _unlock_name() -> String:
	return "kleingeld"


func _make_find(at: Vector3) -> Node3D:
	var value: float = VALUES[RandomPick.weighted(_random, VALUE_WEIGHTS)]
	var holder := Node3D.new()
	holder.name = "Munt"
	add_child(holder)
	holder.global_position = at + Vector3.UP * LIFT
	var coin := MeshInstance3D.new()
	coin.mesh = _mesh()
	coin.rotation_degrees.x = 90.0   # on its edge
	coin.scale = Vector3.ONE * (1.25 if value >= 1.0 else 1.0)
	holder.add_child(coin)
	QuestOutline.add(coin, 0.03)
	holder.set_meta("value", value)
	holder.set_meta("base", holder.position.y)
	holder.set_meta("phase", _random.randf() * TAU)
	return holder


func _turn_find(coin: Node3D) -> void:
	var phase := float(coin.get_meta("phase", 0.0))
	coin.rotation.y = _clock * TURN_SPEED + phase
	coin.position.y = float(coin.get_meta("base", 0.0)) + sin(_clock * BOB_SPEED + phase) * BOB_HEIGHT


func _take(coin: Node3D) -> bool:
	var value := float(coin.get_meta("value", 0.0))
	_player.call("add_money", value)
	UiSounds.play(self, "munt", -2.0)
	var hud: Node = _player.get("_hud")
	if hud and hud.has_method("show_floating_number"):
		hud.show_floating_number(coin.global_position + Vector3.UP * 0.6, "+" + MoneyText.euros(value), COIN_GOLD)
	return true


static func _mesh() -> CylinderMesh:
	if _coin_mesh == null:
		_coin_mesh = CylinderMesh.new()
		_coin_mesh.top_radius = 0.16
		_coin_mesh.bottom_radius = 0.16
		_coin_mesh.height = 0.045
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
