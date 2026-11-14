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
## One conversation under way (behaviour, docs/CODE_LAGEN.md): who is talked to, what was
## asked, its random draws, what it does to the player. The files are conversation_data.gd,
## what is said when conversation_rules.gd (logic), what you see and hear of it in the world
## conversations_view.gd (graphics).
##   const Conversations = preload("res://scripts/story/conversations.gd")
##   var talk := Conversations.new(person, player, hud)
##   hud.show_story(talk.opening(), talk.finish)      # or, for a seller: hud.show_shop(talk, ...)

const ConversationData = preload("res://scripts/story/conversation_data.gd")
const ConversationRules = preload("res://scripts/story/conversation_rules.gd")
const ConversationsView = preload("res://scripts/story/conversations_view.gd")
const Interiors = preload("res://scripts/world/interiors/interiors.gd")
const ItemTable = preload("res://scripts/player/items.gd")
const DepositReturn = preload("res://scripts/world/things/deposit_return.gd")
const MoneyText = preload("res://scripts/common/money_text.gd")
const STREET_FILE := ConversationData.STREET_FILE
const COUNTER_FILE := ConversationData.COUNTER_FILE
const COUNTER_PERSONA := ConversationRules.COUNTER_PERSONA
const SHOPS_FILE := ConversationData.SHOPS_FILE
## The roles (InteriorPerson.role) of who sells: talked to in the shop screen.
const MERCHANT_ROLES := ConversationRules.MERCHANT_ROLES
const STAFF_FILE := ConversationData.STAFF_FILE
## The people of the story (Ome Wim, ...): data/gesprekken/personages.json, read once. Someone
## with the meta CHARACTER_META is that character (scripts/story/characters.gd); which of its
## conversations it has now is the meta TALK_META (the story sets it per step).
const CHARACTERS_FILE := ConversationData.CHARACTERS_FILE
const CHARACTER_META := "personage"
const TALK_META := "gesprek"
## Skill checks the player passed (a list of ids), kept on the player: never asked again.
const PASSED_CHECKS_META := "geslaagde_checks"
## The roles of who is on duty with a conversation of their own in personeel.json.
const OFFICIAL_ROLES := ConversationRules.OFFICIAL_ROLES
## Who you talk to when nothing else fits, and the mood of a line with none set.
const FALLBACK_PERSONA := ConversationRules.FALLBACK_PERSONA
const FALLBACK_MOOD := ConversationRules.FALLBACK_MOOD
const GAVE_META := "gaf_kleingeld"
## Which conversation (0: the base, n: "varianten"[n - 1]) a person was given, kept on them.
const VARIANT_META := "gesprek_variant"
## Set on someone once they have had their chance at giving a reward ("beloning").
const REWARD_META := "gaf_beloning"
## The experience a reward of a conversation brings when its "beloning" says no "xp".
const REWARD_XP := ConversationRules.REWARD_XP
## The player's method that gives a new lost bank card (its own balance, PIN and riddle).
const BANK_CARD_METHOD := "give_found_bank_card"
## At the station everything costs at least this many times the town's price (station_menu).
const STATION_MARKUP := ConversationRules.STATION_MARKUP

var persona := FALLBACK_PERSONA
var person: Node3D
var player: Node
var hud: Node
## What is seen and heard of it in the world.
var view: ConversationsView
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
	view = ConversationsView.new(talking_to, the_hud)
	persona = persona_of(talking_to)
	if is_merchant(talking_to) or is_official(talking_to):
		persona = str(talking_to.get("role"))
	_random.randomize()


# ------------------------------------------------------------------ the data

## The street conversations (data/gesprekken/voorbijgangers.json), read once.
static func street() -> Dictionary:
	return ConversationData.street()


## Behind the counter (data/gesprekken/snackbarhouder.json), read once.
static func counter() -> Dictionary:
	return ConversationData.counter()


## The shops of Den Haag Centraal (data/gesprekken/winkels.json), read once.
static func shops() -> Dictionary:
	return ConversationData.shops()


## The people of the story (data/gesprekken/personages.json "personen": id -> data), read once.
static func characters() -> Dictionary:
	return ConversationData.characters()


## The people on duty (data/gesprekken/personeel.json), read once.
static func staff() -> Dictionary:
	return ConversationData.staff()


## True for someone on duty (a conductor, an enforcement officer) with a conversation of
## their own in personeel.json.
static func is_official(someone: Node) -> bool:
	return someone != null and ConversationRules.is_official_role(staff(), str(someone.get("role")))


## Reads them again (after changing the files, while the game runs).
static func reload() -> void:
	ConversationData.reload()


## Every kind of passer-by, by id.
static func personas() -> Dictionary:
	return ConversationRules.personas(street())


## A question you can ask ("kleingeld", "dag").
static func question(key: String) -> String:
	return ConversationRules.question(street(), key)


## Who `someone` is to talk to: a character of the story (CHARACTER_META), else the id of the
## first person of the data whose "herkennen" fits who it is (its kind of person in the
## crowd, data/drukte.json "mensen") and how it looks (see the top).
static func persona_of(someone: Node) -> String:
	if someone == null:
		return FALLBACK_PERSONA
	if someone.has_meta(CHARACTER_META):
		return str(someone.get_meta(CHARACTER_META))
	return ConversationRules.persona_for(traits_of(someone), street())


## What can be seen of `someone`, for "herkennen" and "namen" (ConversationRules.traits).
static func traits_of(someone: Node) -> Dictionary:
	var figure: Node = someone.get("figure") if someone else null
	var look: Dictionary = figure.get("look") if figure and figure.get("look") is Dictionary else {}
	return ConversationRules.traits(look, _text_of(someone, "crowd_kind"), _text_of(someone, "mobility"), _text_of(someone, "carried"))


## A property of `someone` as text; "" when it has none.
static func _text_of(someone: Node, property: String) -> String:
	return str(someone.get(property)) if someone and someone.get(property) != null else ""


## The name above what someone says: what they look like ("OUDE DAME", "MAN MET HOED",
## "ZAKENVROUW MET ROLKOFFER"): the first of the person's own "namen", then of the general
## "namen" of voorbijgangers.json, whose "als" fits them (traits_of); else its "spreker".
static func name_of(someone: Node, data: Dictionary) -> String:
	return ConversationRules.name_for(traits_of(someone), data, street())


## The lines of this conversation: the base data of who you talk to with the variant they
## were given over it (variants_of, VARIANT_META), chosen once.
func _data() -> Dictionary:
	if not _chosen_data.is_empty():
		return _chosen_data
	var variants := variants_of(_base_data())
	var variant_index := int(person.get_meta(VARIANT_META)) if person and person.has_meta(VARIANT_META) else -1
	if not ConversationRules.has_variant(variant_index, variants.size()):
		variant_index = _random.randi() % variants.size()
		if person:
			person.set_meta(VARIANT_META, variant_index)
	_chosen_data = variants[variant_index]
	return _chosen_data


## The data of who you talk to, before its variants: a shop, someone on duty, a character of
## the story or a passer-by.
func _base_data() -> Dictionary:
	if is_shop():
		return shop_data_of(person)
	if persona in OFFICIAL_ROLES:
		return (staff().get("personen", {}) as Dictionary).get(persona, {})
	if characters().has(persona):
		return character_talk(persona, str(person.get_meta(TALK_META, "")) if person else "")
	return personas().get(persona, personas().get(FALLBACK_PERSONA, {}))


## The conversation of character `who` (personages.json) called `key` (its "gesprekken"; "" or
## unknown: its "standaard"), with what the character says in all of them under it.
static func character_talk(who: String, key: String) -> Dictionary:
	return ConversationRules.character_talk(characters(), who, key)


## Every conversation someone with `base` data can have: the base itself, then each of its
## "varianten" laid over it.
static func variants_of(base: Dictionary) -> Array:
	return ConversationRules.variants_of(base)


## A line of the data: a text, or a list of texts of which one is picked at random.
func _pick(value: Variant, fallback := "") -> String:
	return ConversationRules.line(value, _random.randi() if ConversationRules.is_choice(value) else 0, fallback)


## What you can ask after the answer of topic node `node` (ConversationRules.follow_ups_of).
static func follow_ups_of(node: Dictionary) -> Array:
	return ConversationRules.follow_ups_of(node)


## Every answer in the tree of topic `node` (itself and all follow-ups).
static func answers_in(node: Dictionary) -> Array:
	return ConversationRules.answers_in(node)


## The mood of a kind of line ("begroeting", "onderwerp", "kleingeld_ja", ...): the person's
## own, else the general one, else FALLBACK_MOOD.
func mood_of(line_kind: String) -> String:
	var general: Dictionary = street().get("stemmingen", {}) if not is_shop() else {}
	return ConversationRules.mood_of(_data(), general, line_kind)


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
	return ConversationRules.holds_on(_data(), _let_go)


## The conversation is over: the body as it was.
func finish() -> void:
	view.stop_mood()


## Their mood shown and heard on a page (babble, Emote), their look in the portrait.
## `own_mood`: the mood of this very line (a topic node's "stemming"), else that of its kind.
func _with_mood(page: Dictionary, line_kind: String, own_mood := "") -> Dictionary:
	var mood := own_mood if own_mood != "" else mood_of(line_kind)
	page["voice"] = voice()
	page["mood"] = mood
	var figure := view.figure()
	if figure and figure.get("look") is Dictionary:
		page["portrait_look"] = figure.get("look")
	if figure:
		page["portrait_figure"] = figure   # the close-up follows its pose (PlayerPortrait)
	page["on_show"] = func() -> void: view.show_mood(mood)
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
	return ConversationsView.official_style(ConversationRules.official_data(staff(), role))


func _again() -> String:
	var lines := ConversationRules.again_lines(_data(), street())
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
	var text := _pick(ConversationRules.caught_lines(_data(), reason), "Zwartrijden? Dat wordt {boete} boete.")
	return _page(ConversationRules.caught_text(text, MoneyText.euros(fine)), "betrapt")


## The page of the person saying `text` (a line of `line_kind`, in `own_mood` when it has one),
## with what you can say next (ConversationRules.options).
func _page(text: String, line_kind: String, follow_ups := [], own_mood := "") -> Dictionary:
	var options := ConversationRules.options(_data(), follow_ups, _asked, _passed_checks(), holds_on(), may_beg(), street())
	var texts: Array = options.map(func(option: Array) -> String: return option[1])
	return _with_mood({"kind": "gesprek", "speaker": speaker(), "text": text, "choices": texts,
		"on_choice": func(index: int) -> Array: return _answer(options[index])}, line_kind, own_mood)


## The skill checks the player passed already (PASSED_CHECKS_META).
func _passed_checks() -> Array:
	return player.get_meta(PASSED_CHECKS_META, []) if player else []


func _answer(option: Array) -> Array:
	var data := _data()
	# a conversation that holds on wears you out: every answer a little more overstimulated
	if holds_on() and player and player.has_method("change_stat"):
		player.change_stat("overprikkeldheid", float(data.get("prikkels", 0.0)))
	match str(option[0]):
		"onderwerp", "verder":
			return [_answer_node(option[2], str(option[0]) == "onderwerp")]
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


## A node of the topic tree asked (`is_topic`: the topic itself): its answer, then its own
## follow-ups (none left: the topic is done, "nog iets?").
func _answer_node(node: Dictionary, is_topic: bool) -> Dictionary:
	var data := _data()
	if is_topic:
		_asked["onderwerp"] = true
	if ConversationRules.is_check(node):
		return _try_check(node)
	var follow_ups := follow_ups_of(node)
	var text := _pick(node.get("antwoord"))
	# what the answer brings about ("gevolg"): told to who is talked to (its meta
	# "talk_consequence", a Callable(String): the clerks of the city hall send you on)
	if node.has("gevolg"):
		_consequence(str(node.gevolg))
	var reward_line := _reward_for(node)
	if node.has("koopt_blikjes"):
		reward_line = ConversationRules.joined(reward_line, _buy_cans(node))
	if reward_line != "":
		text += " " + reward_line
	if follow_ups.is_empty() and not is_topic:
		if holds_on():
			# a dead end: they start all over again
			text += " " + _pick(data.get("opnieuw"), "Maar goed, waar was ik?")
			follow_ups = follow_ups_of(data.get("onderwerp", {}))
		else:
			text += " " + _again()
	return _page(text, "onderwerp" if is_topic else "doorvraag", follow_ups, str(node.get("stemming", "")))


## What an answer brings about (a node's "gevolg", see the top).
func _consequence(gevolg: String) -> void:
	if gevolg.begins_with(ConversationRules.MISSION_CONSEQUENCE):
		var story := _story()
		if story and story.has_method("start_from_conversation"):
			story.start_from_conversation(ConversationRules.mission_of_consequence(gevolg))
		return
	if person and person.has_meta("talk_consequence"):
		(person.get_meta("talk_consequence") as Callable).call(gevolg)


## The story of the town who is talked to stands in (the group "verhaal"); null without one.
func _story() -> Node:
	return person.get_tree().get_first_node_in_group("verhaal") if person and person.is_inside_tree() else null


## A skill check on a question ("check": {"id", "label", "kans" in 100, "gelukt", "mislukt"}):
## the question shows "[LABEL 50%]" before it (ConversationRules.question_text). Asked, it
## passes at that chance: its "gelukt" answer and its own follow-ups, and the player keeps it
## (PASSED_CHECKS_META: never asked again); failed: its "mislukt" answer, and it can be tried
## again in a later conversation (not in this one). Either way the player says so
## (PlayerController.checked: the story waits for it, Story goal "check").
func _try_check(node: Dictionary) -> Dictionary:
	var check: Dictionary = node.check
	var check_id := str(check.get("id", ""))
	_asked[ConversationRules.check_key(check_id)] = true
	var passed := ConversationRules.check_passes(check, _random.randi_range(1, 100))
	var holding := holds_on()
	if passed and holding:
		_let_go = true
	if passed and player:
		var passed_checks: Array = player.get_meta(PASSED_CHECKS_META, [])
		passed_checks.append(check_id)
		player.set_meta(PASSED_CHECKS_META, passed_checks)
	if player and player.has_signal("checked"):
		player.emit_signal("checked", check_id, passed)
	if not check.get("verborgen", false):
		view.show_check(ConversationRules.check_result_text(check, passed), passed)
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


## A reward of topic node `node` ("beloning": {"item", "kans" in 100, "tekst", "xp"}): once
## per person (REWARD_META) at that chance the item goes in the player's pockets with its
## experience ("xp", else REWARD_XP), quietly (PlayerController.add_item and add_xp), and the
## reward screen shows them once the conversation is closed (GameHud.show_reward); their line
## about it is returned, to follow the answer it belongs to; "" when nothing is given (no
## reward, not this time, no room). "item" "pinpas" is a lost bank card of its own
## (BANK_CARD_METHOD on the player).
func _reward_for(node: Dictionary) -> String:
	var reward := ConversationRules.reward_of(node)
	if reward.is_empty() or person == null or person.has_meta(REWARD_META) or player == null:
		return ""
	if not ConversationRules.roll_passes(_random.randi_range(1, 100), int(reward.get("kans", 0))):
		person.set_meta(REWARD_META, true)
		return ""
	var item_id := str(reward.get("item", ""))
	if not _give(item_id):
		return ""
	person.set_meta(REWARD_META, true)
	var xp := ConversationRules.reward_xp(reward)
	if xp > 0 and player.has_method("add_xp"):
		player.call("add_xp", float(xp), true)
	if hud and hud.has_method("show_reward"):
		hud.show_reward(ConversationRules.reward_screen(speaker(), xp, item_id))
	return _pick(reward.get("tekst"), "Hier, voor jou.")


## Puts a reward in the player's pockets, quietly; false when it cannot be given (no room,
## no such item).
func _give(item_id: String) -> bool:
	if item_id == "pinpas":
		return player.has_method(BANK_CARD_METHOD) and bool(player.call(BANK_CARD_METHOD, true))
	if ItemTable.ITEMS.has(item_id) and player.has_method("has_room_for") and player.call("has_room_for", item_id):
		return bool(player.call("add_item", item_id, 1, true))
	return false


## Asked for change: once per person maybe some ("gulheid": "kans" in 100, "bedrag" in
## euros), counted as found money; true if they gave.
func _ask_for_money() -> bool:
	var generosity := ConversationRules.generosity(_data())
	var gives := not person.has_meta(GAVE_META) \
			and ConversationRules.roll_passes(_random.randi_range(1, 100), int(generosity.get("kans", 0)))
	person.set_meta(GAVE_META, true)
	if not gives:
		return false
	var euros := float(generosity.get("bedrag", 0.0))
	if player and player.has_method("add_money"):
		player.add_money(euros)
	# as a coin picked up (LooseChange): its value rising, over the open box, and the chime
	view.show_money("+" + MoneyText.euros(euros))
	view.play_coin()
	return true


# ------------------------------------------------------------------ the shop

## True for someone who sells (InteriorPerson `role` in MERCHANT_ROLES): talking to them
## opens the shop screen (GameHud.show_shop, scripts/ui/shop_screen.gd), not the story box.
static func is_merchant(someone: Node) -> bool:
	return someone != null and ConversationRules.is_merchant_role(str(someone.get("role")))


## What `someone` behind a counter says and sells: the snack bar's (COUNTER_FILE), with over
## it the shop of its kind (SHOPS_FILE "winkels", by the metadata "kind" of a seller in Den
## Haag Centraal) when there is one; a field a shop leaves out is the snack bar's.
static func shop_data_of(someone: Node) -> Dictionary:
	return ConversationRules.shop_data(counter(), shops(), str(someone.get_meta("kind", "")) if someone else "")


## Everything at the station costs more than in the town (ConversationRules.station_menu).
static func station_menu(menu: Array) -> Array:
	return ConversationRules.station_menu(menu, counter())


func is_shop() -> bool:
	return ConversationRules.is_merchant_role(persona)


## The name of the shop: the seller's own ("shop_name", Den Haag Centraal), else that of the
## snack bar it stands in (Interior), else "de snackbar".
func shop_name() -> String:
	var interior: Node = person.get_parent() if person else null
	return ConversationRules.shop_name(str(person.get_meta("shop_name", "")) if person else "",
		interior.get("snack_bar_name") if interior else null)


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
	return view.look()


func voice() -> String:
	return view.voice()


## Their body moves with the mood of a line (Emote).
func show_mood(mood: String) -> void:
	view.show_mood(mood)


## The goods: {"item", "vraag", "prijs", "naam"} each (the "menu" of the data); one with a "slot"
## only once the story has unlocked that ("snackkaart": the snack bar's whole menu after mission 1,
## before that only the kroket).
func shop_goods() -> Array:
	var story := _story()
	return ConversationRules.goods(_data().get("menu", []), func(slot: String) -> bool:
		return story == null or not story.has_method("is_unlocked") or bool(story.is_unlocked(slot)))


## A line of the seller: {"text", "mood"}.
func _line(text: String, line_kind: String) -> Dictionary:
	return ConversationRules.shop_line(text, shop_name(), mood_of(line_kind))


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
	var bought: String = player.call("buy", str(entry.get("item", "")), price) if player and player.has_method("buy") else "geld"
	var result := ConversationRules.buy_result(bought)
	var again := " " + _pick(data.get("nog_iets"))
	var line: Dictionary
	match result:
		"ok":
			var lines := ConversationRules.sold_lines(data)
			line = _line(str(lines[_random.randi() % lines.size()]).replace("{wat}", ConversationRules.good_name(entry)) + again, "gekocht")
		"vol":
			line = _line(_pick(data.get("zakken_vol")) + again, "zakken_vol")
		_:
			line = _line(_pick(data.get("geen_geld")).replace("{prijs}", MoneyText.euros(price)), "geen_geld")
	line["result"] = result
	return line


## What you can ask (the "tip_vraag"), "" when the shop has no tip.
func shop_tip_question() -> String:
	return str(_data().get("tip_vraag", "")) if _pick(_data().get("tip")) != "" else ""


func shop_tip() -> Dictionary:
	return _line(_pick(_data().get("tip")), "tip")


func shop_goodbye() -> Dictionary:
	return _line(_pick(_data().get("dag"), "Dag!"), "dag")


## Whether asking for change is an option: not until the story unlocks "bedelen" (Story
## is_unlocked; mission 1 after the cans are handed in). Without a story (a test): always.
func may_beg() -> bool:
	var story := _story()
	return story == null or not story.has_method("is_unlocked") or bool(story.is_unlocked("bedelen"))


## Someone who buys your cans (a node with "koopt_blikjes": euros a can; Blikken Bertus):
## all the cans in your pockets for that, paid out as at a deposit machine
## (DepositReturn.pay_out: PlayerController.deposited, the story's goal "statiegeld"). The
## line after: "gekocht" ({aantal}, {bedrag}), or "geen_blikjes" with none on you.
func _buy_cans(node: Dictionary) -> String:
	var count := int(player.inventory.get("blikje", 0)) if player and player.get("inventory") != null else 0
	if count <= 0:
		return _pick(node.get("geen_blikjes"), "Geen blikjes? Dan heb ik niks voor je.")
	var total := ConversationRules.cans_total(count, float(node.koopt_blikjes))
	for can_index in count:
		player.call("drop_item", "blikje")
	DepositReturn.pay_out(player, total)
	view.show_money("+" + MoneyText.euros(total))
	view.play_coin()
	return ConversationRules.cans_sold_text(_pick(node.get("gekocht"), "Alsjeblieft."), count, MoneyText.euros(total))
