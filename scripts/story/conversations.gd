extends RefCounted
## Talking to someone (a passer-by: Pedestrian; someone in an interior: InteriorPerson;
## PlayerController.talk_to): a little conversation tree in the story box
## (scripts/ui/story_box.gd, pages of kind "gesprek" with "choices").
## Everything said comes from data files you can change and add to (see data/LEESMIJ.md):
## - data/gesprekken/voorbijgangers.json: who you talk to (`persona`: the first of "personen"
##   whose "herkennen" fits how they look: "vervoer" (rolstoel, scootmobiel), "haar" (kort,
##   lang, kaal, pet), "rok" (true/false), "jas" (colours); none: it fits anyone), their
##   greetings, their own topic and its follow-up, asking for some change (now and then they
##   give some: "gulheid", once per person, counted for the missions as found money), the
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
##   (the station's fine_the_player).
## Asked topics are not offered again; goodbye ends it. Every line has a mood: they babble
## in it, in their voice (Babble, the story box) and their body moves with it (Emote: angry
## shakes, happy hops, sad leans forward); `finish` puts them back as they were.
##   var talk := Conversations.new(person, player, hud)
##   hud.show_story(talk.opening(), talk.finish)      # or, for a seller: hud.show_shop(talk, ...)

const Emote = preload("res://scripts/world/emote.gd")
const Interiors = preload("res://scripts/world/interiors.gd")
const STREET_FILE := "res://data/gesprekken/voorbijgangers.json"
const COUNTER_FILE := "res://data/gesprekken/snackbarhouder.json"
const COUNTER_PERSONA := "snackbarhouder"
const SHOPS_FILE := "res://data/gesprekken/winkels.json"
## The roles (InteriorPerson.role) of who sells: talked to in the shop screen.
const MERCHANT_ROLES := ["snackbarhouder", "verkoper"]
const STAFF_FILE := "res://data/gesprekken/personeel.json"
## The roles (StationPerson.role) of who is on duty: their own conversation and look.
const OFFICIAL_ROLES := ["conducteur", "handhaver", "agent"]
## Who you talk to when nothing else fits, and the mood of a line with none set.
const FALLBACK_PERSONA := "forens"
const FALLBACK_MOOD := "neutraal"
const GAVE_META := "gaf_kleingeld"
## Hair that makes someone look old (TownsfolkFigure.HAIRS: grey, white).
const GREY_HAIRS := [Color("#8A8680"), Color("#D8D4CC")]
## At the station everything costs at least this many times the town's price (station_menu).
const STATION_MARKUP := 1.3
const MONEY_COLOUR := Color("#E8B83A")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")

static var _street := {}
static var _counter := {}
static var _shops := {}
static var _staff := {}

var persona := FALLBACK_PERSONA
var person: Node3D
var player: Node
var hud: Node
var _asked := {}
var _random := RandomNumberGenerator.new()


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


func _data() -> Dictionary:
	if is_shop():
		return shop_data_of(person)
	if persona in OFFICIAL_ROLES:
		return (staff().get("personen", {}) as Dictionary).get(persona, {})
	return personas().get(persona, personas().get(FALLBACK_PERSONA, {}))


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
	var greetings: Array = _data().get("begroetingen", ["Ja?"])
	return [_page(str(greetings[_random.randi() % greetings.size()]), "begroeting")]


## The conversation is over: the body as it was.
func finish() -> void:
	Emote.stop(person)


func _voice() -> String:
	return str(person.call("voice")) if person and person.has_method("voice") else "man"


## Their mood shown and heard on a page (babble, Emote), their look in the portrait.
func _with_mood(page: Dictionary, line_kind: String) -> Dictionary:
	var mood := mood_of(line_kind)
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
	var fine := float(station.call("fine_the_player"))
	var text := str(_data().get("betrapt", "Zwartrijden? Dat wordt {boete} boete.")).replace("{boete}", _euros(fine))
	return _page(text, "betrapt")


## The page of the person saying `text` (a line of `line_kind`), with the questions not
## asked yet (the follow-up of the topic first, when there is one).
func _page(text: String, line_kind: String, follow_up := {}) -> Dictionary:
	var data := _data()
	var topic: Dictionary = data.get("onderwerp", {})
	var options: Array = []
	if not follow_up.is_empty():
		options.append(["doorvraag", str(follow_up.get("doorvraag", ""))])
	if not _asked.has("onderwerp") and topic.has("vraag"):
		options.append(["onderwerp", str(topic.vraag)])
	if not _asked.has("kleingeld"):
		options.append(["kleingeld", question("kleingeld")])
	options.append(["dag", question("dag")])
	var texts: Array = options.map(func(option: Array) -> String: return option[1])
	return _with_mood({"kind": "gesprek", "speaker": speaker(), "text": text, "choices": texts,
		"on_choice": func(index: int) -> Array: return _answer(options[index], follow_up)}, line_kind)


func _answer(option: Array, follow_up: Dictionary) -> Array:
	var data := _data()
	match str(option[0]):
		"onderwerp":
			_asked["onderwerp"] = true
			var topic: Dictionary = data.get("onderwerp", {})
			return [_page(str(topic.get("antwoord", "")), "onderwerp", topic if topic.has("doorvraag") else {})]
		"doorvraag":
			return [_page(str(follow_up.get("doorantwoord", "")) + " " + _again(), "doorvraag")]
		"kleingeld":
			_asked["kleingeld"] = true
			var gave := _ask_for_money()
			# begging counts inside: too much of it and you are thrown out (Interiors)
			if person and person.is_inside_tree():
				Interiors.note_offence(person.get_tree(), "bedelen")
			return [_page(str(data.get("kleingeld_ja" if gave else "kleingeld_nee", "")) + " " + _again(), "kleingeld_ja" if gave else "kleingeld_nee")]
	# goodbye: their last word, then the box closes
	return [_with_mood({"kind": "gesprek", "speaker": speaker(), "text": str(data.get("dag", ""))}, "dag")]


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
	if is_shop() or persona in OFFICIAL_ROLES:
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


## The goods: {"item", "vraag", "prijs", "naam"} each (the "menu" of the data).
func shop_goods() -> Array:
	return (_data().get("menu", []) as Array).filter(func(entry: Variant) -> bool: return entry is Dictionary)


## A line of the seller: {"text", "mood"}.
func _line(text: String, line_kind: String) -> Dictionary:
	return {"text": text.replace("{zaak}", shop_name()).replace("{snackbar}", shop_name()), "mood": mood_of(line_kind)}


func shop_greeting() -> Dictionary:
	var greetings: Array = _data().get("begroetingen", ["Zeg het maar."])
	return _line(str(greetings[_random.randi() % greetings.size()]), "begroeting")


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
	var again := " " + str(data.get("nog_iets", ""))
	var line: Dictionary
	match result:
		"ok":
			var lines: Array = data.get("gekocht", ["Alsjeblieft, {wat}."])
			var what := str(entry.get("naam", entry.get("item", "")))
			line = _line(str(lines[_random.randi() % lines.size()]).replace("{wat}", what) + again, "gekocht")
		"vol":
			line = _line(str(data.get("zakken_vol", "")) + again, "zakken_vol")
		_:
			result = "geld"
			line = _line(str(data.get("geen_geld", "")).replace("{prijs}", _euros(price)), "geen_geld")
	line["result"] = result
	return line


## What you can ask (the "tip_vraag"), "" when the shop has no tip.
func shop_tip_question() -> String:
	return str(_data().get("tip_vraag", "")) if str(_data().get("tip", "")) != "" else ""


func shop_tip() -> Dictionary:
	return _line(str(_data().get("tip", "")), "tip")


func shop_goodbye() -> Dictionary:
	return _line(str(_data().get("dag", "Dag!")), "dag")


static func _euros(amount: float) -> String:
	return "€ " + ("%.2f" % amount).replace(".", ",")
