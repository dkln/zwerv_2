extends "res://tests/integration/support/town_test.gd"
## The story of the town from its start: after waking up the prologue opens in the story box
## (the game paused, the text appearing word by word), Enter goes through it, mission 1 is in
## the tracker and announced at the top with its jingle, coins lie on the streets, picking
## them up gives money, and at € 2 earned the thought shows and the step is ticked off.
## The town as the game starts it (the player still asleep, the story not begun), so a
## world of its own; the tests follow the story in the order of the file.
##   tests/run_integration_tests.sh story [-- <archetype>]


static func world_options() -> Dictionary:
	return {"wake": false, "character": Common.arg(1, "jos")}


## A press of the space bar, as the story box gets it.
static func _accept() -> InputEvent:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	return event


## Waits for the prologue (no descent from the sky first); returns whether it opened.
func _wait_for_the_prologue() -> bool:
	scene.get_node("Volgcamera")._end_arrival()
	var box: Control = hud._story_box
	for frame_index in 900:
		if box.is_showing():
			return true
		await tree.process_frame
	return box.is_showing()


## Past the prologue, mission 1 running: waits for the prologue and closes it if the
## mission is not in the tracker yet (a test before may have gone through it already).
func _past_the_prologue() -> void:
	if hud.quests().is_empty():
		await _wait_for_the_prologue()
	await close_screens()
	await frames(3)


## After waking up the prologue opens with the game paused, typed out word by word with a
## cursor and the narrator as a silhouette; Enter goes through it and the game goes on; then
## mission 1 is in the tracker (its second step locked) and announced at the top with its jingle.
func test_prologue_opens_and_leads_to_the_first_mission(test) -> void:
	var box: Control = hud._story_box
	test.check(await _wait_for_the_prologue(), "proloog opent na het wakker worden")
	test.check(tree.paused, "spel staat stil tijdens het verhaal")
	await seconds(0.6)
	var typewriter: RefCounted = box._typewriter
	var shown: int = typewriter._word_ends[typewriter._words_shown - 1] if typewriter._words_shown > 0 else 0
	print("na 0,6 s: %d van %d tekens" % [shown, typewriter.text.length()])
	test.check(shown > 0 and shown < typewriter.text.length(), "tekst verschijnt woord voor woord")
	test.check(box._text.text.contains("[bgcolor="), "cursor achter de woorden")
	test.check(box._portrait != null and box._portrait.silhouette.a > 0.0, "verteller als silhouet")
	var pages: int = box._pages.size()
	print("proloog: %d pagina's" % pages)
	for press_index in pages * 2 + 2:
		if not box.is_showing():
			break
		box.handle_input(_accept())
		await frames(2)
	test.check(not box.is_showing() and not tree.paused, "verhaal dicht, spel gaat door")
	var quests: Array = hud.quests()
	test.check(quests.size() == 1 and String(quests[0].title).contains("kroket"), "missie 1 in de tracker")
	test.check(hud.quest_targets().is_empty(), "geldstap zonder plek op de kaart")
	test.check(quests.size() == 1 and bool(quests[0].steps[1].locked), "kroketstap op slot tot de twee euro er zijn")
	test.check(hud.is_showing_notice() and hud._area_heading.text.contains("NIEUWE MISSIE") and hud._area_name.text.contains("kroket"),
		"de nieuwe missie bovenin in beeld (%s: %s)" % [hud._area_heading.text, hud._area_name.text])
	test.check(hud.has_node("MissieDeuntje") or not ResourceLoader.exists(hud.MISSION_JINGLE), "met het missiedeuntje")


## Coins lie on the streets; walking onto them gives money, and at € 2 earned the thought
## shows, the money step is ticked off (50 XP), and the croquette step opens with the snack
## bars on the map and the minimap.
func test_coins_give_money_and_two_euros_finish_the_step(test) -> void:
	await _past_the_prologue()
	var box: Control = hud._story_box
	var loose_change: Node = scene.get_node("Kleingeld")
	await tree.physics_frame
	var coins: int = loose_change.coins_left()
	print("munten op straat: ", coins)
	test.check(coins >= 10, "kleingeld op straat")
	# walk onto coins (put the player on them) until € 2 is earned
	var money_before: float = player.money
	for attempt in 40:
		if player.money_earned >= 2.0 or loose_change.coins_left() == 0:
			break
		var coin: Node3D = loose_change._coins[0].node
		player.global_position = coin.global_position - Vector3.UP * 0.32
		for frame_index in 3:
			await tree.physics_frame
		if box.is_showing():
			break
	print("verdiend: € %.2f" % player.money_earned)
	test.check(player.money > money_before, "munten oprapen geeft geld")
	test.check(player.money_earned >= 2.0, "twee euro bij elkaar")
	await frames(3)
	test.check(box.is_showing() and box._pages[0].kind == "gedachte", "gedachte bij twee euro")
	test.check(bool(hud.quests()[0].steps[0].done), "stap afgevinkt")
	var targets: Array = hud.quest_targets()
	print("snackbars: ", targets)
	test.check(not bool(hud.quests()[0].steps[1].locked) and targets.size() > 0, "kroketstap open, snackbars op de kaart (%d)" % targets.size())
	test.check(hud._minimap_marks.points.size() == targets.size(), "en op het kaartje")
	test.check(is_equal_approx(player.xp, 50.0) and hud._xp_text.text.begins_with("50"), "50 XP voor de eerste stap (%.0f)" % player.xp)
