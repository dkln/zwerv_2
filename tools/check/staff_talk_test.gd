extends SceneTree
## Talking to people on duty in Den Haag Centraal (Conversations, data/gesprekken/personeel.json):
## a conductor and an enforcement officer have their own lines (greeting, topic, follow-up,
## goodbye), refuse change in character, and the story box shows them as officials (their
## title on a name plate in their colours, the emblem NS / BOA on the portrait, the frame in
## their colour, a lower babble); a traveller is an ordinary passer-by. A fare dodger who
## talks to the conductor chasing them is caught: the fine (the station's fine_the_player).
## usage: tools/godot.sh --headless --script tools/check/staff_talk_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const Conversations = preload("res://scripts/story/conversations.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 300)
	for role: String in Conversations.OFFICIAL_ROLES:
		var data: Dictionary = (Conversations.staff().get("personen", {}) as Dictionary).get(role, {})
		var complete := true
		for key in ["spreker", "embleem", "kleur", "begroetingen", "onderwerp", "kleingeld_nee", "dag"]:
			complete = complete and data.has(key)
		_check(complete, "personeel %s compleet" % role)
	_check(((Conversations.staff().personen as Dictionary).conducteur as Dictionary).has("betrapt"), "de conducteur heeft een zin voor zwartrijders")
	PlayerCharacter.choose("martin")
	var scene := Common.instantiate(Common.CITY, false)
	for node_name in ["DetailNiveau", "Rook", "Grassprieten", "Verhaal"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	var player: Node3D = scene.get_node("Speler")
	var hud: Node = scene.get_node("HUD")
	scene.get_node("Volgcamera")._end_arrival()
	for frame_index in 600:
		await physics_frame
		if player._placed and not player._sleeping:
			break
	player._wake_up()
	for attempt in 40:
		if not player._sleeping:
			break
		await create_timer(0.1, true).timeout
	var interiors: Node = scene.get_node("Binnenruimtes")
	var ways: Array = interiors.ways_in().filter(func(way: Dictionary) -> bool: return way.kind == "centraal")
	_check(not ways.is_empty(), "Centraal heeft een ingang")
	if ways.is_empty():
		_finish()
		return
	interiors.enter(ways[0])
	await create_timer(1.4, true).timeout
	var station: Node3D = interiors._interior
	_check(station != null and station.has_method("is_chasing"), "binnen in het station")
	if station == null or not station.has_method("is_chasing"):
		_finish()
		return
	var people: Array = station.station_people()
	var by_role := {}
	for someone: StationPerson in people:
		if not by_role.has(someone.role):
			by_role[someone.role] = someone
	print("in het station: ", by_role.keys())
	var box: Node = hud._story_box
	var greetings := {}
	for role: String in ["conducteur", "handhaver"]:
		_check(by_role.has(role), "een %s in het station" % role)
		if not by_role.has(role):
			continue
		var official: StationPerson = by_role[role]
		_check(Conversations.is_official(official), "%s is personeel" % role)
		player.talk_to(official)
		await process_frame
		var page: Dictionary = box._pages[box._page_index]
		var style: Dictionary = page.get("official", {})
		print("%s: [%s] %s  %s" % [page.speaker, style.get("emblem", ""), page.text, page.choices])
		greetings[role] = String(page.text)
		var own_lines: Dictionary = (Conversations.staff().personen as Dictionary)[role]
		_check(own_lines.begroetingen.has(page.text) and page.speaker == own_lines.spreker, "%s: een eigen begroeting en naam (%s)" % [role, page.speaker])
		_check(not style.is_empty() and box._emblem.visible and box._emblem_label.text == own_lines.embleem, "%s: embleem %s op het portret" % [role, own_lines.embleem])
		var plate: StyleBoxFlat = box._name_tag.get_theme_stylebox("panel")
		_check(plate.bg_color.is_equal_approx(Color(own_lines.naamkaartje)) and plate.border_width_left == 2, "%s: naamkaartje in de eigen kleuren" % role)
		_check(box._portrait.townsfolk_look == official.figure.look, "%s: in uniform in het portret" % role)
		_check(float(style.get("pitch", 1.0)) < 1.0, "%s: een eigen, lagere stem" % role)
		await _check_live_portrait(box._portrait, official.figure, role, func() -> bool: return box._typewriter.is_done(), func() -> void: box._typewriter.finish())
		# the topic, its follow-up, change, goodbye: each their own line
		var topic: Dictionary = own_lines.onderwerp
		box._typewriter.finish()
		box._choose((page.choices as Array).find(topic.vraag))
		box._say_choice()
		page = box._pages[box._page_index]
		_check(String(page.text) == topic.antwoord, "%s: eigen antwoord op het onderwerp" % role)
		_check((page.choices as Array).has(topic.doorvraag), "%s: met een doorvraag" % role)
		var money_before: float = player.money
		box._typewriter.finish()
		box._choose((page.choices as Array).find(Conversations.question("kleingeld")))
		box._say_choice()
		page = box._pages[box._page_index]
		print("  kleingeld: ", page.text)
		_check(String(page.text).begins_with(own_lines.kleingeld_nee) and is_equal_approx(player.money, money_before), "%s: weigert kleingeld, in stijl" % role)
		box._typewriter.finish()
		box._choose((page.choices as Array).find(Conversations.question("dag")))
		box._say_choice()
		page = box._pages[box._page_index]
		print("  dag: ", page.text)
		_check(String(page.text) == own_lines.dag and not page.get("official", {}).is_empty(), "%s: eigen afscheid, nog steeds als personeel" % role)
		box._typewriter.finish()
		box._next_page()
		await process_frame
		_check(not box.is_showing(), "%s: gesprek dicht" % role)
	# a traveller: an ordinary passer-by
	var traveller: StationPerson = by_role.get("reiziger", by_role.get("student", null))
	if traveller:
		player.talk_to(traveller)
		await process_frame
		var page: Dictionary = box._pages[box._page_index]
		_check(not Conversations.is_official(traveller) and not page.has("official") and not box._emblem.visible, "een reiziger is een gewone voorbijganger (%s)" % page.speaker)
		var plate: StyleBoxFlat = box._name_tag.get_theme_stylebox("panel")
		_check(plate.border_width_left == 0, "de reiziger heeft het gewone naamkaartje")
		box._pages = box._pages.slice(-1)
		box._page_index = 0
		box._next_page()
		await process_frame
	# the fare dodger and the conductor chasing them: caught, the fine
	if by_role.has("conducteur"):
		var conductor: StationPerson = by_role.conducteur
		station._chaser = conductor
		player.add_money(80.0 - player.money)
		var fines_before: int = station.fines
		player.talk_to(conductor)
		await process_frame
		var page: Dictionary = box._pages[box._page_index]
		print("zwartrijder: ", page.text, "  € %.2f over" % player.money)
		_check(String(page.text).contains("zwartrijden") and String(page.text).contains("€ 50,00"), "de conducteur die je achternazit: betrapt")
		_check(is_equal_approx(player.money, 30.0) and station.fines == fines_before + 1, "zwartrijder beboet (€ 50 eraf)")
		_check(station._chaser == null, "de achtervolging is voorbij")
		box._pages = box._pages.slice(-1)
		box._page_index = 0
		box._next_page()
		await process_frame
		# and talking to him again: no second fine
		player.talk_to(conductor)
		await process_frame
		_check(is_equal_approx(player.money, 30.0) and greetings.has("conducteur"), "daarna gewoon een gesprek, geen tweede boete")
		box._pages = box._pages.slice(-1)
		box._page_index = 0
		box._next_page()
	_finish()


## The close-up is live and talks: it follows the figure in the world (its pose, its mood's
## moves), the mouth opens and shuts while the line types out, and is shut once it is there.
func _check_live_portrait(portrait: Node, figure: TownsfolkFigure, label: String, typed_out: Callable, finish_typing: Callable) -> void:
	var face: TownsfolkFigure = portrait._townsfolk if portrait else null
	_check(face != null and face.has_face(), "%s: het portret heeft een mondje" % label)
	if face == null:
		return
	_check(portrait.source_figure == figure, "%s: het portret volgt de figuur in de wereld" % label)
	var openings := {}
	var heights := {}
	for sample in 16:
		await create_timer(0.04, true).timeout
		if typed_out.call():
			break
		openings[snappedf(face.mouth_opening(), 0.01)] = true
		heights[snappedf(face.transform.origin.y + face.transform.basis.y.y, 0.0001)] = true
	print("  %s: mond %s, %d houdingen" % [label, openings.keys(), heights.size()])
	_check(openings.size() >= 2 and openings.keys().any(func(opening: float) -> bool: return opening > 0.5), "%s: het mondje beweegt tijdens het typen" % label)
	_check(heights.size() >= 3, "%s: het portret beweegt (stemming, ademen)" % label)
	var arm_in_world: Transform3D = figure._joints.arm_left.transform
	_check((face._joints.arm_left.transform as Transform3D).is_equal_approx(arm_in_world) and (face._body.transform as Transform3D).is_equal_approx(figure._body.transform), "%s: dezelfde houding als in het spel" % label)
	finish_typing.call()
	await create_timer(0.1, true).timeout
	_check(is_zero_approx(face.mouth_opening()), "%s: mondje dicht als de zin er staat" % label)


func _finish() -> void:
	print("personeel ok" if _problems.is_empty() else "problemen: " + str(_problems))
	quit(0 if _problems.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	print(("ok   " if condition else "FOUT ") + label)
	if not condition:
		_problems.append(label)
