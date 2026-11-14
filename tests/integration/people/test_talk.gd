extends "res://tests/integration/support/town_test.gd"
## Talking to passers-by (PlayerController.talk_to, scripts/story/conversations.gd): near
## someone the HUD shows "[E] Praten" bottom left, E opens a conversation in the story box
## with choices, the persona fits the look, asking for change maybe gives some, and saying
## goodbye closes it. Every persona has all its lines.
##   tests/run_integration_tests.sh talk

const Conversations = preload("res://scripts/story/conversations.gd")
const Babble = preload("res://scripts/audio/babble.gd")
const StoryBoxHelp = preload("res://tests/integration/support/story_box_help.gd")


## The passers-by of the town.
func _walkers() -> Pedestrians:
	return scene.get_node("Voetgangers")


## A passer-by who has not been asked for change yet, held where they are, with the player
## put right before them (so they are the one to talk to).
func _stand_before_someone() -> Pedestrian:
	await physics_frames(120)
	var person: Pedestrian = null
	for someone: Pedestrian in _walkers().people():
		# (someone plain, on foot and there: not a rider, not lying down, not just changing)
		if not someone.has_meta(Conversations.GAVE_META) and someone.mobility == "" and someone.role == "" \
				and someone._ragdoll == null and someone._waiting_become.is_empty() and someone.is_inside_tree():
			person = someone
			break
	if person == null:
		return null
	person._pause = 100.0
	player.global_position = person.global_position + Vector3(1.2, 0.0, 0.0)
	await physics_frames(10)
	# someone else plain who walked up closer meanwhile is the one the player talks to: then
	# that one (the town is busy)
	var partner: Variant = player._talk_partner
	if partner is Pedestrian and partner != person and partner.mobility == "" and partner.role == "" \
			and partner._ragdoll == null and not partner.has_meta(Conversations.GAVE_META):
		person._pause = 0.0
		partner._pause = 100.0
		return partner
	return person


## The player talking to a passer-by, the story box open on the greeting typed out;
## returns who (null if no one could be found).
func _start_talk() -> Pedestrian:
	var person := await _stand_before_someone()
	if person == null:
		return null
	player.talk_to(person)
	await frames(1)
	hud._story_box._typewriter.finish()
	await frames(4)
	return person


## The conversation over and the passer-by walking on again.
func _end_talk(person: Pedestrian) -> void:
	StoryBoxHelp.close(hud._story_box)
	if person and is_instance_valid(person):
		person._pause = 0.0
	await frames(1)


## Every persona of voorbijgangers.json has all its lines.
func test_every_persona_is_complete(test) -> void:
	for persona: String in Conversations.personas():
		var data: Dictionary = Conversations.personas()[persona]
		var complete := true
		for key: String in ["spreker", "begroetingen", "onderwerp", "kleingeld_ja", "kleingeld_nee", "dag", "gulheid"]:
			complete = complete and data.has(key)
		test.check(complete, "persona %s compleet" % persona)


## Every voice has a babble sound for every mood.
func test_every_babble_sound_is_there(test) -> void:
	var missing: Array[String] = []
	for mood: String in Babble.MOODS:
		for voice: String in Babble.VOICES:
			var sound_name := "brabbel_%s_%s_1" % [voice, mood]
			if not ResourceLoader.exists(Babble.SoundFiles.path_of(sound_name)):
				missing.append(sound_name)
	test.check(missing.is_empty(), "alle brabbelgeluiden er%s" % ("" if missing.is_empty() else " (geen %s)" % ", ".join(missing)))


## Lying asleep with their back to the camera, the player gets up facing it.
func test_player_wakes_facing_the_camera(test) -> void:
	var to_camera := tree.root.get_camera_3d().global_position - player.global_position
	player.rotation.y = atan2(-to_camera.x, -to_camera.z)
	player._fall_asleep()
	player._wake_up()
	await wait_until(func() -> bool: return not player._sleeping, 10.0)
	to_camera = tree.root.get_camera_3d().global_position - player.global_position
	var woke_facing := Vector2(sin(player.rotation.y), cos(player.rotation.y))
	test.check(woke_facing.dot(Vector2(to_camera.x, to_camera.z).normalized()) > 0.9, "na het opstaan met het gezicht naar de camera")


## The town has several kinds of people, and everyone is something you can see ("OUDE
## DAME", "MAN MET HOED"), never just a passer-by.
func test_town_has_different_people_each_with_a_description(test) -> void:
	await physics_frames(120)
	var personas := {}
	var names := {}
	var nameless := 0
	for someone: Pedestrian in _walkers().people():
		var persona_id := Conversations.persona_of(someone)
		personas[persona_id] = true
		var shown := Conversations.name_of(someone, Conversations.personas().get(persona_id, {}))
		if shown == "" or shown == "VOORBIJGANGER":
			nameless += 1
		names[shown] = names.get(shown, 0) + 1
	print("personas in de stad: ", personas.keys())
	print("namen in de stad: ", names)
	test.check(personas.size() >= 4, "verschillende soorten mensen (%d)" % personas.size())
	test.check(nameless == 0 and names.size() >= 5, "iedereen heeft een beschrijving (%d soorten namen, %d zonder)" % [names.size(), nameless])


## A passer-by of a kind (crowd_kind) talks as the persona of that kind.
func test_conversation_fits_the_kind_of_person(test) -> void:
	await physics_frames(120)
	var kinds_fit := true
	for someone: Pedestrian in _walkers().people():
		if someone.crowd_kind != "" and someone.role == "" and someone.mobility == "":
			var persona_id := Conversations.persona_of(someone)
			var rules: Dictionary = Conversations.personas().get(persona_id, {}).get("herkennen", {})
			if str(rules.get("soort", "")) != someone.crowd_kind:
				kinds_fit = false
				print("past niet: %s praat als %s" % [someone.crowd_kind, persona_id])
	test.check(kinds_fit, "het gesprek past bij de soort mens")


## Someone on duty as a police officer in the street talks as the police (an official).
func test_officer_in_the_street_talks_as_police(test) -> void:
	await physics_frames(120)
	var officer: Pedestrian = _walkers().people()[1]
	var role_before := officer.role
	var kind_before := officer.crowd_kind
	officer.role = "agent"
	officer.crowd_kind = "agent"
	var police := Conversations.new(officer, player, hud)
	test.check(Conversations.is_official(officer) and police.speaker() == "POLITIE" and police.official_style().get("emblem") == "POLITIE",
		"een agent op straat praat als politie")
	officer.role = role_before
	officer.crowd_kind = kind_before


## Near someone the HUD offers "[E] Praten"; talking stops them standing straight, opens
## the story box and pauses the game, and they turn to the player.
func test_near_someone_you_can_talk_and_they_stop_for_it(test) -> void:
	var person := await _stand_before_someone()
	test.check(person != null and player._talk_partner == person, "iemand in de buurt om mee te praten")
	if person == null:
		return
	test.check(hud._action_prompts.visible and hud._action_prompts.actions() == [["E", "Praten"]], "[E] Praten linksonder")
	player.talk_to(person)
	var body: Node3D = person.figure.get("_body")
	test.check(person.get("_walking") == 0.0 and body != null and body.position.is_zero_approx(),
		"de voorbijganger staat stil en recht (geen been in de lucht)")
	await frames(1)
	test.check(hud._story_box.is_showing() and tree.paused, "gesprek open, spel staat stil")
	await seconds(0.6)
	var to_player: Vector3 = (player.global_position - person.global_position)
	var facing := Vector3(sin(person.rotation.y), 0.0, cos(person.rotation.y))
	test.check(facing.dot(Vector3(to_player.x, 0.0, to_player.z).normalized()) > 0.95, "de ander draait naar de speler")
	await _end_talk(person)


## The greeting of a passer-by: choices, no official's emblem, a voice and a mood, babble
## while it types, the body moving with the mood, and the live portrait of who you talk to.
func test_greeting_has_choices_voice_mood_and_a_live_portrait(test) -> void:
	var person := await _stand_before_someone()
	test.check(person != null, "iemand om mee te praten")
	if person == null:
		return
	player.talk_to(person)
	await frames(1)
	var box: Node = hud._story_box
	var page := StoryBoxHelp.page(box)
	print("%s: %s  %s" % [page.speaker, page.text, page.choices])
	test.check(page.kind == "gesprek" and page.choices.size() >= 3, "met keuzes")
	test.check(not page.has("official") and not box._emblem.visible, "een voorbijganger is geen personeel (geen embleem, gewoon naamkaartje)")
	test.check(page.has("voice") and page.has("mood"), "met stem en stemming (%s, %s)" % [page.get("voice"), page.get("mood")])
	await frames(20)
	test.check(is_instance_valid(box._babble), "brabbelt tijdens het typen")
	var emote: Node = person.get_node_or_null("Emotie")
	test.check(emote != null and emote.mood == page.mood, "lichaam beweegt met de stemming")
	test.check(box._portrait != null and box._portrait.townsfolk_look == person.figure.look and box._portrait.townsfolk_figure() != null, "gesprekspartner in het portret")
	test.check(box._portrait.source_figure == person.figure and box._portrait.townsfolk_figure().has_face() and box._portrait.speaking == not box._typewriter.is_done(), "portret van de voorbijganger leeft en praat mee")
	await _end_talk(person)


## During a conversation the camera zooms in calmly, though the game is paused.
func test_camera_zooms_in_while_talking(test) -> void:
	var person := await _stand_before_someone()
	test.check(person != null, "iemand om mee te praten")
	if person == null:
		return
	var follow: Node = scene.get_node("Volgcamera")
	player.talk_to(person)
	await frames(21)
	var zoom_before: float = follow._zoom
	await seconds(2.5)
	print("zoom: %.1f -> %.1f m (aankomst %s, talk_zoom %.1f, snelheid %.2f)" % [zoom_before, follow._zoom, follow._arriving, follow.talk_zoom, follow._zoom_velocity])
	test.check(follow._zoom < zoom_before - 1.0 and follow._zoom > follow.talk_zoom, "camera zoomt rustig in, ook met het spel stil")
	await _end_talk(person)


## The choices stand to the right of the conversation, as wide as their column and as big
## as the text; choosing one out of view scrolls them along.
func test_choices_stand_beside_the_conversation(test) -> void:
	var person := await _start_talk()
	test.check(person != null, "iemand om mee te praten")
	if person == null:
		return
	var box: Node = hud._story_box
	test.check(box._choices_scroll.visible and box._choices_box.visible, "keuzes rechts in beeld")
	test.check(box._choices_scroll.position.x >= box._scroll.position.x + box._scroll.size.x, "keuzes naast het gesprek")
	var narrowest := INF
	for line: Label in box._choice_labels:
		narrowest = minf(narrowest, line.size.x)
	test.check(narrowest > box._choices_scroll.size.x * 0.8, "keuzes zo breed als hun vak (%.0f van %.0f px)" % [narrowest, box._choices_scroll.size.x])
	test.check(is_equal_approx(box._portrait_frame.size.y, box.BOX_HEIGHT), "venster blijft even hoog")
	var room: float = box._choices_box.size.y - box._choices_scroll.size.y
	if room > 1.0:
		box._choose(box._choice_labels.size() - 1)
		await frames(2)
		test.check(box._choices_scroll.scroll_vertical > 0, "kiezen scrolt de keuzes mee (%d px)" % box._choices_scroll.scroll_vertical)
		box._choose(0)
		await frames(2)
	print("keuzes passen %s (%.0f px over)" % ["niet" if room > 1.0 else "wel", maxf(room, 0.0)])
	var first_line: Label = box._choice_labels[0]
	test.check(first_line.get_theme_font_size("font_size") == box.TEXT_SIZE, "keuzes even groot als de tekst")
	await _end_talk(person)


## Asking for change: an amount given rises over the open box, the whole reply comes in
## view, what was said stays above it, and you cannot ask the same person again.
func test_asking_for_change_once_per_person(test) -> void:
	var person := await _start_talk()
	test.check(person != null, "iemand om mee te praten")
	if person == null:
		return
	var box: Node = hud._story_box
	var page := StoryBoxHelp.choose(box, Conversations.question("kleingeld"))
	print("  kleingeld: ", page.text)
	# given: the amount rises over the open box (as a coin picked up), not under its dimming
	var over_story: Array = hud._numbers_over_story._numbers
	print("  getal boven het vak: %d (0: deze gaf niets)" % over_story.size())
	if not over_story.is_empty():
		test.check(str((over_story[0].label as Label).text).begins_with("+€"), "het bedrag boven het gesprek")
		test.check(hud._numbers_over_story.get_index() > box.get_index(), "getekend over het verhaalvak")
	await StoryBoxHelp.typed_out_and_settled(tree, box)
	var reply := StoryBoxHelp.reply_in_view(box)
	test.check(box._text.text != "" and reply.in_view, "na de keuze de hele nieuwe reactie in beeld (%.0f..%.0f px in 0..%.0f)" % [reply.top, reply.bottom, reply.view_height])
	test.check(box._history_text.visible and box._history_text.text.contains(Conversations.question("kleingeld")), "wat gezegd is blijft staan")
	test.check(not (page.choices as Array).has(Conversations.question("kleingeld")), "kleingeld niet nog eens vragen")
	test.check(person.has_meta(Conversations.GAVE_META), "eens per persoon")
	await _end_talk(person)


## A line typing out stays in view as it goes (the box scrolls along), and after one more
## choice the newest reply is still all in view.
func test_what_types_out_stays_in_view(test) -> void:
	var person := await _start_talk()
	test.check(person != null, "iemand om mee te praten")
	if person == null:
		return
	var box: Node = hud._story_box
	StoryBoxHelp.choose(box, Conversations.question("kleingeld"))
	await StoryBoxHelp.typed_out_and_settled(tree, box)
	# a new line typing out: the part that has appeared stays in view as it goes
	box._choose(0)
	box._say_choice()
	var typed_in_view := true
	for sample_index in 40:
		await seconds(0.05)
		var typed_bottom: float = box._text.position.y + box._text.size.y * box._typewriter.shown_share() - box._scroll.scroll_vertical
		if box._typewriter.shown_share() > 0.2 and typed_bottom > box._scroll.size.y + box.TEXT_SIZE * 2.0:
			typed_in_view = false
	test.check(typed_in_view, "wat uittypt blijft in beeld (scrolt mee)")
	# another question: the history longer, the newest line still all in view
	box._typewriter.finish()
	box._choose(0)
	box._say_choice()
	await seconds(0.3)
	box._typewriter.finish()
	await seconds(0.3)
	var view: Rect2 = box._scroll.get_global_rect()
	var reply: Rect2 = box._text.get_global_rect()
	test.check(view.grow(1.0).encloses(reply), "ook na nog een keuze de nieuwste reactie helemaal in beeld")
	await _end_talk(person)


## Saying goodbye closes the box and lets the game go on, the passer-by as they were
## (no mood moves left).
func test_goodbye_closes_the_conversation(test) -> void:
	var person := await _start_talk()
	test.check(person != null, "iemand om mee te praten")
	if person == null:
		return
	var box: Node = hud._story_box
	var emote: Node = person.get_node_or_null("Emotie")
	var rest: Transform3D = emote._rest if emote else Transform3D.IDENTITY
	test.check(emote != null, "tijdens het gesprek beweegt het lichaam met de stemming")
	var page := StoryBoxHelp.choose(box, Conversations.question("dag"))
	print("  dag: ", page.text)
	box._typewriter.finish()
	box._next_page()
	var emote_after: Node = person.get_node_or_null("Emotie")
	test.check((emote_after == null or emote_after.is_queued_for_deletion()) and person.figure.transform.is_equal_approx(rest), "daarna weer gewoon")
	await frames(1)
	test.check(not box.is_showing() and not tree.paused, "na het afscheid dicht, spel gaat door")
	await _end_talk(person)


## For every persona of voorbijgangers.json: its longest answer (over all its conversations,
## with the longest "nog iets" after it) as the reply to a choice, after a greeting (so
## there is history above it); typed out and settled, the reply is in view (its end at
## least, when it is taller than the box).
func test_longest_reply_of_every_persona_fits_in_view(test) -> void:
	var box: Node = hud._story_box
	var longest_again := ""
	for again: Variant in Conversations.street().get("nog_iets", ["Nog iets?"]):
		if str(again).length() > longest_again.length():
			longest_again = str(again)
	var cut_off: Array[String] = []
	for persona: String in Conversations.personas():
		var data: Dictionary = Conversations.personas()[persona]
		var longest := ""
		for variant: Dictionary in Conversations.variants_of(data):
			var reply_texts: Array = []
			for answer_texts: Array in Conversations.answers_in(variant.get("onderwerp", {})):
				reply_texts.append_array(answer_texts)
			for line_kind: String in ["kleingeld_ja", "kleingeld_nee"]:
				var line: Variant = variant.get(line_kind, "")
				reply_texts.append_array(line if line is Array else [line])
			for reply_text: Variant in reply_texts:
				var with_again := str(reply_text) + " " + longest_again
				if with_again.length() > longest.length():
					longest = with_again
		var greeting := str((data.get("begroetingen", ["Hé."]) as Array)[0])
		var choices := [Conversations.question("kleingeld"), Conversations.question("dag")]
		var reply_page := {"kind": "gesprek", "speaker": str(data.get("spreker", "")), "text": longest, "choices": choices,
			"voice": "man", "mood": "neutraal", "on_choice": func(_index: int) -> Array: return []}
		box.show_pages([{"kind": "gesprek", "speaker": str(data.get("spreker", "")), "text": greeting, "choices": choices,
			"voice": "man", "mood": "neutraal", "on_choice": func(_index: int) -> Array: return [reply_page]}])
		box._typewriter.finish()
		box._say_choice()
		await StoryBoxHelp.typed_out_and_settled(tree, box)
		var reply := StoryBoxHelp.reply_in_view(box)
		print("  %-14s %3d tekens: %.0f..%.0f px in 0..%.0f" % [persona, longest.length(), reply.top, reply.bottom, reply.view_height])
		if not reply.in_view:
			cut_off.append(persona)
		StoryBoxHelp.close(box)
		await frames(1)
	test.check(cut_off.is_empty(), "het langste antwoord van elke voorbijganger helemaal in beeld (%s)" % ("alle %d" % Conversations.personas().size() if cut_off.is_empty() else "afgesneden: " + ", ".join(cut_off)))
