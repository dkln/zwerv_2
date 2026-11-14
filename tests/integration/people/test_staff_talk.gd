extends "res://tests/integration/support/town_test.gd"
## Talking to people on duty in Den Haag Centraal (Conversations, data/gesprekken/personeel.json):
## a conductor and an enforcement officer have their own lines (greeting, topic, follow-up,
## goodbye), refuse change in character, and the story box shows them as officials (their
## title on a name plate in their colours, the emblem NS / BOA on the portrait, the frame in
## their colour, a lower babble); a traveller is an ordinary passer-by. A fare dodger who
## talks to the conductor chasing them is caught: the fine (the station's fine_the_player).
##   tests/run_integration_tests.sh staff_talk

const Conversations = preload("res://scripts/story/conversations.gd")
const StoryBoxHelp = preload("res://tests/integration/support/story_box_help.gd")


## Goes into Den Haag Centraal and returns the first person of every role there
## ({role: StationPerson}); empty if the station cannot be entered. `test` gets the checks
## that it could.
func _people_in_the_station(test) -> Dictionary:
	var way := await enter("centraal")
	test.check(not way.is_empty(), "Centraal heeft een ingang")
	if way.is_empty():
		return {}
	var station: Node3D = interiors._interior
	var inside := station != null and station.has_method("is_chasing")
	test.check(inside, "binnen in het station")
	if not inside:
		return {}
	var by_role := {}
	for someone: StationPerson in station.station_people():
		if not by_role.has(someone.role):
			by_role[someone.role] = someone
	print("in het station: ", by_role.keys())
	return by_role


## The lines of `role` in personeel.json.
func _lines_of(role: String) -> Dictionary:
	return (Conversations.staff().personen as Dictionary)[role]


## Starts the base conversation (not one of its "varianten") with the first `role` in the
## station; returns {"official", "lines", "page"} with the box open on the greeting, or
## empty if there is no one of that role.
func _talk_to_official(test, role: String) -> Dictionary:
	var by_role := await _people_in_the_station(test)
	test.check(by_role.has(role), "een %s in het station" % role)
	if not by_role.has(role):
		return {}
	var official: StationPerson = by_role[role]
	official.set_meta(Conversations.VARIANT_META, 0)
	player.talk_to(official)
	await frames(1)
	return {"official": official, "lines": _lines_of(role), "page": StoryBoxHelp.page(hud._story_box)}


## The greeting of an official of `role`: its own line and name, shown as an official
## (emblem, name plate, uniform in the portrait, a lower voice) with a live, talking portrait.
func _check_shown_as_official(test, role: String) -> void:
	var talk := await _talk_to_official(test, role)
	if talk.is_empty():
		return
	var box: Node = hud._story_box
	var official: StationPerson = talk.official
	var own_lines: Dictionary = talk.lines
	var page: Dictionary = talk.page
	var style: Dictionary = page.get("official", {})
	print("%s: [%s] %s  %s" % [page.speaker, style.get("emblem", ""), page.text, page.choices])
	test.check(Conversations.is_official(official), "%s is personeel" % role)
	test.check(own_lines.begroetingen.has(page.text) and page.speaker == own_lines.spreker, "%s: een eigen begroeting en naam (%s)" % [role, page.speaker])
	test.check(not style.is_empty() and box._emblem.visible and box._emblem_label.text == own_lines.embleem, "%s: embleem %s op het portret" % [role, own_lines.embleem])
	var plate: StyleBoxFlat = box._name_tag.get_theme_stylebox("panel")
	test.check(plate.bg_color.is_equal_approx(Color(own_lines.naamkaartje)) and plate.border_width_left == 2, "%s: naamkaartje in de eigen kleuren" % role)
	test.check(box._portrait.townsfolk_look == official.figure.look, "%s: in uniform in het portret" % role)
	test.check(float(style.get("pitch", 1.0)) < 1.0, "%s: een eigen, lagere stem" % role)
	await _check_live_portrait(test, box, official.figure, role)
	StoryBoxHelp.close(box)


## The close-up is live and talks: it follows the figure in the world (its pose, its mood's
## moves), the mouth opens and shuts while the line types out, and is shut once it is there.
func _check_live_portrait(test, box: Node, figure: TownsfolkFigure, label: String) -> void:
	var portrait: Node = box._portrait
	var face: TownsfolkFigure = portrait.townsfolk_figure() if portrait else null
	test.check(face != null and face.has_face(), "%s: het portret heeft een mondje" % label)
	if face == null:
		return
	test.check(portrait.source_figure == figure, "%s: het portret volgt de figuur in de wereld" % label)
	var openings := {}
	var heights := {}
	for sample in 16:
		await seconds(0.04)
		if box._typewriter.is_done():
			break
		openings[snappedf(face.mouth_opening(), 0.01)] = true
		heights[snappedf(face.transform.origin.y + face.transform.basis.y.y, 0.0001)] = true
	print("  %s: mond %s, %d houdingen" % [label, openings.keys(), heights.size()])
	test.check(openings.size() >= 2 and openings.keys().any(func(opening: float) -> bool: return opening > 0.5), "%s: het mondje beweegt tijdens het typen" % label)
	test.check(heights.size() >= 3, "%s: het portret beweegt (stemming, ademen)" % label)
	var arm_in_world: Transform3D = figure._joints.arm_left.transform
	test.check((face._joints.arm_left.transform as Transform3D).is_equal_approx(arm_in_world) and (face._body.transform as Transform3D).is_equal_approx(figure._body.transform), "%s: dezelfde houding als in het spel" % label)
	box._typewriter.finish()
	await seconds(0.1)
	test.check(is_zero_approx(face.mouth_opening()), "%s: mondje dicht als de zin er staat" % label)


## The conversation with an official of `role` after the greeting: the topic, its
## follow-up, change refused, goodbye; each their own line, and the box shut after.
func _check_own_lines(test, role: String) -> void:
	var talk := await _talk_to_official(test, role)
	if talk.is_empty():
		return
	var box: Node = hud._story_box
	var own_lines: Dictionary = talk.lines
	var topic: Dictionary = own_lines.onderwerp
	var page := StoryBoxHelp.choose(box, topic.vraag)
	test.check(String(page.text) == topic.antwoord, "%s: eigen antwoord op het onderwerp" % role)
	test.check((page.choices as Array).has(topic.doorvraag), "%s: met een doorvraag" % role)
	var money_before: float = player.money
	page = StoryBoxHelp.choose(box, Conversations.question("kleingeld"))
	print("  kleingeld: ", page.text)
	test.check(String(page.text).begins_with(own_lines.kleingeld_nee) and is_equal_approx(player.money, money_before), "%s: weigert kleingeld, in stijl" % role)
	page = StoryBoxHelp.choose(box, Conversations.question("dag"))
	print("  dag: ", page.text)
	test.check(String(page.text) == own_lines.dag and not page.get("official", {}).is_empty(), "%s: eigen afscheid, nog steeds als personeel" % role)
	box._typewriter.finish()
	box._next_page()
	await frames(1)
	test.check(not box.is_showing(), "%s: gesprek dicht" % role)


## Everyone on duty in personeel.json has all their lines, and the conductor one for fare dodgers.
func test_every_official_has_all_their_lines(test) -> void:
	for role: String in Conversations.OFFICIAL_ROLES:
		var data: Dictionary = (Conversations.staff().get("personen", {}) as Dictionary).get(role, {})
		var complete := true
		for key: String in ["spreker", "embleem", "kleur", "begroetingen", "onderwerp", "kleingeld_nee", "dag"]:
			complete = complete and data.has(key)
		test.check(complete, "personeel %s compleet" % role)
	test.check(_lines_of("conducteur").has("betrapt"), "de conducteur heeft een zin voor zwartrijders")


## The conductor in the station is shown as an official: own greeting, NS emblem, name
## plate, uniform, lower voice, a live portrait that talks along.
func test_conductor_is_shown_as_an_official(test) -> void:
	await _check_shown_as_official(test, "conducteur")


## The enforcement officer in the station is shown as an official, as the conductor.
func test_enforcement_officer_is_shown_as_an_official(test) -> void:
	await _check_shown_as_official(test, "handhaver")


## The conductor answers the topic and its follow-up, refuses change and says goodbye in
## his own lines.
func test_conductor_has_his_own_lines(test) -> void:
	await _check_own_lines(test, "conducteur")


## The enforcement officer answers the topic and its follow-up, refuses change and says
## goodbye in their own lines.
func test_enforcement_officer_has_their_own_lines(test) -> void:
	await _check_own_lines(test, "handhaver")


## A traveller in the station is an ordinary passer-by: no emblem, the plain name plate.
func test_a_traveller_is_an_ordinary_passer_by(test) -> void:
	var by_role := await _people_in_the_station(test)
	var traveller: StationPerson = by_role.get("reiziger", by_role.get("student", null))
	test.check(traveller != null, "een reiziger in het station")
	if traveller == null:
		return
	var box: Node = hud._story_box
	player.talk_to(traveller)
	await frames(1)
	var page := StoryBoxHelp.page(box)
	test.check(not Conversations.is_official(traveller) and not page.has("official") and not box._emblem.visible, "een reiziger is een gewone voorbijganger (%s)" % page.speaker)
	var plate: StyleBoxFlat = box._name_tag.get_theme_stylebox("panel")
	test.check(plate.border_width_left == 0, "de reiziger heeft het gewone naamkaartje")
	StoryBoxHelp.close(box)


## A fare dodger who talks to the conductor chasing them is caught: fined € 50 once, the
## chase over; talking to him again is an ordinary conversation.
func test_fare_dodger_talking_to_the_chasing_conductor_is_fined(test) -> void:
	var by_role := await _people_in_the_station(test)
	test.check(by_role.has("conducteur"), "een conducteur in het station")
	if not by_role.has("conducteur"):
		return
	var station: Node3D = interiors._interior
	var box: Node = hud._story_box
	var conductor: StationPerson = by_role.conducteur
	station._chaser = conductor
	player.add_money(80.0 - player.money)
	var fines_before: int = station.fines
	player.talk_to(conductor)
	await frames(1)
	var page := StoryBoxHelp.page(box)
	print("zwartrijder: ", page.text, "  € %.2f over" % player.money)
	test.check(String(page.text).contains("zwartrijden") and String(page.text).contains("€ 50,00"), "de conducteur die je achternazit: betrapt")
	test.check(is_equal_approx(player.money, 30.0) and station.fines == fines_before + 1, "zwartrijder beboet (€ 50 eraf)")
	test.check(station._chaser == null, "de achtervolging is voorbij")
	StoryBoxHelp.close(box)
	await frames(1)
	# and talking to him again: no second fine
	player.talk_to(conductor)
	await frames(1)
	test.check(is_equal_approx(player.money, 30.0) and box.is_showing() and not String(StoryBoxHelp.page(box).text).contains("zwartrijden"),
		"daarna gewoon een gesprek, geen tweede boete")
	StoryBoxHelp.close(box)


## Chased for not checking out: talking to the conductor, his own line for it
## ("betrapt_uitchecken"), the fine, and he checks you out.
func test_talking_to_the_conductor_after_not_checking_out(test) -> void:
	var by_role := await _people_in_the_station(test)
	test.check(by_role.has("conducteur"), "een conducteur in het station")
	if not by_role.has("conducteur"):
		return
	var station: Node3D = interiors._interior
	var box: Node = hud._story_box
	var conductor: StationPerson = by_role.conducteur
	station._chaser = conductor
	station._chase_reason = "uitchecken"
	player.set_meta("ov_ingecheckt", true)
	player.add_money(80.0 - player.money)
	player.talk_to(conductor)
	await frames(1)
	var page := StoryBoxHelp.page(box)
	print("niet uitgecheckt: ", page.text)
	test.check(String(page.text).contains("niet uitgecheckt") and String(page.text).contains("€ 50,00"), "de conducteur: betrapt, niet uitgecheckt")
	test.check(is_equal_approx(player.money, 30.0) and not bool(player.get_meta("ov_ingecheckt", false)), "beboet en uitgecheckt")
	StoryBoxHelp.close(box)
