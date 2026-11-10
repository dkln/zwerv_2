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
##   `role` "snackbarhouder") it is ordering: the "menu" (item, what you ask, price), bought
##   with the player's money (PlayerController.buy), a tip, or nothing after all.
## Asked topics are not offered again; goodbye ends it. Every line has a mood: they babble
## in it, in their voice (Babble, the story box) and their body moves with it (Emote: angry
## shakes, happy hops, sad leans forward); `finish` puts them back as they were.
##   var talk := Conversations.new(person, player, hud)
##   hud.show_story(talk.opening(), talk.finish)

const Emote = preload("res://scripts/world/emote.gd")
const STREET_FILE := "res://data/gesprekken/voorbijgangers.json"
const COUNTER_FILE := "res://data/gesprekken/snackbarhouder.json"
const COUNTER_PERSONA := "snackbarhouder"
## Who you talk to when nothing else fits, and the mood of a line with none set.
const FALLBACK_PERSONA := "forens"
const FALLBACK_MOOD := "neutraal"
const GAVE_META := "gaf_kleingeld"
const MONEY_COLOUR := Color("#E8B83A")

static var _street := {}
static var _counter := {}

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
	if talking_to and talking_to.get("role") == COUNTER_PERSONA:
		persona = COUNTER_PERSONA
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


## Reads them again (after changing the files, while the game runs).
static func reload() -> void:
	_street = {}
	_counter = {}


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


## A question you can ask ("kleingeld", "snackbar", "dag").
static func question(key: String) -> String:
	return str((street().get("vragen", {}) as Dictionary).get(key, ""))


## Who `someone` is to talk to: the id of the first person of the data whose "herkennen"
## fits how it looks (see the top).
static func persona_of(someone: Node) -> String:
	if someone == null:
		return FALLBACK_PERSONA
	var mobility := str(someone.get("mobility")) if someone.get("mobility") != null else ""
	var figure: Node = someone.get("figure")
	var look: Dictionary = figure.get("look") if figure and figure.get("look") is Dictionary else {}
	for entry: Dictionary in street().get("personen", []):
		if _fits(entry.get("herkennen", {}), mobility, look):
			return str(entry.get("id", FALLBACK_PERSONA))
	return FALLBACK_PERSONA


static func _fits(rules: Dictionary, mobility: String, look: Dictionary) -> bool:
	if rules.has("vervoer") and str(rules.vervoer) != mobility:
		return false
	if not rules.has("vervoer") and mobility != "":
		return false   # someone riding is only who says so
	if rules.has("haar") and str(rules.haar) != str(look.get("hair_style", "kort")):
		return false
	if rules.has("rok") and bool(rules.rok) != bool(look.get("skirt", false)):
		return false
	if rules.has("jas"):
		var coat: Color = look.get("coat", Color.WHITE)
		var colours: Array = rules.jas if rules.jas is Array else [rules.jas]
		if not colours.any(func(colour: Variant) -> bool: return coat.is_equal_approx(Color(str(colour)))):
			return false
	return true


func _data() -> Dictionary:
	return counter() if persona == COUNTER_PERSONA else personas().get(persona, personas().get(FALLBACK_PERSONA, {}))


## The mood of a kind of line ("begroeting", "onderwerp", "kleingeld_ja", ...): the person's
## own, else the general one, else FALLBACK_MOOD.
func mood_of(line_kind: String) -> String:
	var own: Dictionary = _data().get("stemmingen", {})
	var general: Dictionary = street().get("stemmingen", {}) if persona != COUNTER_PERSONA else {}
	return str(own.get(line_kind, general.get(line_kind, FALLBACK_MOOD)))


# ------------------------------------------------------------------ the conversation

## The first page: a greeting and what you can say.
func opening() -> Array:
	var greetings: Array = _data().get("begroetingen", ["Ja?"])
	var greeting := str(greetings[_random.randi() % greetings.size()])
	if persona == COUNTER_PERSONA:
		return [_counter_page(greeting.replace("{snackbar}", _snack_bar_name()), "begroeting")]
	return [_page(greeting, "begroeting")]


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
	page["on_show"] = func() -> void: Emote.start(person, figure, mood)
	return page


func _again() -> String:
	var lines: Array = street().get("nog_iets", ["Nog iets?"])
	return str(lines[_random.randi() % lines.size()])


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
	if not _asked.has("snackbar"):
		options.append(["snackbar", question("snackbar")])
	options.append(["dag", question("dag")])
	var texts: Array = options.map(func(option: Array) -> String: return option[1])
	return _with_mood({"kind": "gesprek", "speaker": str(data.get("spreker", "")), "text": text, "choices": texts,
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
			return [_page(str(data.get("kleingeld_ja" if gave else "kleingeld_nee", "")) + " " + _again(), "kleingeld_ja" if gave else "kleingeld_nee")]
		"snackbar":
			_asked["snackbar"] = true
			return [_page(str(data.get("snackbar", "")) + " " + _again(), "snackbar")]
	# goodbye: their last word, then the box closes
	return [_with_mood({"kind": "gesprek", "speaker": str(data.get("spreker", "")), "text": str(data.get("dag", ""))}, "dag")]


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
	if hud and hud.has_method("show_floating_number"):
		hud.show_floating_number(person.global_position + Vector3.UP * 2.0, "+" + _euros(euros), MONEY_COLOUR)
	return true


# ------------------------------------------------------------------ the counter

## The name of the snack bar the one behind the counter stands in (Interior).
func _snack_bar_name() -> String:
	var interior: Node = person.get_parent() if person else null
	var bar_name: Variant = interior.get("snack_bar_name") if interior else null
	return String(bar_name) if bar_name is String and bar_name != "" else "de snackbar"


## A page of the one behind the counter: `text`, and the menu to order from.
func _counter_page(text: String, line_kind: String) -> Dictionary:
	var data := counter()
	var options: Array = []
	for entry: Dictionary in data.get("menu", []):
		options.append(["kopen", "%s (%s)" % [str(entry.get("vraag", "")), _euros(float(entry.get("prijs", 0.0)))], entry])
	options.append(["tip", str(data.get("tip_vraag", "")), {}])
	options.append(["niets", str(data.get("niets_vraag", "")), {}])
	var texts: Array = options.map(func(option: Array) -> String: return option[1])
	return _with_mood({"kind": "gesprek", "speaker": str(data.get("spreker", "")), "text": text, "choices": texts,
		"on_choice": func(index: int) -> Array: return _order(options[index])}, line_kind)


func _order(option: Array) -> Array:
	var data := counter()
	var again := " " + str(data.get("nog_iets", ""))
	match str(option[0]):
		"kopen":
			var entry: Dictionary = option[2]
			var price := float(entry.get("prijs", 0.0))
			var result: String = player.call("buy", str(entry.get("item", "")), price) if player and player.has_method("buy") else "geld"
			match result:
				"ok":
					var lines: Array = data.get("gekocht", ["Alsjeblieft, {wat}."])
					var what := str(entry.get("naam", entry.get("item", "")))
					return [_counter_page(str(lines[_random.randi() % lines.size()]).replace("{wat}", what) + again, "gekocht")]
				"vol":
					return [_counter_page(str(data.get("zakken_vol", "")) + again, "zakken_vol")]
				_:
					return [_counter_page(str(data.get("geen_geld", "")).replace("{prijs}", _euros(price)) + again, "geen_geld")]
		"tip":
			return [_counter_page(str(data.get("tip", "")) + again, "tip")]
	return [_with_mood({"kind": "gesprek", "speaker": str(data.get("spreker", "")), "text": str(data.get("dag", ""))}, "dag")]


static func _euros(amount: float) -> String:
	return "€ " + ("%.2f" % amount).replace(".", ",")
