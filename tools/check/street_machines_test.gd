extends SceneTree
## The machines and finds in the town (scenes/stad.tscn): the cash machines and OV machines
## of the node "Straatautomaten" (scripts/world/street_machines.gd) stand on the ground with
## a collider and an [E] spot before them; at a cash machine "[E] Pinnen" opens the cash
## machine's screen; the waste bins (node "Prullenbakken") have cans, "[E] Blikje pakken"
## puts one in the pockets; lost bank cards (node "Pinpassen") lie on the streets and walking
## over one gives a "pinpas" of its own. Prints where the cash machines stand.
## usage: tools/godot.sh --headless --script tools/check/street_machines_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const BankCards = preload("res://scripts/player/bank_cards.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 280)
	PlayerCharacter.choose("martin")
	var scene := Common.instantiate(Common.CITY, false)
	for node_name in ["DetailNiveau", "Rook"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	var player: Node3D = scene.get_node("Speler")
	var machines: Node = scene.get_node_or_null("Straatautomaten")
	var bins: Node = scene.get_node_or_null("Prullenbakken")
	var cards: Node = scene.get_node_or_null("Pinpassen")
	_check(machines != null and bins != null and cards != null, "Straatautomaten, Prullenbakken en Pinpassen in de stad")
	if machines == null or bins == null or cards == null:
		quit(1)
		return
	for frame_index in 600:
		await physics_frame
		if cards._laid and not machines.machines.is_empty():
			break
	await physics_frame
	player.set("has_backpack", true)
	player._sleeping = false
	# the machines
	var cash_machines: Array = machines.cash_machines()
	print("geldautomaten: %d, OV-automaten: %d" % [cash_machines.size(), machines.machines.size() - cash_machines.size()])
	_check(cash_machines.size() >= 15, "geldautomaten door de stad (%d)" % cash_machines.size())
	_check(machines.machines.size() > cash_machines.size(), "OV-automaten bij tramhaltes")
	var floating := 0
	for place: Node3D in machines.machines:
		print("  %s bij (%.0f, %.1f, %.0f)" % [place.name, place.global_position.x, place.global_position.y, place.global_position.z])
		var space := place.get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(place.global_position + Vector3.UP * 0.3, place.global_position + Vector3.DOWN * 0.4, 1)
		query.exclude = [(place.get_child(0).get_node("Botsvorm") as CollisionObject3D).get_rid()]
		if space.intersect_ray(query).is_empty():
			floating += 1
	_check(floating == 0, "alle automaten staan op de grond (%d zweven)" % floating)
	# at a cash machine: [E] Pinnen, the screen opens
	var first: Node3D = cash_machines[0]
	var spot: Node3D = first.get_node("Plek")
	player.teleport(spot.global_position, 0.0)
	for frame_index in 4:
		await physics_frame
	var hud: Node = scene.get_node("HUD")
	var actions: Array = hud._action_prompts.actions() if hud and hud.get("_action_prompts") else []
	_check(actions.has(["E", "Pinnen"]), "bij een geldautomaat: [E] Pinnen (%s)" % str(actions))
	player.give_found_bank_card()
	first.get_node("Plek").go_through()
	for frame_index in 30:
		await process_frame
		if get_root().has_node("Automaatscherm") and get_root().get_node("Automaatscherm").visible:
			break
	var screen: Node = get_root().get_node_or_null("Automaatscherm")
	_check(screen != null and paused, "de geldautomaat opent zijn eigen scherm (het spel staat stil)")
	if screen:
		screen.animate = false
		screen.close()
		for frame_index in 3:
			await process_frame
	paused = false
	# a can from a bin
	print("prullenbakken: %d, met blikje: %d" % [bins.bin_count(), bins.cans_left()])
	_check(bins.bin_count() > 20 and bins.cans_left() > 5, "blikjes in prullenbakken")
	var can_spot: Node3D = bins.a_can_spot()
	var cans_before: int = bins.cans_left()
	can_spot.go_through()
	await process_frame
	_check(int(player.inventory.get("blikje", 0)) == 1 and bins.cans_left() == cans_before - 1, "[E] Blikje pakken: het blikje in je zakken")
	# a lost card
	_check(cards.cards_left() >= 3, "pinpassen op straat (%d)" % cards.cards_left())
	var before := BankCards.cards_of(player).size()
	var card: Node3D = cards._cards[0]
	player.global_position = card.global_position - Vector3.UP * 0.12
	for frame_index in 5:
		await physics_frame
	_check(BankCards.cards_of(player).size() == before + 1, "over een pinpas lopen: een pas met eigen rekening erbij")
	print("straatautomaten ok" if _problems.is_empty() else "straatautomaten problemen: " + str(_problems))
	quit(0 if _problems.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
