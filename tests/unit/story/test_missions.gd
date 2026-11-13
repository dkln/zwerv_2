extends RefCounted
## Unit tests of the mission data (data/missies/*.json, scripts/story/story.gd): every mission
## can be read, has what the story needs, its goals are of a kind the story knows, the
## missions it starts after exist, and the areas (data/gebieden.json), the characters
## (data/gesprekken/personages.json) and the items it names are there.

const Story = preload("res://scripts/story/story.gd")
const Shroud = preload("res://scripts/story/shroud.gd")
const Conversations = preload("res://scripts/story/conversations.gd")
const Items = preload("res://scripts/player/items.gd")


## The mission files are found and read, the first two of chapter 1 among them.
func test_the_missions_can_be_read(test) -> void:
	var missions := Story.load_missions()
	test.check(missions.size() >= 1, "missies gevonden (%d)" % missions.size())
	for id in ["missie_1_lege_maag", "missie_2_bekend_gezicht"]:
		test.check(missions.any(func(data: Dictionary) -> bool: return data.id == id), id)


## Every mission has what the story needs, steps with an id and a text, goals of a known
## kind, and only existing missions to start after.
func test_every_mission_is_complete(test) -> void:
	var missions := Story.load_missions()
	var ids := missions.map(func(data: Dictionary) -> String: return str(data.id))
	for data: Dictionary in missions:
		for key in ["id", "titel", "start", "stappen"]:
			test.check(data.has(key), "%s heeft %s" % [data.get("id", "?"), key])
		var start := str(data.get("start", ""))
		test.check(start == "na_proloog" or (start.begins_with("na:") and ids.has(start.trim_prefix("na:"))),
				"%s start na iets dat er is (%s)" % [data.id, start])
		for step: Dictionary in data.get("stappen", []):
			var goal: Dictionary = step.get("doel", {})
			test.check(step.has("id") and step.has("tekst"), "%s: stap met id en tekst" % data.id)
			test.check(Story.GOAL_KINDS.has(str(goal.get("soort", ""))), "%s/%s: een bekend doel (%s)" % [data.id, step.get("id"), goal.get("soort")])
			for what in step.get("ontgrendelt", []):
				test.check(Story.UNLOCKABLE.has(str(what)), "%s/%s: ontgrendelt iets dat op slot kan (%s)" % [data.id, step.get("id"), what])


## The areas a mission opens are in data/gebieden.json, the characters it names in
## personages.json (with every conversation a step asks for), the items it gives in Items.
func test_what_the_missions_name_exists(test) -> void:
	var areas: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(Shroud.AREAS_FILE)) as Dictionary).get("gebieden", {})
	var characters := Conversations.characters()
	for data: Dictionary in Story.load_missions():
		var opened: Array = data.get("opent_na_afloop", []).duplicate()
		var gifts: Array = data.get("geeft", []).duplicate()
		var talks: Dictionary = data.get("gesprekken_na_afloop", {}).duplicate()
		for step: Dictionary in data.get("stappen", []):
			opened.append_array(step.get("opent", []))
			gifts.append_array(step.get("geeft", []))
			talks.merge(step.get("gesprekken", {}), true)
			var who := str(step.get("doel", {}).get("persoon", ""))
			if str(step.get("doel", {}).get("soort", "")) in ["naar_persoon", "begeleiden", "werver"]:
				test.check(characters.has(who), "%s/%s: personage %s bestaat" % [data.id, step.id, who])
		for area in opened:
			test.check(areas.has(str(area)), "%s: gebied %s bestaat" % [data.id, area])
		for gift: Dictionary in gifts:
			test.check(Items.ITEMS.has(str(gift.get("item", ""))), "%s: item %s bestaat" % [data.id, gift.get("item")])
		for who: String in talks:
			var talk_names: Dictionary = characters.get(who, {}).get("gesprekken", {})
			test.check(talk_names.has(str(talks[who])), "%s: %s heeft het gesprek %s" % [data.id, who, talks[who]])


## Every character can be talked to: a greeting, a topic, and a look the town can draw.
func test_every_character_has_its_lines(test) -> void:
	for who: String in Conversations.characters():
		var entry: Dictionary = Conversations.characters()[who]
		test.check(entry.has("spreker") and entry.has("uiterlijk"), "%s: spreker en uiterlijk" % who)
		for key: String in entry.get("gesprekken", {}):
			var talk := Conversations.character_talk(who, key)
			test.check(not (talk.get("begroetingen", []) as Array).is_empty(), "%s/%s: begroeting" % [who, key])
			test.check((talk.get("onderwerp", {}) as Dictionary).has("vraag"), "%s/%s: onderwerp" % [who, key])


## Mission 1 adds up: the cans (four outside, the last two in the station) would be enough at the
## deposit machine, but it is out of order and Blikken Bertus pays less than the kroket at the
## snack cart costs; the begging step asks for just that price.
func test_mission_1_adds_up_to_the_kroket(test) -> void:
	var DepositReturn := load("res://scripts/world/things/deposit_return.gd")
	var data: Dictionary = Story.load_missions().filter(func(found: Dictionary) -> bool: return found.id == "missie_1_lege_maag")[0]
	var steps := {}
	for step: Dictionary in data.stappen:
		steps[str(step.id)] = step
	var cans: Dictionary = steps.get("blikjes", {})
	var wanted := int(cans.get("doel", {}).get("aantal", 0))
	test.check(wanted == 6 and int(cans.get("blikjes_buiten", 0)) == 4 and int(cans.get("blikjes_station", 0)) == 2,
		"zes blikjes: vier buiten, twee in het station (%d)" % wanted)
	var seller: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gesprekken/snackbarhouder.json"))
	var price := 0.0
	for offer: Dictionary in seller.menu:
		if str(offer.item) == "kroket":
			price = float(offer.prijs)
	var deposit := wanted * float(DepositReturn.DEPOSIT.blikje)
	test.check(deposit >= price, "bij de automaat (€ %.2f) zou het genoeg zijn voor de kroket (€ %.2f)" % [deposit, price])
	# the machine is out of order: Blikken Bertus buys them, for less
	var broken: Dictionary = steps.get("statiegeld", {}).get("storing", {})
	var buyer := str(broken.get("persoon", ""))
	var buys: Dictionary = Conversations.characters().get(buyer, {}).get("gesprekken", {}).get("koopt", {}).get("onderwerp", {})
	var at_buyer := wanted * float(buys.get("koopt_blikjes", 0.0))
	test.check(buyer == "bertus" and at_buyer > 0.0 and at_buyer < price,
		"bij Bertus (€ %.2f) is het te weinig voor de kroket: het tekort wordt gebedeld" % at_buyer)
	var begging: Dictionary = steps.get("bedelen", {})
	test.check(str(begging.get("doel", {}).get("soort", "")) == "geld_op_zak" and is_equal_approx(float(begging.doel.get("bedrag", 0.0)), price),
		"bedelen tot de prijs van de kroket op zak")
	test.check(bool(begging.get("verborgen_tot_open", false)) and (begging.get("ontgrendelt", []) as Array).has("bedelen"),
		"de bedelstap: pas in de lijst als hij begint, en dan kun je bedelen")
