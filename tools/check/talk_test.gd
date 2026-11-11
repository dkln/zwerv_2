extends SceneTree
## Talking to passers-by (PlayerController.talk_to, scripts/story/conversations.gd): near
## someone the HUD shows "[E] Praten" bottom left, E opens a conversation in the story box
## with choices, the persona fits the look, asking for change maybe gives some, and saying
## goodbye closes it. Every persona has all its lines.
## usage: tools/godot.sh --headless --script tools/check/talk_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const Conversations = preload("res://scripts/story/conversations.gd")
const Babble = preload("res://scripts/audio/babble.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 300)
	for persona: String in Conversations.personas():
		var data: Dictionary = Conversations.personas()[persona]
		var complete := true
		for key in ["spreker", "begroetingen", "onderwerp", "kleingeld_ja", "kleingeld_nee", "dag", "gulheid"]:
			complete = complete and data.has(key)
		_check(complete, "persona %s compleet" % persona)
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
	for attempt in 30:
		if not player._sleeping:
			break
		await create_timer(0.1, true).timeout
	var to_camera := get_root().get_viewport().get_camera_3d().global_position - player.global_position
	var woke_facing := Vector2(sin(player.rotation.y), cos(player.rotation.y))
	_check(woke_facing.dot(Vector2(to_camera.x, to_camera.z).normalized()) > 0.9, "na het opstaan met het gezicht naar de camera")
	for frame_index in 120:
		await physics_frame
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	var person: Pedestrian = walkers.people()[0]
	var personas := {}
	for someone: Pedestrian in walkers.people():
		personas[Conversations.persona_of(someone)] = true
	print("personas in de stad: ", personas.keys())
	_check(personas.size() >= 4, "verschillende soorten mensen (%d)" % personas.size())
	# everyone is something you can see: "OUDE DAME", "MAN MET HOED", never just a passer-by
	var names := {}
	var nameless := 0
	for someone: Pedestrian in walkers.people():
		var persona_id := Conversations.persona_of(someone)
		var data: Dictionary = Conversations.personas().get(persona_id, {})
		var shown := Conversations.name_of(someone, data)
		if shown == "" or shown == "VOORBIJGANGER":
			nameless += 1
		names[shown] = names.get(shown, 0) + 1
	print("namen in de stad: ", names)
	_check(nameless == 0 and names.size() >= 5, "iedereen heeft een beschrijving (%d soorten namen, %d zonder)" % [names.size(), nameless])
	# a passer-by of a kind talks as that kind; someone on duty as the police
	var kinds_fit := true
	for someone: Pedestrian in walkers.people():
		if someone.crowd_kind != "" and someone.role == "" and someone.mobility == "":
			var persona_id := Conversations.persona_of(someone)
			var rules: Dictionary = Conversations.personas().get(persona_id, {}).get("herkennen", {})
			if str(rules.get("soort", "")) != someone.crowd_kind:
				kinds_fit = false
				print("past niet: %s praat als %s" % [someone.crowd_kind, persona_id])
	_check(kinds_fit, "het gesprek past bij de soort mens")
	var officer: Pedestrian = walkers.people()[1]
	var was := [officer.role, officer.crowd_kind]
	officer.role = "agent"
	officer.crowd_kind = "agent"
	var police := Conversations.new(officer, player, hud)
	_check(Conversations.is_official(officer) and police.speaker() == "POLITIE" and police.official_style().get("emblem") == "POLITIE",
			"een agent op straat praat als politie")
	officer.role = was[0]
	officer.crowd_kind = was[1]
	# stand right before them
	person._pause = 100.0
	player.global_position = person.global_position + Vector3(1.2, 0.0, 0.0)
	for frame_index in 10:
		await physics_frame
	_check(player._talk_partner == person, "iemand in de buurt om mee te praten")
	_check(hud._action_prompts.visible and hud._action_prompts.actions() == [["E", "Praten"]], "[E] Praten linksonder")
	player.talk_to(person)
	var body: Node3D = person.figure.get("_body")
	_check(person.get("_walking") == 0.0 and body != null and body.position.is_zero_approx(),
			"de voorbijganger staat stil en recht (geen been in de lucht)")
	await process_frame
	var box: Node = hud._story_box
	_check(box.is_showing() and paused, "gesprek open, spel staat stil")
	await create_timer(0.6, true).timeout
	var to_player: Vector3 = (player.global_position - person.global_position)
	var facing := Vector3(sin(person.rotation.y), 0.0, cos(person.rotation.y))
	_check(facing.dot(Vector3(to_player.x, 0.0, to_player.z).normalized()) > 0.95, "de ander draait naar de speler")
	var page: Dictionary = box._pages[box._page_index]
	print("%s: %s  %s" % [page.speaker, page.text, page.choices])
	_check(page.kind == "gesprek" and page.choices.size() >= 3, "met keuzes")
	_check(not page.has("official") and not box._emblem.visible, "een voorbijganger is geen personeel (geen embleem, gewoon naamkaartje)")
	_check(page.has("voice") and page.has("mood"), "met stem en stemming (%s, %s)" % [page.get("voice"), page.get("mood")])
	for frame_index in 20:
		await process_frame
	_check(is_instance_valid(box._babble), "brabbelt tijdens het typen")
	var emote: Node = person.get_node_or_null("Emotie")
	_check(emote != null and emote.mood == page.mood, "lichaam beweegt met de stemming")
	var rest: Transform3D = emote._rest if emote else Transform3D.IDENTITY
	_check(box._portrait != null and box._portrait.townsfolk_look == person.figure.look and box._portrait._townsfolk != null, "gesprekspartner in het portret")
	_check(box._portrait.source_figure == person.figure and box._portrait._townsfolk.has_face() and box._portrait.speaking == not box._typewriter.is_done(), "portret van de voorbijganger leeft en praat mee")
	var follow: Node = scene.get_node("Volgcamera")
	var zoom_before: float = follow._zoom
	# real seconds (headless frames go faster than the clock); the timer runs while paused
	await create_timer(2.5, true).timeout
	print("zoom: %.1f -> %.1f m (aankomst %s, talk_zoom %.1f, snelheid %.2f)" % [zoom_before, follow._zoom, follow._arriving, follow.talk_zoom, follow._zoom_velocity])
	_check(follow._zoom < zoom_before - 1.0 and follow._zoom > follow.talk_zoom, "camera zoomt rustig in, ook met het spel stil")
	box._typewriter.finish()
	for frame_index in 4:
		await process_frame
	# the choices on the right, the conversation on the left
	_check(box._choices_scroll.visible and box._choices_box.visible, "keuzes rechts in beeld")
	_check(box._choices_scroll.position.x >= box._scroll.position.x + box._scroll.size.x, "keuzes naast het gesprek")
	var narrowest := INF
	for line: Label in box._choice_labels:
		narrowest = minf(narrowest, line.size.x)
	_check(narrowest > box._choices_scroll.size.x * 0.8, "keuzes zo breed als hun vak (%.0f van %.0f px)" % [narrowest, box._choices_scroll.size.x])
	_check(is_equal_approx(box._portrait_frame.size.y, box.BOX_HEIGHT), "venster blijft even hoog")
	var room: float = box._choices_box.size.y - box._choices_scroll.size.y
	if room > 1.0:
		var last: int = box._choice_labels.size() - 1
		box._choose(last)
		await process_frame
		await process_frame
		_check(box._choices_scroll.scroll_vertical > 0, "kiezen scrolt de keuzes mee (%d px)" % box._choices_scroll.scroll_vertical)
		box._choose(0)
		await process_frame
		await process_frame
	print("keuzes passen %s (%.0f px over)" % ["niet" if room > 1.0 else "wel", maxf(room, 0.0)])
	var first_line: Label = box._choice_labels[0]
	_check(first_line.get_theme_font_size("font_size") == box.TEXT_SIZE, "keuzes even groot als de tekst")
	# ask for change
	box._typewriter.finish()
	var money_index: int = (page.choices as Array).find(Conversations.question("kleingeld"))
	box._choose(money_index)
	box._say_choice()
	page = box._pages[box._page_index]
	print("  kleingeld: ", page.text)
	# let it type out (real seconds) and the scroll settle (FOLLOW_AFTER), then measure in the
	# box's own design pixels: headless the window is tiny and frames run faster than the
	# clock, the layout is the same
	for attempt in 80:
		if box._typewriter.is_done():
			break
		await create_timer(0.05, true).timeout
	await create_timer(box.FOLLOW_AFTER + 0.2, true).timeout
	var view: Rect2 = box._scroll.get_global_rect()
	var reply: Rect2 = box._text.get_global_rect()
	var reply_top: float = box._text.position.y - box._scroll.scroll_vertical
	var reply_bottom: float = reply_top + box._text.size.y
	var view_height: float = box._scroll.size.y
	var whole_fits: bool = box._text.size.y <= view_height
	var in_view: bool = reply_bottom <= view_height + 1.0 and (reply_top >= -1.0 or not whole_fits)
	_check(box._text.text != "" and in_view, "na de keuze de hele nieuwe reactie in beeld (%.0f..%.0f px in 0..%.0f)" % [reply_top, reply_bottom, view_height])
	_check(box._history_text.visible and box._history_text.text.contains(Conversations.question("kleingeld")), "wat gezegd is blijft staan")
	_check(not (page.choices as Array).has(Conversations.question("kleingeld")), "kleingeld niet nog eens vragen")
	_check(person.has_meta(Conversations.GAVE_META), "eens per persoon")
	# a new line typing out: the part that has appeared stays in view as it goes
	box._choose(0)
	box._say_choice()
	var typed_in_view := true
	for frame_index in 40:
		await create_timer(0.05, true).timeout
		# in the box's own (design) pixels: headless the window is tiny, the layout is not
		var typed_bottom: float = box._text.position.y + box._text.size.y * box._typewriter.shown_share() - box._scroll.scroll_vertical
		if box._typewriter.shown_share() > 0.2 and typed_bottom > box._scroll.size.y + box.TEXT_SIZE * 2.0:
			typed_in_view = false
	_check(typed_in_view, "wat uittypt blijft in beeld (scrolt mee)")
	# another question: the history longer, the newest line still all in view
	box._typewriter.finish()
	box._choose(0)
	box._say_choice()
	await create_timer(0.3, true).timeout
	box._typewriter.finish()
	await create_timer(0.3, true).timeout
	page = box._pages[box._page_index]
	view = box._scroll.get_global_rect()
	reply = box._text.get_global_rect()
	_check(view.grow(1.0).encloses(reply), "ook na nog een keuze de nieuwste reactie helemaal in beeld")
	# goodbye
	box._typewriter.finish()
	box._choose((page.choices as Array).find(Conversations.question("dag")))
	box._say_choice()
	print("  dag: ", box._pages[box._page_index].text)
	box._typewriter.finish()
	box._next_page()
	var emote_after: Node = person.get_node_or_null("Emotie")
	_check((emote_after == null or emote_after.is_queued_for_deletion()) and person.figure.transform.is_equal_approx(rest), "daarna weer gewoon")
	await process_frame
	_check(not box.is_showing() and not paused, "na het afscheid dicht, spel gaat door")
	# every persona's longest reply (with the longest "nog iets" after it), after a line and a
	# choice: once typed out and settled, its end is in view (not only the passer-by picked)
	await _check_longest_replies(box)
	for mood: String in Babble.MOODS:
		for voice: String in Babble.VOICES:
			var name := "brabbel_%s_%s_1" % [voice, mood]
			if not ResourceLoader.exists(Babble.FOLDER + name + ".ogg"):
				_problems.append("geen " + name)
	_check(not _problems.any(func(problem: String) -> bool: return problem.begins_with("geen ")), "alle brabbelgeluiden er")
	print("praten ok" if _problems.is_empty() else "problemen: " + str(_problems))
	quit(0 if _problems.is_empty() else 1)


## For every persona of voorbijgangers.json: its longest answer as the reply to a choice in
## the story box, after a greeting (so there is history above it); typed out and the scroll
## settled (real seconds), the whole reply in view (its end at least, when it is taller).
func _check_longest_replies(box: Node) -> void:
	var agains: Array = Conversations.street().get("nog_iets", ["Nog iets?"])
	var longest_again := ""
	for again: Variant in agains:
		if str(again).length() > longest_again.length():
			longest_again = str(again)
	var cut_off: Array[String] = []
	for persona: String in Conversations.personas():
		var data: Dictionary = Conversations.personas()[persona]
		var topic: Dictionary = data.get("onderwerp", {})
		var replies: Array[String] = [str(topic.get("antwoord", "")), str(topic.get("doorantwoord", "")) + " " + longest_again,
			str(data.get("kleingeld_ja", "")) + " " + longest_again, str(data.get("kleingeld_nee", "")) + " " + longest_again]
		var longest := ""
		for reply_text in replies:
			if reply_text.length() > longest.length():
				longest = reply_text
		var greeting := str((data.get("begroetingen", ["Hé."]) as Array)[0])
		var choices := [Conversations.question("kleingeld"), Conversations.question("dag")]
		var reply_page := {"kind": "gesprek", "speaker": str(data.get("spreker", "")), "text": longest, "choices": choices,
			"voice": "man", "mood": "neutraal", "on_choice": func(_index: int) -> Array: return []}
		box.show_pages([{"kind": "gesprek", "speaker": str(data.get("spreker", "")), "text": greeting, "choices": choices,
			"voice": "man", "mood": "neutraal", "on_choice": func(_index: int) -> Array: return [reply_page]}])
		box._typewriter.finish()
		box._say_choice()
		for attempt in 120:
			if box._typewriter.is_done():
				break
			await create_timer(0.05, true).timeout
		await create_timer(box.FOLLOW_AFTER + 0.2, true).timeout
		var reply_top: float = box._text.position.y - box._scroll.scroll_vertical
		var reply_bottom: float = reply_top + box._text.size.y
		var view_height: float = box._scroll.size.y
		var whole_fits: bool = box._text.size.y <= view_height
		print("  %-14s %3d tekens: %.0f..%.0f px in 0..%.0f" % [persona, longest.length(), reply_top, reply_bottom, view_height])
		if not (reply_bottom <= view_height + 1.0 and (reply_top >= -1.0 or not whole_fits)):
			cut_off.append(persona)
		box._pages = box._pages.slice(-1)
		box._page_index = 0
		box._next_page()
		await process_frame
	_check(cut_off.is_empty(), "het langste antwoord van elke voorbijganger helemaal in beeld (%s)" % ("alle %d" % Conversations.personas().size() if cut_off.is_empty() else "afgesneden: " + ", ".join(cut_off)))


func _check(condition: bool, label: String) -> void:
	print(("ok   " if condition else "FOUT ") + label)
	if not condition:
		_problems.append(label)
