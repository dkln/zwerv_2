extends SceneTree
## Checks the story of the town headless: after waking up the prologue opens in the story box
## (the game paused, the text appearing word by word), Enter goes through it, mission 1 is in
## the tracker, coins lie on the streets, picking them up gives money, and at € 2 earned the
## thought shows and the step is ticked off.
## usage: Godot --headless --script tools/check/story_test.gd [-- <archetype>]

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 300)
	PlayerCharacter.choose(Common.arg(0, "jos"))
	var scene := Common.instantiate(Common.CITY, false)
	for node_name in ["DetailNiveau", "Rook", "Grassprieten"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	var player: Node3D = scene.get_node("Speler")
	var hud: Node = scene.get_node("HUD")
	var loose_change: Node = scene.get_node("Kleingeld")
	await process_frame   # _ready runs once the tree turns (not in _init)
	var box: Control = hud._story_box
	for frame_index in 900:
		await process_frame
		if box.is_showing():
			break
	_check(box.is_showing(), "proloog opent na het wakker worden")
	_check(paused, "spel staat stil tijdens het verhaal")
	await create_timer(0.6).timeout
	var shown: int = box._text.visible_characters
	print("na 0,6 s: %d van %d tekens" % [shown, box._text.text.length()])
	_check(shown > 0 and shown < box._text.text.length(), "tekst verschijnt woord voor woord")
	var pages: int = box._pages.size()
	print("proloog: %d pagina's" % pages)
	for press_index in pages * 2 + 2:
		if not box.is_showing():
			break
		box.handle_input(_accept())
		await Common.wait_frames(self, 2)
	_check(not box.is_showing() and not paused, "verhaal dicht, spel gaat door")
	var quests: Array = hud.quests()
	_check(quests.size() == 1 and String(quests[0].title).contains("kroket"), "missie 1 in de tracker")
	await physics_frame
	var coins: int = loose_change.coins_left()
	print("munten op straat: ", coins)
	_check(coins >= 10, "kleingeld op straat")
	# walk onto coins (put the player on them) until € 2 is earned
	var money_before: float = player.money
	for attempt in 40:
		if player.money_earned >= 2.0 or loose_change.coins_left() == 0:
			break
		var coin: Node3D = loose_change._coins[0].node
		player.global_position = coin.global_position - Vector3.UP * 0.32
		for frame_index in 3:
			await physics_frame
		if box.is_showing():
			break
	print("verdiend: € %.2f" % player.money_earned)
	_check(player.money > money_before, "munten oprapen geeft geld")
	_check(player.money_earned >= 2.0, "twee euro bij elkaar")
	await Common.wait_frames(self, 3)
	_check(box.is_showing() and box._pages[0].kind == "gedachte", "gedachte bij twee euro")
	_check(bool(hud.quests()[0].steps[0].done), "stap afgevinkt")
	print("verhaal ok" if _problems.is_empty() else "verhaal problemen: " + str(_problems))
	quit(0 if _problems.is_empty() else 1)


static func _accept() -> InputEvent:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	return event


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
