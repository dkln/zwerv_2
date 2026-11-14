extends "res://scripts/world/things/street_finds.gd"
## Loose change on the streets (the node "Kleingeld" of scenes/stad.tscn; behaviour,
## docs/CODE_LAGEN.md): none until the story unlocks it ("kleingeld", a later mission), then
## a very rare find, only a coin (`count`: one) of 10, 20 or 50 cents (now and then a euro)
## in the whole town, on squares and pavements well away from where the player starts
## (between `near` and `reach` metres; `near_count` of them closer by, none by default: the
## first mission pays for its kroket with cans, not coins). Where they lie and walking over
## them: street_finds.gd. A coin stands on its edge, turns and bobs a little, glinting gold
## (loose_change_view.gd); walking over it (within `pick_up_distance`) picks it up:
## PlayerController.add_money, a chime ("munt") and its value rising from where it lay
## ("+€ 0,50", GameHud.show_floating_number). Which coins, how they move:
## loose_change_rules.gd.

const LooseChangeRules = preload("res://scripts/world/things/loose_change_rules.gd")
const LooseChangeView = preload("res://scripts/world/things/loose_change_view.gd")
## Values (euros) and how often each comes (the rules').
const VALUES := LooseChangeRules.VALUES
const VALUE_WEIGHTS := LooseChangeRules.VALUE_WEIGHTS
## How high the middle of a coin on its edge stands above the ground (the view's).
const LIFT := LooseChangeView.LIFT


func _unlock_name() -> String:
	return LooseChangeRules.UNLOCK


func _make_find(at: Vector3) -> Node3D:
	var value := LooseChangeRules.value_of(RandomPick.weighted(_random, VALUE_WEIGHTS))
	var coin := LooseChangeView.create(LooseChangeRules.is_big(value))
	add_child(coin)
	coin.global_position = at + Vector3.UP * LIFT
	coin.set_meta("value", value)
	coin.set_meta("base", coin.position.y)
	coin.set_meta("phase", _random.randf() * TAU)
	return coin


func _turn_find(coin: Node3D) -> void:
	var phase := float(coin.get_meta("phase", 0.0))
	coin.call("show_turn", LooseChangeRules.turn(_clock, phase),
			float(coin.get_meta("base", 0.0)) + LooseChangeRules.bob(_clock, phase))


func _take(coin: Node3D) -> bool:
	var value := float(coin.get_meta("value", 0.0))
	_player.call("add_money", value)
	LooseChangeView.play_chime(self)
	var hud: Node = _player.get("_hud")
	if hud and hud.has_method("show_floating_number"):
		hud.show_floating_number(LooseChangeView.number_place(coin.global_position),
				LooseChangeRules.pickup_text(value), LooseChangeView.COIN_GOLD)
	return true
