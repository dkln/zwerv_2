extends "res://tests/integration/support/town_test.gd"
## The story of the town from its start, with the locks of the game on (the shroud and the
## game menu, "verhaal_sloten"): after waking up the prologue opens in the story box (the game
## paused, the text appearing word by word), Enter goes through it, and mission 1 ("Lege
## maag") is in the tracker and announced at the top with its jingle (standing up and the
## hunger are told in the prologue, not tasks). Then its steps one by
## one: the cans that make the open area grow until a supermarket is
## in it, its deposit machine out of order (the next supermarket opens), the kroket eaten,
## the rucksack (the game menu unlocked) with the empty slot of the stolen ID card. Then
## mission 2: Ome Wim on the Plein, the skill check, the walk through the Centrum, the
## fundraiser in the way and the old coat (the player in it, no longer in a T-shirt).
## The town as the game starts it (the player still asleep, the story not begun), so a
## world of its own; the tests follow the story in the order of the file.
##   tests/run_integration_tests.sh story [-- <archetype>]

const DepositReturn = preload("res://scripts/world/things/deposit_return.gd")
const Conversations = preload("res://scripts/story/conversations.gd")
const MISSION_1 := "missie_1_lege_maag"
const MISSION_2 := "missie_2_bekend_gezicht"


static func world_options() -> Dictionary:
	return {"wake": false, "character": Common.arg(1, "jos"), "verhaal_sloten": true, "tempo": 4.0}


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


## Past the prologue, mission 1 running.
func _past_the_prologue() -> void:
	if hud.quests().is_empty():
		await _wait_for_the_prologue()
	await close_screens()
	await frames(3)


func _story() -> Node:
	return scene.get_node("Verhaal")


func _step_done(step_id: String, mission := MISSION_1) -> bool:
	return _story().step_done(mission, step_id)


## Lets the story look (it looks every half second) and closes what it showed.
func _let_the_story_look() -> void:
	await seconds(0.7)
	await close_screens()
	await frames(2)


## After waking up the prologue opens with the game paused, typed out word by word with a
## cursor and the narrator as a silhouette; Enter goes through it and the game goes on; then
## mission 1 is in the tracker (its later steps locked) and announced at the top with its
## jingle. The game menu does not open yet.
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
	test.check(quests.size() == 1 and String(quests[0].title) == "Lege maag", "missie 1 in de tracker")
	test.check(quests.size() == 1 and bool(quests[0].steps[1].locked), "de volgende stappen op slot")
	test.check(hud.is_showing_notice() and hud._area_heading.text.contains("NIEUWE MISSIE") and hud._area_name.text.contains("Lege maag"),
		"de nieuwe missie bovenin in beeld (%s: %s)" % [hud._area_heading.text, hud._area_name.text])
	test.check(hud.has_node("MissieDeuntje") or not ResourceLoader.exists(hud.MISSION_JINGLE), "met het missiedeuntje")
	var game_menu: Node = hud.get_node("Spelmenu")
	game_menu.open("inventaris")
	test.check(not game_menu.is_open(), "het spelmenu (Tab) gaat nog niet open")
	test.check(not player.call("wears_coat"), "de speler begint zonder jas, in een T-shirt")
	var hunger: Vector2 = player.stat("honger")
	print("honger: %.0f van %.0f" % [hunger.x, hunger.y])
	test.check(hunger.x < 80.0, "de honger knaagt al (%.0f)" % hunger.x)


## Standing up and the hunger are told in the prologue, not tasks: mission 1 starts with the
## cans. Only the area round the start is open: walking out of it
## does not go, and it is not on the map.
func test_the_prologue_tells_of_standing_up_and_the_hunger(test) -> void:
	await _past_the_prologue()
	var story := _story()
	var told := " ".join(story.prologue_pages().map(func(page: Dictionary) -> String: return str(page.text)))
	test.check(told.contains("overeind") and told.contains("maag") and told.contains("blikjes"), "de proloog vertelt het opstaan, de honger en de blikjes")
	var first_step: Dictionary = (hud.quests()[0].steps as Array)[0]
	test.check(String(first_step.text).contains("blikjes"), "de eerste taak: blikjes zoeken (%s)" % first_step.text)
	var start: Vector2 = story.shroud.start_centre
	var far := start + Vector2(story.shroud.start_radius + 30.0, 0.0)
	test.check(story.shroud.is_open(start.x, start.y) and not story.may_walk(far.x, far.y), "alleen rond de start open")
	test.check(hud.is_shrouded(far), "daarbuiten niet op de kaart")
	var coins: Node = scene.get_node_or_null("Kleingeld")
	var cards: Node = scene.get_node_or_null("Pinpassen")
	test.check(coins != null and not coins._laid and coins.coins_left() == 0, "aan het begin geen kleingeld op straat")
	test.check(cards != null and not cards._laid and cards.cards_left() == 0, "en geen pinpassen")


## Cans: six for the step, four in the bins on the square by the start (none in the others
## round it, none coming), marked; at the fourth a thought about the last two, behind the
## gates of the station (each in a bin of its own on a platform), and outside the minimap points
## to the entrance of Centraal (also after going in and out, and after a restore); inside, the
## cans lie there, reachable from the platform, and are marked themselves, each mark gone once its
## can is taken. The area stays as it is until the deposit step opens it up to the supermarket.
func test_four_cans_outside_and_the_last_two_behind_the_gates(test) -> void:
	await _past_the_prologue()
	var story := _story()
	await close_screens()
	var targets: Array = hud.quest_targets()
	print("prullenbakken met een blikje: ", targets)
	test.check(targets.size() == 4 and targets.all(func(spot: Vector2) -> bool: return story.shroud.is_open(spot.x, spot.y)),
		"vier prullenbakken met een blikje in het open gebied (%d)" % targets.size())
	var bins: Node = scene.get_node("Prullenbakken")
	# on the square or by the tram stop before Centraal, never behind the station hall (its
	# front at z 69 * 4, tools/build/city/east.gd): no building between the start and a bin
	var buildings := scene.get_node("Gebouwen") as GridMap
	test.check(targets.all(func(spot: Vector2) -> bool: return spot.y < 69 * 4.0 and bins.in_sight_of(buildings, story.shroud.start_centre, spot)),
		"alle vier op het plein voor Centraal, niet erachter")
	var near: Array = bins.can_spots(story.shroud.start_centre, 20).filter(func(spot: Vector2) -> bool: return spot.distance_to(story.shroud.start_centre) < 150.0)
	test.check(near.size() == 4, "verder geen blikjes rond de start (%d)" % near.size())
	test.check(bins.keep_empty_radius > 1000.0, "er komen er geen bij")
	var radius_before: float = story.shroud.start_radius
	# one taken from its bin: that bin is no longer marked
	var taken := -1
	for index in bins._bins.size():
		if bins._bins[index].spot != null and bins._bins[index].free:
			var at: Vector3 = bins._bins[index].ground
			if targets.any(func(spot: Vector2) -> bool: return spot.distance_to(Vector2(at.x, at.z)) < 0.5):
				taken = index
				break
	test.check(taken != -1, "een gemarkeerde prullenbak met een blikje")
	if taken != -1:
		var at: Vector3 = bins._bins[taken].ground
		bins._take(taken)
		await frames(2)
		var shown: Dictionary = hud._reward_screen.current_page() if hud.is_showing_reward() else {}
		test.check(String(shown.get("item", "")) == "blikje" and int(player.inventory.get("blikje", 0)) == 1,
			"het eerste blikje: het beloningsscherm (%s)" % shown)
		await close_screens()
		targets = hud.quest_targets()
		test.check(targets.size() == 3 and not targets.any(func(spot: Vector2) -> bool: return spot.distance_to(Vector2(at.x, at.z)) < 0.5),
			"het opgepakte blikje staat niet meer op de kaart (%d)" % targets.size())
	player.add_item("blikje", 4 - player.inventory.get("blikje", 0), true)
	await frames(2)
	test.check(hud.is_showing_story() and hud._story_box._pages.any(func(page: Dictionary) -> bool: return String(page.text).contains("poortjes")),
		"bij het vierde: de gedachte over de poortjes")
	await close_screens()
	test.check(is_equal_approx(story.shroud.start_radius, radius_before), "het gebied groeit niet met de blikjes")
	targets = hud.quest_targets()
	var entrance: Vector2 = story._station_entrance()
	print("ingang van Centraal: ", entrance, " (plek centraal: ", story._place("centraal"), ")")
	test.check(targets.size() == 1 and (targets[0] as Vector2).distance_to(entrance) < 1.0 and entrance.distance_to(story._place("centraal")) > 5.0,
		"buiten wijst het kaartje naar de ingang van Centraal")
	story.restore(story.snapshot())
	await frames(2)
	targets = hud.quest_targets()
	test.check(targets.size() == 1 and (targets[0] as Vector2).distance_to(entrance) < 1.0, "ook na opslaan en terugzetten")
	test.check(story.station_cans_wanted() == 2, "het verhaal wil nog twee blikjes in het station (%d)" % story.station_cans_wanted())
	var interiors: Node = scene.get_node("Binnenruimtes")
	var station: Node = interiors.interior_of("centraal")
	var ways: Array = interiors.ways_in().filter(func(way_in: Dictionary) -> bool: return str(way_in.get("kind", "")) == "centraal")
	test.check(station != null and not ways.is_empty(), "het station en zijn ingang")
	if station == null or ways.is_empty():
		return
	# no jumping yet: that comes with the station
	test.check(not story.is_unlocked("springen") and not player.jumping_open(), "springen kan nog niet")
	player._start_jump()
	test.check(not player._airborne, "spatie: geen sprong")
	await interiors.enter(ways[0])
	await seconds(0.7)
	var told: Array = hud._story_box._pages if hud.is_showing_story() else []
	print("binnen in het station: ", told.map(func(page: Dictionary) -> String: return str(page.get("kind", ""))))
	test.check(told.size() == 3 and told.all(func(page: Dictionary) -> bool: return str(page.get("kind", "")) == "verhaal")
			and String(told[0].text).contains("perrons") and told.any(func(page: Dictionary) -> bool: return String(page.text).contains("conducteur")),
		"binnen vertelt de verteller van de twee blikjes op de perrons en de conducteurs")
	test.check(story.is_unlocked("springen") and player.jumping_open(), "en nu kun je springen")
	await close_screens()
	await seconds(0.7)
	var cans: Dictionary = station.mission_cans()
	var first: Node3D = cans.get("perron_1")
	var second: Node3D = cans.get("perron_2")
	print("blikjes op de perrons: ", first.position if first else null, ", ", second.position if second else null)
	test.check(interiors.is_inside() and first != null and second != null, "binnen: twee blikjes in het station")
	if first == null or second == null:
		return
	test.check([first, second].all(func(can: Node3D) -> bool: return can.position.z > 0.0 and is_zero_approx(can.position.y)),
		"allebei op een perron, voorbij de poortjes")
	test.check(station._platform_at(first.position) != station._platform_at(second.position) or first.position.distance_to(second.position) >= station.MISSION_CANS_APART,
		"in twee verschillende prullenbakken, een eind uit elkaar")
	targets = hud.quest_targets()
	test.check(targets.size() == 2 and [first, second].all(func(can: Node3D) -> bool:
			return targets.any(func(spot: Vector2) -> bool: return spot.distance_to(Vector2(can.global_position.x, can.global_position.z)) < 0.5)),
		"binnen wijst het kaartje de twee blikjes aan (%d)" % targets.size())
	test.check(await _reach_and_take(station, first), "het eerste blikje te pakken vanaf het perron ([E] Blikje pakken)")
	await frames(2)
	test.check(not hud.is_showing_reward() and hud.rewards_waiting().is_empty() and int(player.inventory.get("blikje", 0)) == 5,
		"een later blikje: geen beloningsscherm")
	await close_screens()
	targets = hud.quest_targets()
	test.check(targets.size() == 1 and (targets[0] as Vector2).distance_to(Vector2(second.global_position.x, second.global_position.z)) < 0.5,
		"het eerste gepakt: alleen het tweede nog op de kaart (%d)" % targets.size())
	await interiors.leave()
	await close_screens()
	await seconds(0.7)
	targets = hud.quest_targets()
	test.check(not interiors.is_inside() and targets.size() == 1 and (targets[0] as Vector2).distance_to(entrance) < 1.0,
		"weer buiten: het kaartje wijst weer naar de ingang van Centraal")
	await interiors.enter(ways[0])
	await close_screens()
	await seconds(0.7)
	test.check(not hud.is_showing_story(), "weer binnen: de verteller vertelt het niet nog eens")
	test.check(not station.mission_cans().has("perron_1") and station.mission_cans().has("perron_2"), "weer binnen: een gepakt blikje komt niet terug")
	targets = hud.quest_targets()
	test.check(targets.size() == 1 and (targets[0] as Vector2).distance_to(Vector2(second.global_position.x, second.global_position.z)) < 0.5,
		"weer binnen: het kaartje wijst het tweede blikje aan (%d)" % targets.size())
	test.check(await _reach_and_take(station, second), "het tweede blikje te pakken vanaf het perron")
	await frames(2)
	await close_screens()
	test.check(_step_done("blikjes"), "zes blikjes: de stap is klaar")
	test.check(story.station_cans_wanted() == 0, "het station hoeft er geen meer")
	test.check(bins.keep_empty_radius == 0.0, "daarna vullen de bakken weer bij")
	var shop: Vector2 = story.supermarkets(story.shroud.start_centre, 1)[0]
	test.check(story.shroud.is_open(shop.x, shop.y), "de statiegeldstap: de supermarkt is open")
	test.check(not (hud.quests()[0].steps as Array).any(func(step: Dictionary) -> bool: return String(step.text).contains("kleingeld")),
		"de bedelstap staat nog niet in de takenlijst")
	await interiors.leave()
	await close_screens()


## The player put on the platform beside the can `spot` of `station` (a spot where the floor is
## the platform's, within the spot's reach): it offers "[E] Blikje pakken" there, and using it
## takes the can. True if it did.
func _reach_and_take(station: Node, spot: Node3D) -> bool:
	for angle_index in 8:
		var angle := angle_index * TAU / 8.0
		var local: Vector3 = spot.position + Vector3(cos(angle), 0.0, sin(angle)) * 0.9
		if station.floor_height(local) != 0.0 or station._track_at(local) != 0:
			continue
		player.global_position = station.to_global(local) + Vector3.UP * 0.05
		player.velocity = Vector3.ZERO
		for frame_index in 12:
			await tree.physics_frame
		if player._talk_partner == spot:
			var inventory_before := int(player.inventory.get("blikje", 0))
			spot.go_through()
			await frames(1)
			return int(player.inventory.get("blikje", 0)) == inventory_before + 1
	return false


## The first deposit machine tried is out of order: then (and not before) Blikken Bertus is on
## the Stationsplein, wandering with his trolley and smoking, muttering now and then; the map
## points to him and the area does not grow. He buys the cans, a quarter each: € 1,50 for six,
## short of the kroket (€ 2), which ticks off the step. Then the thought of asking people for
## money, and the begging step (only now in the list, and only now can you ask for change);
## € 2 in the wallet ticks it off.
func test_the_first_deposit_machine_is_out_of_order(test) -> void:
	await _past_the_prologue()
	var story := _story()
	for step_id in ["blikjes"]:
		story.complete_step(MISSION_1, step_id)
	await close_screens()
	var characters: Node = scene.get_node("Personages")
	test.check(characters.person_of("bertus") == null and not story.has_appeared("bertus"), "voor de kapotte automaat: nog geen Bertus")
	var radius_before: float = story.shroud.start_radius
	var shops: Array = story.supermarkets(story.shroud.start_centre, 2)
	var broken: String = story.machine_out_of_order(shops[0])
	await close_screens()
	print("de eerste automaat: ", broken)
	test.check(broken.contains("BUITEN GEBRUIK"), "de eerste automaat is stuk")
	test.check(story.machine_out_of_order(shops[0]) == broken, "en blijft stuk")
	var bertus: Node3D = characters.person_of("bertus")
	test.check(bertus != null and story.has_appeared("bertus") and characters.is_wandering("bertus"), "daarna: Blikken Bertus op het plein")
	if bertus == null:
		return
	var at := Vector2(bertus.global_position.x, bertus.global_position.z)
	print("Bertus op ", at, ", start ", story.shroud.start_centre)
	test.check(story.shroud.is_open(at.x, at.y) and at.distance_to(story._place("centraal")) < 30.0, "op het Stationsplein, in het open gebied")
	test.check(is_equal_approx(story.shroud.start_radius, radius_before), "het gebied groeit niet")
	test.check(characters.trolley_of("bertus") != null and characters.trolley_of("bertus").get_child_count() > 10, "met een winkelkarretje vol blikjes")
	test.check(characters.smoke_of("bertus") != null and characters.smoke_of("bertus").is_inside_tree(), "en hij rookt")
	test.check(bertus.call("voice") == "rasperig", "met een rasperige stem")
	var targets: Array = hud.quest_targets()
	test.check(targets.size() == 1 and (targets[0] as Vector2).distance_to(at) < 3.0, "het kaartje wijst naar Bertus")
	test.check((hud.quests()[0].steps as Array).any(func(step: Dictionary) -> bool: return String(step.text).contains("Bertus")), "de stap zegt het")
	# he wanders: a while later he stands elsewhere, the mark with him, and he mutters
	player.global_position = Vector3(at.x + 12.0, player.global_position.y, at.y + 12.0)
	var lines: Array = Conversations.characters().bertus.mompelt
	var moved := false
	for second in 30:
		await seconds(1.0)
		var now := Vector2(bertus.global_position.x, bertus.global_position.z)
		moved = moved or now.distance_to(at) > 2.0
		if moved and characters.last_muttered("bertus") != "":
			break
	var now := Vector2(bertus.global_position.x, bertus.global_position.z)
	print("Bertus nu op ", now, ", mompelt: ", characters.last_muttered("bertus"))
	test.check(moved and story.shroud.is_open(now.x, now.y) and now.distance_to(story._place("centraal")) < 30.0, "hij loopt rond op het plein")
	test.check(lines.has(characters.last_muttered("bertus")), "en mompelt in zichzelf")
	targets = hud.quest_targets()
	test.check(targets.size() == 1 and (targets[0] as Vector2).distance_to(now) < 3.0, "het kaartje volgt hem")
	var begging := (hud.quests()[0].steps as Array).filter(func(step: Dictionary) -> bool: return String(step.text).contains("kleingeld"))
	test.check(begging.is_empty(), "de bedelstap staat nog niet in de takenlijst (ook niet op slot)")
	var talk := Conversations.new(player, player, hud)
	test.check(not story.is_unlocked("bedelen") and not talk.may_beg(), "nog niet om kleingeld vragen")
	test.check(not player.merchants_open(), "nog niet praten met handelaars (geen geld)")
	# selling the six cans to Bertus: a quarter each
	player.add_money(-player.money)
	player.add_item("blikje", 6 - int(player.inventory.get("blikje", 0)), true)
	var with_bertus := Conversations.new(bertus, player, hud)
	var buys: Dictionary = Conversations.character_talk("bertus", "koopt").onderwerp
	var said := with_bertus._buy_cans(buys)
	print("Bertus: ", said)
	await frames(2)
	test.check(is_equal_approx(player.money, 1.5) and int(player.inventory.get("blikje", 0)) == 0, "Bertus geeft € 1,50 voor zes blikjes (€ %.2f)" % player.money)
	test.check(_step_done("statiegeld"), "statiegeld: de stap is klaar")
	test.check(hud.is_showing_story() and hud._story_box._pages.any(func(page: Dictionary) -> bool: return String(page.text).contains("vragen")),
		"de gedachte: mensen om geld vragen")
	await close_screens()
	test.check(is_equal_approx(story.shroud.start_radius, radius_before), "het gebied is nog even klein")
	test.check(story.is_unlocked("bedelen") and talk.may_beg(), "nu kun je om kleingeld vragen")
	test.check(player.merchants_open(), "nu kun je met handelaars praten")
	begging = (hud.quests()[0].steps as Array).filter(func(step: Dictionary) -> bool: return String(step.text).contains("kleingeld"))
	test.check(begging.size() == 1 and not bool(begging[0].locked) and not bool(begging[0].done),
		"de bedelstap staat nu in de takenlijst: %s" % (begging[0].text if begging.size() > 0 else ""))
	test.check(not _step_done("bedelen"), "€ 1,50 is niet genoeg voor een kroket")
	player.add_money(0.5)
	await frames(2)
	test.check(_step_done("bedelen"), "€ 2 op zak: de bedelstap is klaar")
	await close_screens()
	test.check(characters.person_of("bertus") != null, "Bertus blijft op het plein")


## The kroket: bought it counts only once eaten (F); only then the pockets step appears ("Controleer
## je zakken": the game menu opens), and only opening the inventory finds the slot of the ID card
## empty: the thought of the stolen ID then, mission 1 done, the area opens up (the Plein, Ome
## Wim's) and mission 2 starts.
func test_the_kroket_and_the_stolen_id(test) -> void:
	await _past_the_prologue()
	var story := _story()
	for step_id in ["blikjes", "statiegeld", "bedelen"]:
		story.complete_step(MISSION_1, step_id)
	await close_screens()
	var pockets := func() -> Array: return (hud.quests()[0].steps as Array).filter(func(step: Dictionary) -> bool: return String(step.text).contains("zakken"))
	test.check((pockets.call() as Array).is_empty(), "de zakkenstap staat nog niet in de takenlijst")
	test.check(not story.is_unlocked("snackkaart"), "de frietkar verkoopt nog alleen kroketten")
	var plein: Vector2 = story._place("plein")
	test.check(plein != Vector2.INF and not story.shroud.is_open(plein.x, plein.y), "het Plein is nog dicht")
	player.add_item("kroket", 1, true)
	await frames(2)
	test.check(not _step_done("kroket"), "een kroket op zak telt nog niet")
	test.check(player.eat_something(), "F: de kroket opgegeten")
	await frames(2)
	test.check(_step_done("kroket"), "kroket gegeten")
	var after_kroket: Array = hud._story_box._pages if hud.is_showing_story() else []
	test.check(not after_kroket.any(func(page: Dictionary) -> bool: return String(page.text).contains("ID")), "na de kroket nog geen woord over de ID-kaart")
	await close_screens()
	test.check((pockets.call() as Array).size() == 1, "nu: Controleer je zakken [Tab]")
	test.check(story.is_unlocked("snackkaart"), "na de kroket: de hele kaart van de frietkar")
	var game_menu: Node = hud.get_node("Spelmenu")
	game_menu.open("inventaris")
	test.check(game_menu.is_open(), "het spelmenu gaat nu open")
	var shown: Array = game_menu._items_in_category("")
	test.check(not shown.is_empty() and shown[0] == "id_kaart" and int(player.inventory.get("id_kaart", 0)) == 0,
		"het vakje van de ID-kaart, leeg")
	game_menu.close()
	await frames(2)
	test.check(_step_done("rugzak") and story.is_finished(MISSION_1), "missie 1 klaar")
	test.check(hud.is_showing_story() and String(hud._story_box._pages[0].text).contains("ID-kaart"), "bij het openen: waar is mijn ID-kaart?")
	test.check(not story.is_started(MISSION_2), "missie 2 pas na de gedachten over de ID")
	test.check(story.shroud.is_open(plein.x, plein.y), "missie 1 klaar: het gebied wordt groter (het Plein)")
	await close_screens()
	await frames(5)
	test.check(story.is_started(MISSION_2), "missie 2 begint")
	test.check(story.is_started("zij_blikjesronde"), "de blikjesronde komt vrij")


## Mission 2: Ome Wim stands on the Plein; come to him and talk; the skill check can be
## tried again; the walk through the Centrum opens it; the fundraiser stands in the way
## until talked to; at the Spui the old coat, worn at once.
func test_ome_wim_and_his_coat(test) -> void:
	await _past_the_prologue()
	var story := _story()
	if not story.is_finished(MISSION_1):
		story.complete_mission(MISSION_1)
		await close_screens()
		await frames(5)
		await close_screens()
	var characters: Node = scene.get_node("Personages")
	var wim: Node3D = characters.person_of("ome_wim")
	test.check(wim != null, "Ome Wim staat in de stad")
	if wim == null:
		return
	print("Ome Wim op ", wim.global_position)
	test.check(Vector2(wim.global_position.x, wim.global_position.z).distance_to(story._place("plein")) < 12.0, "op het Plein")
	test.check(story.shroud.is_open(wim.global_position.x, wim.global_position.z), "het Plein is open")
	player.global_position = wim.global_position + Vector3(2.0, 0.0, 0.0)
	await _let_the_story_look()
	test.check(_step_done("zoeken", MISSION_2), "Ome Wim gevonden")
	player.talk_to(wim)
	await frames(2)
	test.check(_step_done("praten", MISSION_2), "met hem gepraat")
	await close_screens()
	# the check: failed it can be tried again (a later conversation), passed it is done
	player.emit_signal("checked", "overtuigen_wim", false)
	test.check(not _step_done("overtuigen", MISSION_2), "mislukt: nog te proberen")
	player.emit_signal("checked", "overtuigen_wim", true)
	await frames(2)
	test.check(_step_done("overtuigen", MISSION_2) and story.has_flag("check:overtuigen_wim"), "overtuigd")
	await close_screens()
	test.check(story.shroud.is_open(100.0, 200.0), "het rondje: het Centrum is open")
	test.check((wim as Pedestrian).story_goal != Pedestrian.NO_STORY_GOAL or not (wim as Pedestrian).story_held, "Ome Wim loopt")
	characters.arrived.emit("ome_wim")
	await frames(2)
	test.check(_step_done("rondje", MISSION_2), "rondje gelopen")
	await close_screens()
	var fundraiser: Node3D = characters.person_of("werver")
	test.check(fundraiser != null, "de goededoelenwerver staat in de weg")
	if fundraiser:
		player.talk_to(fundraiser)
		await frames(2)
		await close_screens()
		await frames(3)
		test.check(_step_done("werver", MISSION_2), "eruit gepraat")
	await close_screens()
	characters.arrived.emit("ome_wim")
	await frames(2)
	await close_screens()
	test.check(int(player.inventory.get("oude_jas", 0)) == 1 and player.call("wears_coat"), "de oude jas aan")
	test.check(story.is_finished(MISSION_2), "missie 2 klaar")
	test.check(story.markers().has("haagse_bos") and story.shroud.is_open(328.0, 28.0), "het Haagse Bos op de kaart en open")
