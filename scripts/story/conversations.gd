extends RefCounted
## Talking to someone (a passer-by: Pedestrian; someone in an interior: InteriorPerson;
## PlayerController.talk_to): a little conversation tree in the story box
## (scripts/ui/story_box.gd, pages of kind "gesprek" with "choices").
## Everything said comes from data files you can change and add to (see data/LEESMIJ.md):
## - data/gesprekken/voorbijgangers.json: who you talk to (`persona`: the first of "personen"
##   whose "herkennen" fits how they look: "vervoer" (rolstoel, scootmobiel), "haar" (kort,
##   lang, kaal, pet), "rok" (true/false), "jas" (colours); none: it fits anyone), their
##   greetings, their own topic and its follow-up, asking for some change (now and then they
##   give some: "gulheid", once per person, counted for the missions as found money; only
##   once the story has unlocked "bedelen", may_beg: mission 1 after the deposit), the
##   way to the snack bar and goodbye; the questions you can ask ("vragen") and the mood of
##   each kind of line ("stemmingen", a person's own over them).
## - data/gesprekken/snackbarhouder.json: behind the counter of a snack bar (InteriorPerson
##   `role` "snackbarhouder") it is the shop: the "menu" (item, what you ask, price), bought
##   with the player's money (PlayerController.buy), a tip; data/gesprekken/winkels.json: the
##   sellers in the shops of Den Haag Centraal (`role` "verkoper", or "snackbarhouder" at
##   Smikkels; the metadata "kind" picks the shop), the same fields, the snack bar's for what a
##   shop leaves out (shop_data_of). Someone who sells (is_merchant) is talked to in the shop
##   screen (scripts/ui/shop_screen.gd: GameHud.show_shop), which asks this for the greeting,
##   the goods, buying (shop_buy), the tip and goodbye.
## - data/gesprekken/personeel.json: people on duty (`role` "conducteur" or "handhaver":
##   StationPerson, Den Haag Centraal) talk as they do there, the same fields as a passer-by,
##   never give change, and are shown as officials in the story box (page "official": their
##   title on a name plate of their own colours, an emblem on the portrait, a lower voice).
##   A fare dodger talking to the conductor chasing them is caught: "betrapt", and the fine
##   (the station's fine_the_player); for not checking out (chase_reason "uitchecken")
##   "betrapt_uitchecken" when there is one.
## Variants ("varianten" of a person, a shop or someone on duty): other conversations for the
## same kind of person, each overriding some fields (another topic, other lines); every person
## gets one of them (or the base) at random the first time you talk to them and keeps it
## (VARIANT_META), so two people of the same kind can say quite different things.
## A topic ("onderwerp") is a little tree: after its "antwoord" you can ask its "doorvraag"
## (answered by "doorantwoord") and/or one of its "verder" (each {"vraag", "antwoord",
## "stemming", "verder"}, as deep as you like); lines may be a list, one is picked at random.
## A node may have a "gevolg" (what its answer brings about, _consequence): "missie:<id>" starts
## that mission (a task, a side quest: Story.start_from_conversation, after the conversation);
## anything else is handed to the person's meta "talk_consequence" ("doorverwezen" at a counter
## of the city hall: a new number and another clerk).
## A node may hold a "beloning" (_reward_for): now and then they give you something that fits
## what they just said (a sandwich, a can, food; very rarely a bank card they found), with
## some experience (its "xp", else REWARD_XP); shown in the reward screen once the
## conversation is over (GameHud.show_reward: the item big and turning, its jingle).
## Asked topics are not offered again; goodbye ends it. Every line has a mood: they babble
## in it, in their voice (Babble, the story box) and their body moves with it (Emote: angry
## shakes, happy hops, sad leans forward); `finish` puts them back as they were.
##   var talk := Conversations.new(person, player, hud)
##   hud.show_story(talk.opening(), talk.finish)      # or, for a seller: hud.show_shop(talk, ...)

const Emote = preload("res://scripts/world/people/emote.gd")
const Interiors = preload("res://scripts/world/interiors/interiors.gd")
const STREET_FILE := "res://data/gesprekken/voorbijgangers.json"
const COUNTER_FILE := "res://data/gesprekken/snackbarhouder.json"
const COUNTER_PERSONA := "snackbarhouder"
const SHOPS_FILE := "res://data/gesprekken/winkels.json"
## The roles (InteriorPerson.role) of who sells: talked to in the shop screen.
const MERCHANT_ROLES := ["snackbarhouder", "verkoper"]
const STAFF_FILE := "res://data/gesprekken/personeel.json"
## The people of the story (Ome Wim, ...): data/gesprekken/personages.json, read once. Someone
## with the meta CHARACTER_META is that character (scripts/story/characters.gd); which of its
## conversations it has now is the meta TALK_META (the story sets it per step).
const CHARACTERS_FILE := "res://data/gesprekken/personages.json"
const CHARACTER_META := "personage"
const TALK_META := "gesprek"
## Skill checks the player passed (a list of ids), kept on the player: never asked again.
const PASSED_CHECKS_META := "geslaagde_checks"
## The roles (StationPerson.role) of who is on duty: their own conversation and look.
## Who is on duty and has a conversation of their own in personeel.json (shown as such: the
## name plate in their colours, their emblem): the NS and enforcement at Den Haag Centraal,
## the staff of the supermarkets, the people of the city hall.
const OFFICIAL_ROLES := ["conducteur", "handhaver", "agent", "medewerker_derrek", "medewerker_alfred_steyhn",
	"receptioniste", "beveiliger", "ambtenaar", "loketmedewerker", "raadslid", "burgemeester"]
## Who you talk to when nothing else fits, and the mood of a line with none set.
const FALLBACK_PERSONA := "forens"
const FALLBACK_MOOD := "neutraal"
const GAVE_META := "gaf_kleingeld"
## Which conversation (0: the base, n: "varianten"[n - 1]) a person was given, kept on them.
const VARIANT_META := "gesprek_variant"
## Set on someone once they have had their chance at giving a reward ("beloning").
const REWARD_META := "gaf_beloning"
## The experience a reward of a conversation brings when its "beloning" says no "xp".
const REWARD_XP := 25
const ItemTable = preload("res://scripts/player/items.gd")
const DepositReturn = preload("res://scripts/world/things/deposit_return.gd")
## The player's method that gives a new lost bank card (its own balance, PIN and riddle).
const BANK_CARD_METHOD := "give_found_bank_card"
## Hair that makes someone look old (TownsfolkFigure.HAIRS: grey, white).
const GREY_HAIRS := [Color("#8A8680"), Color("#D8D4CC")]
## At the station everything costs at least this many times the town's price (station_menu).
const STATION_MARKUP := 1.3
const MONEY_COLOUR := Color("#E8B83A")
const CHECK_PASSED_COLOUR := Color("#8BE36B")
const CHECK_FAILED_COLOUR := Color("#FF4D5E")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")

static var _street := {}
static var _counter := {}
static var _shops := {}
static var _staff := {}
static var _characters := {}

var persona := FALLBACK_PERSONA
var person: Node3D
var player: Node
var hud: Node
var _asked := {}
var _random := RandomNumberGenerator.new()
## A conversation that holds on ("klampt_vast", the telephone sellers): no goodbye, no begging;
## a branch that ends begins again ("opnieuw" + the first choices of the topic); only a check
## passed lets go (its "gelukt" is the last word).
var _let_go := false
## The lines of this conversation: the person's data with their variant over it (_data).
var _chosen_data := {}


func _init(talking_to: Node3D, the_player: Node, the_hud: Node) -> void:
	person = talking_to
	player = the_player
	hud = the_hud
	persona = persona_of(talking_to)
	if is_merchant(talking_to) or is_official(talking_to):
		persona = str(talking_to.get("role"))
	_random.randomize()


# ------------------------------------------------------------------ the data

## The street conversations (data/gesprekken/voorbijgangers.json), read once.
static func street() -> Dictionary:
	if _street.is_empty():
		_street = _read(STREET_FILE)
	return _street


## Behind the counter (data/gesprekken/snackbarhouder.json), read once.
static func counter() -> Dictionary:
	if _counter.is_empty():
		_counter = _read(COUNTER_FILE)
	return _counter


## The shops of Den Haag Centraal (data/gesprekken/winkels.json), read once.
static func shops() -> Dictionary:
	if _shops.is_empty():
		_shops = _read(SHOPS_FILE)
	return _shops


## The people of the story (data/gesprekken/personages.json "personen": id -> data), read once.
static func characters() -> Dictionary:
	if _characters.is_empty():
		_characters = _read(CHARACTERS_FILE)
	return _characters.get("personen", {})


## The people on duty (data/gesprekken/personeel.json), read once.
static func staff() -> Dictionary:
	if _staff.is_empty():
		_staff = _read(STAFF_FILE)
	return _staff


## True for someone on duty (a conductor, an enforcement officer) with a conversation of
## their own in personeel.json.
static func is_official(someone: Node) -> bool:
	if someone == null:
		return false
	var role := str(someone.get("role"))
	return role in OFFICIAL_ROLES and (staff().get("personen", {}) as Dictionary).has(role)


## Reads them again (after changing the files, while the game runs).
static func reload() -> void:
	_characters = {}
	_staff = {}
	_street = {}
	_counter = {}
	_shops = {}


static func _read(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		push_error("conversations: %s is no valid JSON (%s)" % [path, "leeg" if text.is_empty() else "fout in het bestand"])
		return {}
	return data


## Every kind of passer-by, by id.
static func personas() -> Dictionary:
	var found := {}
	for entry: Dictionary in street().get("personen", []):
		found[str(entry.get("id", ""))] = entry
	return found


## A question you can ask ("kleingeld", "dag").
static func question(key: String) -> String:
	return str((street().get("vragen", {}) as Dictionary).get(key, ""))


## Who `someone` is to talk to: the id of the first person of the data whose "herkennen"
## fits who it is (its kind of person in the crowd, data/drukte.json "mensen") and how it
## looks (see the top).
static func persona_of(someone: Node) -> String:
	if someone == null:
		return FALLBACK_PERSONA
	if someone.has_meta(CHARACTER_META):
		return str(someone.get_meta(CHARACTER_META))
	var traits := traits_of(someone)
	for entry: Dictionary in street().get("personen", []):
		if _fits(entry.get("herkennen", {}), traits):
			return str(entry.get("id", FALLBACK_PERSONA))
	return FALLBACK_PERSONA


## What can be seen of `someone`, for "herkennen" and "namen": {"soort" (its kind of person
## in the crowd, "" when none), "vervoer" (what it rides), "haar" (hair style), "rok", "vrouw"
## (long hair or a skirt), "grijs" (grey or white hair), "draagt" (what it carries), "jas"
## (the coat's colour)}.
static func traits_of(someone: Node) -> Dictionary:
	var figure: Node = someone.get("figure") if someone else null
	var look: Dictionary = figure.get("look") if figure and figure.get("look") is Dictionary else {}
	var hair_style := str(look.get("hair_style", "kort"))
	var hair: Color = look.get("hair", Color.BLACK)
	var skirt := bool(look.get("skirt", false))
	return {
		"soort": str(someone.get("crowd_kind")) if someone and someone.get("crowd_kind") != null else "",
		"vervoer": str(someone.get("mobility")) if someone and someone.get("mobility") != null else "",
		"haar": hair_style,
		"rok": skirt,
		"vrouw": hair_style == "lang" or skirt,
		"grijs": GREY_HAIRS.any(func(grey: Color) -> bool: return hair.is_equal_approx(grey)),
		"draagt": str(someone.get("carried")) if someone and someone.get("carried") != null else "",
		"jas": look.get("coat", Color.WHITE),
	}


## Whether `traits` (traits_of) fit `rules`: every rule must hold. Rules: "soort", "vervoer",
## "haar", "draagt" (one value or a list of them), "rok", "vrouw", "grijs" (true/false), "jas"
## (a colour or a list). Someone riding fits only rules that name its "vervoer".
static func _fits(rules: Dictionary, traits: Dictionary) -> bool:
	if not rules.has("vervoer") and str(traits.vervoer) != "":
		return false
	for key: String in rules:
		var wanted: Variant = rules[key]
		match key:
			"soort", "vervoer", "haar", "draagt":
				var values: Array = wanted if wanted is Array else [wanted]
				if not values.has(str(traits.get(key, ""))):
					return false
			"rok", "vrouw", "grijs":
				if bool(wanted) != bool(traits.get(key, false)):
					return false
			"jas":
				var coat: Color = traits.jas
				var colours: Array = wanted if wanted is Array else [wanted]
				if not colours.any(func(colour: Variant) -> bool: return coat.is_equal_approx(Color(str(colour)))):
					return false
	return true


## The name above what someone says: what they look like ("OUDE DAME", "MAN MET HOED",
## "ZAKENVROUW MET ROLKOFFER"): the first of the person's own "namen", then of the general
## "namen" of voorbijgangers.json, whose "als" fits them (traits_of); else its "spreker".
static func name_of(someone: Node, data: Dictionary) -> String:
	var traits := traits_of(someone)
	var choices: Array = data.get("namen", []) + street().get("namen", [])
	for choice: Dictionary in choices:
		if _fits(choice.get("als", {}), traits):
			return str(choice.get("naam", ""))
	return str(data.get("spreker", ""))


## The lines of this conversation: the base data of who you talk to with the variant they
## were given over it (variants_of, VARIANT_META), chosen once.
func _data() -> Dictionary:
	if not _chosen_data.is_empty():
		return _chosen_data
	var base: Dictionary
	if is_shop():
		base = shop_data_of(person)
	elif persona in OFFICIAL_ROLES:
		base = (staff().get("personen", {}) as Dictionary).get(persona, {})
	elif characters().has(persona):
		base = character_talk(persona, str(person.get_meta(TALK_META, "")) if person else "")
	else:
		base = personas().get(persona, personas().get(FALLBACK_PERSONA, {}))
	var variants := variants_of(base)
	var variant_index := -1
	if person and person.has_meta(VARIANT_META):
		variant_index = int(person.get_meta(VARIANT_META))
	if variant_index < 0 or variant_index >= variants.size():
		variant_index = _random.randi() % variants.size()
		if person:
			person.set_meta(VARIANT_META, variant_index)
	_chosen_data = variants[variant_index]
	return _chosen_data


## The conversation of character `who` (personages.json) called `key` (its "gesprekken"; "" or
## unknown: its "standaard"), with what the character says in all of them ("spreker",
## "stemmingen", "dag", "kleingeld_ja", "kleingeld_nee", "gulheid", "nog_iets") under it.
static func character_talk(who: String, key: String) -> Dictionary:
	var data: Dictionary = characters().get(who, {})
	var talks: Dictionary = data.get("gesprekken", {})
	if not talks.has(key):
		key = str(data.get("standaard", ""))
	var talk: Dictionary = (talks.get(key, {}) as Dictionary).duplicate()
	for field in ["spreker", "stemmingen", "begroetingen", "dag", "kleingeld_ja", "kleingeld_nee", "gulheid", "nog_iets"]:
		if data.has(field) and not talk.has(field):
			talk[field] = data[field]
	return talk


## Every conversation someone with `base` data can have: the base itself, then each of its
## "varianten" laid over it (a field of the variant replaces the base's; "stemmingen" are
## merged, the variant's winning).
static func variants_of(base: Dictionary) -> Array:
	var variants: Array = [base]
	for override: Variant in base.get("varianten", []):
		if not override is Dictionary:
			continue
		var merged := base.duplicate()
		merged.erase("varianten")
		for field: String in override:
			merged[field] = override[field]
		if override.has("stemmingen"):
			var moods: Dictionary = (base.get("stemmingen", {}) as Dictionary).duplicate()
			moods.merge(override["stemmingen"], true)
			merged["stemmingen"] = moods
		variants.append(merged)
	return variants


## A line of the data: a text, or a list of texts of which one is picked at random.
func _pick(value: Variant, fallback := "") -> String:
	if value is Array:
		return str(value[_random.randi() % value.size()]) if not value.is_empty() else fallback
	return fallback if value == null else str(value)


## What you can ask after the answer of topic node `node`: its "doorvraag" (as a node with
## "doorantwoord" for its answer) and its "verder", each {"vraag", "antwoord", ...}.
static func follow_ups_of(node: Dictionary) -> Array:
	var follow_ups: Array = []
	if node.has("doorvraag"):
		follow_ups.append({"vraag": node.doorvraag, "antwoord": node.get("doorantwoord", "")})
	for child: Variant in node.get("verder", []):
		if child is Dictionary and (child as Dictionary).has("vraag"):
			follow_ups.append(child)
	return follow_ups


## Every answer in the tree of topic `node` (itself and all follow-ups), each a list of the
## texts it may be: for checks of how long they get.
static func answers_in(node: Dictionary) -> Array:
	var found: Array = []
	if node.has("antwoord"):
		var answer: Variant = node.antwoord
		found.append(answer if answer is Array else [answer])
	for child: Dictionary in follow_ups_of(node):
		found.append_array(answers_in(child))
	return found


## The mood of a kind of line ("begroeting", "onderwerp", "kleingeld_ja", ...): the person's
## own, else the general one, else FALLBACK_MOOD.
func mood_of(line_kind: String) -> String:
	var own: Dictionary = _data().get("stemmingen", {})
	var general: Dictionary = street().get("stemmingen", {}) if not is_shop() else {}
	return str(own.get(line_kind, general.get(line_kind, FALLBACK_MOOD)))


# ------------------------------------------------------------------ the conversation

## The first page: a greeting and what you can say (a seller: only the greeting; the shop
## screen is where you buy).
func opening() -> Array:
	if is_shop():
		var greeting := shop_greeting()
		return [_with_mood({"kind": "gesprek", "speaker": speaker(), "text": greeting.text}, "begroeting")]
	if _is_caught():
		return [_caught_page()]
	return [_page(_pick(_data().get("begroetingen"), "Ja?"), "begroeting")]


## Whether this conversation holds on to you (see _let_go).
func holds_on() -> bool:
	return bool(_data().get("klampt_vast", false)) and not _let_go


## The conversation is over: the body as it was.
func finish() -> void:
	Emote.stop(person)


func _voice() -> String:
	return str(person.call("voice")) if person and person.has_method("voice") else "man"


## Their mood shown and heard on a page (babble, Emote), their look in the portrait.
## `own_mood`: the mood of this very line (a topic node's "stemming"), else that of its kind.
func _with_mood(page: Dictionary, line_kind: String, own_mood := "") -> Dictionary:
	var mood := own_mood if own_mood != "" else mood_of(line_kind)
	page["voice"] = _voice()
	page["mood"] = mood
	var look: Variant = person.get("figure").get("look") if person and person.get("figure") else null
	if look is Dictionary:
		page["portrait_look"] = look
	var figure: Node3D = person.get("figure") if person else null
	if figure:
		page["portrait_figure"] = figure   # the close-up follows its pose (PlayerPortrait)
	page["on_show"] = func() -> void: Emote.start(person, figure, mood)
	if persona in OFFICIAL_ROLES:
		page["official"] = official_style()
	return page


## How the story box shows someone on duty (personeel.json): "emblem" on the portrait,
## "colour" of the frame and cursor, the name plate's "plate" and "plate_text" colours, the
## babble's "pitch". Empty for anyone else.
func official_style() -> Dictionary:
	return official_style_of(persona)


## official_style for someone of `role` (OFFICIAL_ROLES), empty for anyone else.
static func official_style_of(role: String) -> Dictionary:
	if not role in OFFICIAL_ROLES:
		return {}
	var data: Dictionary = (staff().get("personen", {}) as Dictionary).get(role, {})
	if data.is_empty():
		return {}
	var colour := Color(str(data.get("kleur", "#FFB547")))
	return {"emblem": str(data.get("embleem", "")), "colour": colour,
		"plate": Color(str(data.get("naamkaartje", data.get("kleur", "#FFB547")))),
		"plate_text": Color(str(data.get("tekstkleur", "#0B0D1A"))),
		"pitch": float(data.get("stemhoogte", 1.0))}


func _again() -> String:
	var own: Variant = _data().get("nog_iets")
	var lines: Array = own if own is Array else street().get("nog_iets", ["Nog iets?"])
	return str(lines[_random.randi() % lines.size()])


## The conductor who is chasing the player (a fare dodger: the station's is_chasing) is the
## one they talk to.
func _is_caught() -> bool:
	if persona != "conducteur" or person == null:
		return false
	var station: Node = person.get("station")
	return station != null and station.has_method("is_chasing") and station.call("is_chasing", person)


## Caught: the fine (the station's fine_the_player), and the conductor says why.
func _caught_page() -> Dictionary:
	var station: Node = person.get("station")
	# not checked out (the station's chase_reason "uitchecken"): his own line for that
	var reason := String(station.call("chase_reason")) if station.has_method("chase_reason") else "zwartrijden"
	var fine := float(station.call("fine_the_player"))
	var own: Variant = _data().get("betrapt_uitchecken") if reason == "uitchecken" else null
	var text := _pick(own if own != null else _data().get("betrapt"), "Zwartrijden? Dat wordt {boete} boete.").replace("{boete}", _euros(fine))
	return _page(text, "betrapt")


## The page of the person saying `text` (a line of `line_kind`, in `own_mood` when it has one),
## with what you can say next: the follow-ups of the topic node just answered first
## (follow_ups_of), then the topic when not asked yet, change when not asked yet, goodbye.
func _page(text: String, line_kind: String, follow_ups := [], own_mood := "") -> Dictionary:
	var data := _data()
	var topic: Dictionary = data.get("onderwerp", {})
	var options: Array = []
	for follow_up: Dictionary in follow_ups:
		if _check_passed(follow_up):
			continue   # a skill check passed already: not asked again
		options.append(["verder", _question_text(follow_up), follow_up])
	if not _asked.has("onderwerp") and topic.has("vraag"):
		options.append(["onderwerp", str(topic.vraag), topic])
	if not holds_on():
		if not _asked.has("kleingeld") and may_beg():
			options.append(["kleingeld", question("kleingeld"), {}])
		options.append(["dag", question("dag"), {}])
	var texts: Array = options.map(func(option: Array) -> String: return option[1])
	return _with_mood({"kind": "gesprek", "speaker": speaker(), "text": text, "choices": texts,
		"on_choice": func(index: int) -> Array: return _answer(options[index])}, line_kind, own_mood)


func _answer(option: Array) -> Array:
	var data := _data()
	# a conversation that holds on wears you out: every answer a little more overstimulated
	if holds_on() and player and player.has_method("change_stat"):
		player.change_stat("overprikkeldheid", float(data.get("prikkels", 0.0)))
	match str(option[0]):
		"onderwerp", "verder":
			# a node of the topic tree: its answer, then its own follow-ups (none left: the
			# topic is done, "nog iets?")
			var is_topic := str(option[0]) == "onderwerp"
			if is_topic:
				_asked["onderwerp"] = true
			var node: Dictionary = option[2]
			if node.get("check") is Dictionary:
				return [_try_check(node)]
			var follow_ups := follow_ups_of(node)
			var text := _pick(node.get("antwoord"))
			# what the answer brings about ("gevolg"): told to who is talked to (its meta
			# "talk_consequence", a Callable(String): the clerks of the city hall send you on)
			if node.has("gevolg"):
				_consequence(str(node.gevolg))
			var reward_line := _reward_for(node)
			if node.has("koopt_blikjes"):
				reward_line = (reward_line + " " + _buy_cans(node)).strip_edges()
			if reward_line != "":
				text += " " + reward_line
			if follow_ups.is_empty() and not is_topic:
				if holds_on():
					# a dead end: they start all over again
					text += " " + _pick(data.get("opnieuw"), "Maar goed, waar was ik?")
					follow_ups = follow_ups_of(data.get("onderwerp", {}))
				else:
					text += " " + _again()
			return [_page(text, "onderwerp" if is_topic else "doorvraag", follow_ups, str(node.get("stemming", "")))]
		"kleingeld":
			_asked["kleingeld"] = true
			var gave := _ask_for_money()
			# begging counts inside: too much of it and you are thrown out (Interiors)
			if person and person.is_inside_tree():
				Interiors.note_offence(person.get_tree(), "bedelen")
			var line_kind := "kleingeld_ja" if gave else "kleingeld_nee"
			return [_page(_pick(data.get(line_kind)) + " " + _again(), line_kind)]
	# goodbye: their last word, then the box closes
	return [_with_mood({"kind": "gesprek", "speaker": speaker(), "text": _pick(data.get("dag"))}, "dag")]


## What an answer brings about (a node's "gevolg", see the top).
func _consequence(gevolg: String) -> void:
	if gevolg.begins_with("missie:"):
		var story := person.get_tree().get_first_node_in_group("verhaal") if person and person.is_inside_tree() else null
		if story and story.has_method("start_from_conversation"):
			story.start_from_conversation(gevolg.trim_prefix("missie:"))
		return
	if person and person.has_meta("talk_consequence"):
		(person.get_meta("talk_consequence") as Callable).call(gevolg)


## A skill check on a question ("check": {"id", "label", "kans" in 100, "gelukt", "mislukt"}):
## the question shows "[LABEL 50%]" before it (_question_text). Asked, it passes at that
## chance: its "gelukt" answer and its own follow-ups, and the player keeps it
## (PASSED_CHECKS_META: never asked again); failed: its "mislukt" answer, and it can be tried
## again in a later conversation (not in this one). Either way the player says so
## (PlayerController.checked: the story waits for it, Story goal "check").
func _try_check(node: Dictionary) -> Dictionary:
	var check: Dictionary = node.check
	var check_id := str(check.get("id", ""))
	_asked["check:" + check_id] = true
	var passed := _random.randi_range(1, 100) <= int(check.get("kans", 50))
	var holding := holds_on()
	if passed and holding:
		_let_go = true
	if passed and player:
		var passed_checks: Array = player.get_meta(PASSED_CHECKS_META, [])
		passed_checks.append(check_id)
		player.set_meta(PASSED_CHECKS_META, passed_checks)
	if player and player.has_signal("checked"):
		player.emit_signal("checked", check_id, passed)
	if hud and hud.has_method("show_floating_number") and person and not check.get("verborgen", false):
		hud.show_floating_number(person.global_position + Vector3.UP * 2.3,
			"%s %s" % [str(check.get("label", "CHECK")), "GESLAAGD" if passed else "MISLUKT"],
			CHECK_PASSED_COLOUR if passed else CHECK_FAILED_COLOUR, 14, true)
	if passed and holding:
		# let go: their last word, then the box closes
		return _with_mood({"kind": "gesprek", "speaker": speaker(), "text": _pick(check.get("gelukt"), "Goed dan.")}, "dag",
			str(check.get("stemming_gelukt", "")))
	if passed:
		var follow_ups := follow_ups_of(node)
		var text := _pick(check.get("gelukt"), "Goed dan.")
		if follow_ups.is_empty():
			text += " " + _again()
		return _page(text, "doorvraag", follow_ups, str(check.get("stemming_gelukt", "")))
	return _page(_pick(check.get("mislukt"), "Nee.") + " " + _again(), "doorvraag", [], str(check.get("stemming_mislukt", "")))


## Whether `node` is a skill check the player passed already (or tried in this conversation).
func _check_passed(node: Dictionary) -> bool:
	if not node.get("check") is Dictionary:
		return false
	var check_id := str(node.check.get("id", ""))
	if _asked.has("check:" + check_id):
		return true
	return player != null and (player.get_meta(PASSED_CHECKS_META, []) as Array).has(check_id)


## The question of a node as you can choose it: a skill check with its label and chance first.
static func _question_text(node: Dictionary) -> String:
	var text := str(node.get("vraag", ""))
	if node.get("check") is Dictionary and not (node.check as Dictionary).get("verborgen", false):
		var check: Dictionary = node.check
		text = "[%s %d%%] %s" % [str(check.get("label", "CHECK")), int(check.get("kans", 50)), text]
	return text


## A reward of topic node `node` ("beloning": {"item", "kans" in 100, "tekst", "xp"}): once
## per person (REWARD_META) at that chance the item goes in the player's pockets with its
## experience ("xp", else REWARD_XP), quietly (PlayerController.add_item and add_xp), and the
## reward screen shows them once the conversation is closed (GameHud.show_reward); their line
## about it is returned, to follow the answer it belongs to; "" when nothing is given (no
## reward, not this time, no room). "item" "pinpas" is a lost bank card of its own
## (BANK_CARD_METHOD on the player).
func _reward_for(node: Dictionary) -> String:
	var reward: Dictionary = node.get("beloning", {}) if node.get("beloning") is Dictionary else {}
	if reward.is_empty() or person == null or person.has_meta(REWARD_META) or player == null:
		return ""
	if _random.randi_range(1, 100) > int(reward.get("kans", 0)):
		person.set_meta(REWARD_META, true)
		return ""
	var item_id := str(reward.get("item", ""))
	var given := false
	if item_id == "pinpas":
		given = player.has_method(BANK_CARD_METHOD) and bool(player.call(BANK_CARD_METHOD, true))
	elif ItemTable.ITEMS.has(item_id) and player.has_method("has_room_for") and player.call("has_room_for", item_id):
		given = bool(player.call("add_item", item_id, 1, true))
	if not given:
		return ""
	person.set_meta(REWARD_META, true)
	var xp := int(reward.get("xp", REWARD_XP))
	if xp > 0 and player.has_method("add_xp"):
		player.call("add_xp", float(xp), true)
	if hud and hud.has_method("show_reward"):
		var from := speaker()
		hud.show_reward({"heading": "GEKREGEN", "title": "Van " + from if from != "" else "",
			"xp": xp, "items": [{"item": item_id, "count": 1}]})
	return _pick(reward.get("tekst"), "Hier, voor jou.")


## Asked for change: once per person maybe some ("gulheid": "kans" in 100, "bedrag" in
## euros), counted as found money; true if they gave.
func _ask_for_money() -> bool:
	var generosity: Dictionary = _data().get("gulheid", {"kans": 0, "bedrag": 0.0})
	if person.has_meta(GAVE_META) or _random.randi_range(1, 100) > int(generosity.get("kans", 0)):
		person.set_meta(GAVE_META, true)
		return false
	person.set_meta(GAVE_META, true)
	var euros := float(generosity.get("bedrag", 0.0))
	if player and player.has_method("add_money"):
		player.add_money(euros)
	# as a coin picked up (LooseChange): its value rising, over the open box, and the chime
	if hud and hud.has_method("show_floating_number"):
		hud.show_floating_number(person.global_position + Vector3.UP * 2.0, "+" + _euros(euros), MONEY_COLOUR, 18, true)
	UiSounds.play(person, "munt", -2.0)
	return true


# ------------------------------------------------------------------ the shop

## True for someone who sells (InteriorPerson `role` in MERCHANT_ROLES): talking to them
## opens the shop screen (GameHud.show_shop, scripts/ui/shop_screen.gd), not the story box.
static func is_merchant(someone: Node) -> bool:
	return someone != null and str(someone.get("role")) in MERCHANT_ROLES


## What `someone` behind a counter says and sells: the snack bar's (COUNTER_FILE), with over
## it the shop of its kind (SHOPS_FILE "winkels", by the metadata "kind" of a seller in Den
## Haag Centraal) when there is one; a field a shop leaves out is the snack bar's.
static func shop_data_of(someone: Node) -> Dictionary:
	var merged := counter().duplicate()
	var kind := str(someone.get_meta("kind", "")) if someone else ""
	var own: Dictionary = (shops().get("winkels", {}) as Dictionary).get(kind, {})
	merged.merge(own, true)
	if kind != "":
		merged["menu"] = station_menu(merged.get("menu", []))
	return merged


## Everything at the station costs more than in the town (it is the station): a shop of Den
## Haag Centraal asks at least STATION_MARKUP times what the town's snack bar asks for the same
## thing (rounded up to 5 cents); what the town does not sell keeps the price of winkels.json.
static func station_menu(menu: Array) -> Array:
	var town_prices := {}
	for entry: Dictionary in counter().get("menu", []):
		town_prices[str(entry.get("item", ""))] = float(entry.get("prijs", 0.0))
	var result := []
	for entry: Dictionary in menu:
		var priced := entry.duplicate()
		var town_price: float = town_prices.get(str(entry.get("item", "")), 0.0)
		var lowest := ceilf(town_price * STATION_MARKUP * 20.0 - 0.0001) / 20.0
		priced["prijs"] = maxf(float(entry.get("prijs", 0.0)), lowest)
		result.append(priced)
	return result


func is_shop() -> bool:
	return persona in MERCHANT_ROLES


## The name of the shop: the seller's own ("shop_name", Den Haag Centraal), else that of the
## snack bar it stands in (Interior), else "de snackbar".
func shop_name() -> String:
	var own := str(person.get_meta("shop_name", "")) if person else ""
	if own != "":
		return own
	var interior: Node = person.get_parent() if person else null
	var bar_name: Variant = interior.get("snack_bar_name") if interior else null
	return String(bar_name) if bar_name is String and bar_name != "" else "de snackbar"


## What kind of shop it is ("soort": "KIOSK", "SNACKBAR", ...), for the screen's banner.
func shop_kind_label() -> String:
	return str(_data().get("soort", "SNACKBAR"))


## The shop's logo ("logo": "icoon" a pixel icon of the game's menus, "kleur" its board,
## "tekst" the colour of the icon): the board over a stall and the badge on the shop screen.
func shop_logo() -> Dictionary:
	return _data().get("logo", {})


## The name over the conversation: a shop's or official's own "spreker", a passer-by's what
## they look like (name_of).
func speaker() -> String:
	if is_shop() or persona in OFFICIAL_ROLES or characters().has(persona):
		return str(_data().get("spreker", ""))
	return name_of(person, _data())


## The look of who you talk to (a TownsfolkFigure look), empty when unknown.
func look() -> Dictionary:
	var figure: Node = person.get("figure") if person else null
	var figure_look: Variant = figure.get("look") if figure else null
	return figure_look if figure_look is Dictionary else {}


func voice() -> String:
	return _voice()


## Their body moves with the mood of a line (Emote).
func show_mood(mood: String) -> void:
	if person:
		Emote.start(person, person.get("figure"), mood)


## The goods: {"item", "vraag", "prijs", "naam"} each (the "menu" of the data); one with a "slot"
## only once the story has unlocked that ("snackkaart": the snack bar's whole menu after mission 1,
## before that only the kroket).
func shop_goods() -> Array:
	var story: Node = person.get_tree().get_first_node_in_group("verhaal") if person and person.is_inside_tree() else null
	return (_data().get("menu", []) as Array).filter(func(entry: Variant) -> bool:
		return entry is Dictionary and (not entry.has("slot") or story == null or not story.has_method("is_unlocked")
				or bool(story.is_unlocked(str(entry.slot)))))


## A line of the seller: {"text", "mood"}.
func _line(text: String, line_kind: String) -> Dictionary:
	return {"text": text.replace("{zaak}", shop_name()).replace("{snackbar}", shop_name()), "mood": mood_of(line_kind)}


func shop_greeting() -> Dictionary:
	return _line(_pick(_data().get("begroetingen"), "Zeg het maar."), "begroeting")


## Buys good `index` of shop_goods with the player's money (PlayerController.buy): the
## seller's line and "result": "ok" (paid, in the pockets), "geld" (too little money: the
## line names the price) or "vol" (no room in the pockets).
func shop_buy(index: int) -> Dictionary:
	var data := _data()
	var goods := shop_goods()
	if index < 0 or index >= goods.size():
		return {}
	var entry: Dictionary = goods[index]
	var price := float(entry.get("prijs", 0.0))
	var result: String = player.call("buy", str(entry.get("item", "")), price) if player and player.has_method("buy") else "geld"
	var again := " " + _pick(data.get("nog_iets"))
	var line: Dictionary
	match result:
		"ok":
			var lines: Array = data.get("gekocht", ["Alsjeblieft, {wat}."])
			var what := str(entry.get("naam", entry.get("item", "")))
			line = _line(str(lines[_random.randi() % lines.size()]).replace("{wat}", what) + again, "gekocht")
		"vol":
			line = _line(_pick(data.get("zakken_vol")) + again, "zakken_vol")
		_:
			result = "geld"
			line = _line(_pick(data.get("geen_geld")).replace("{prijs}", _euros(price)), "geen_geld")
	line["result"] = result
	return line


## What you can ask (the "tip_vraag"), "" when the shop has no tip.
func shop_tip_question() -> String:
	return str(_data().get("tip_vraag", "")) if _pick(_data().get("tip")) != "" else ""


func shop_tip() -> Dictionary:
	return _line(_pick(_data().get("tip")), "tip")


func shop_goodbye() -> Dictionary:
	return _line(_pick(_data().get("dag"), "Dag!"), "dag")


static func _euros(amount: float) -> String:
	return "€ " + ("%.2f" % amount).replace(".", ",")


## Whether asking for change is an option: not until the story unlocks "bedelen" (Story
## is_unlocked; mission 1 after the cans are handed in). Without a story (a test): always.
func may_beg() -> bool:
	var tree := person.get_tree() if person and person.is_inside_tree() else null
	var story: Node = tree.get_first_node_in_group("verhaal") if tree else null
	return story == null or not story.has_method("is_unlocked") or bool(story.is_unlocked("bedelen"))


## Someone who buys your cans (a node with "koopt_blikjes": euros a can; Blikken Bertus):
## all the cans in your pockets for that, paid out as at a deposit machine
## (DepositReturn.pay_out: PlayerController.deposited, the story's goal "statiegeld"). The
## line after: "gekocht" ({aantal}, {bedrag}), or "geen_blikjes" with none on you.
func _buy_cans(node: Dictionary) -> String:
	var count := int(player.inventory.get("blikje", 0)) if player and player.get("inventory") != null else 0
	if count <= 0:
		return _pick(node.get("geen_blikjes"), "Geen blikjes? Dan heb ik niks voor je.")
	var total := snappedf(count * float(node.koopt_blikjes), 0.01)
	for can_index in count:
		player.call("drop_item", "blikje")
	DepositReturn.pay_out(player, total)
	if hud and hud.has_method("show_floating_number") and person:
		hud.show_floating_number(person.global_position + Vector3.UP * 2.0, "+" + _euros(total), MONEY_COLOUR, 18, true)
	UiSounds.play(person, "munt", -2.0)
	return _pick(node.get("gekocht"), "Alsjeblieft.").replace("{aantal}", str(count)).replace("{bedrag}", _euros(total))
