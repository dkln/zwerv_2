extends RefCounted
## The rules of talking to someone (logic; docs/CODE_LAGEN.md): pure functions over the data
## of data/gesprekken/*.json (conversation_data.gd reads the files, conversations.gd is one
## conversation under way). Who someone is to talk to from how they look, their name, the
## variants of a conversation, the tree of a topic, the mood of a line, what you can say
## next, skill checks, rewards, begging, and what a shop sells and says.
## Where a line is one of a list, the caller draws a number (its own random generator: the
## order of the draws is the caller's) and hands it in.
##   const ConversationRules = preload("res://scripts/story/conversation_rules.gd")

const COUNTER_PERSONA := "snackbarhouder"
## The roles (InteriorPerson.role) of who sells: talked to in the shop screen.
const MERCHANT_ROLES := ["snackbarhouder", "verkoper"]
## Who is on duty and has a conversation of their own in personeel.json (shown as such: the
## name plate in their colours, their emblem): the NS and enforcement at Den Haag Centraal,
## the staff of the supermarkets, the people of the city hall.
const OFFICIAL_ROLES := ["conducteur", "handhaver", "agent", "medewerker_derrek", "medewerker_alfred_steyhn",
	"receptioniste", "beveiliger", "ambtenaar", "loketmedewerker", "raadslid", "burgemeester", "concierge"]
## Who you talk to when nothing else fits, and the mood of a line with none set.
const FALLBACK_PERSONA := "forens"
const FALLBACK_MOOD := "neutraal"
## The experience a reward of a conversation brings when its "beloning" says no "xp".
const REWARD_XP := 25
## At the station everything costs at least this many times the town's price (station_menu).
const STATION_MARKUP := 1.3
## Hair that makes someone look old (TownsfolkFigure.HAIRS: grey, white), as #RRGGBB.
const GREY_HAIRS := ["#8A8680", "#D8D4CC"]
## What a character says in all of its conversations (character_talk).
const CHARACTER_FIELDS := ["spreker", "stemmingen", "begroetingen", "dag", "kleingeld_ja", "kleingeld_nee", "gulheid", "nog_iets"]
## What starts a mission in a node's "gevolg": "missie:<id>".
const MISSION_CONSEQUENCE := "missie:"


# ------------------------------------------------------------------ who it is

## Every kind of passer-by of the street data, by id.
static func personas(street: Dictionary) -> Dictionary:
	var found := {}
	for entry: Dictionary in street.get("personen", []):
		found[str(entry.get("id", ""))] = entry
	return found


## A question you can ask ("kleingeld", "dag") of the street data.
static func question(street: Dictionary, key: String) -> String:
	return str((street.get("vragen", {}) as Dictionary).get(key, ""))


## Whether hair of this colour makes someone look old (GREY_HAIRS).
static func is_grey(hair: Color) -> bool:
	return GREY_HAIRS.any(func(grey: String) -> bool: return hair.is_equal_approx(Color.html(grey)))


## What can be seen of someone, for "herkennen" and "namen": {"soort" (its kind of person in
## the crowd, "" when none), "vervoer" (what it rides), "haar" (hair style), "rok", "vrouw"
## (long hair or a skirt), "grijs" (grey or white hair), "draagt" (what it carries), "jas"
## (the coat's colour)}, from its look (a TownsfolkFigure look) and what it is and has.
static func traits(look: Dictionary, crowd_kind: String, mobility: String, carried: String) -> Dictionary:
	var hair_style := str(look.get("hair_style", "kort"))
	var skirt := bool(look.get("skirt", false))
	return {
		"soort": crowd_kind,
		"vervoer": mobility,
		"haar": hair_style,
		"rok": skirt,
		"vrouw": hair_style == "lang" or skirt,
		"grijs": is_grey(look.get("hair", Color.BLACK)),
		"draagt": carried,
		"jas": look.get("coat", Color.WHITE),
	}


## Whether `seen` (traits) fit `wanted_traits`: every rule must hold. Rules: "soort",
## "vervoer", "haar", "draagt" (one value or a list of them), "rok", "vrouw", "grijs"
## (true/false), "jas" (a colour or a list). Someone riding fits only rules that name its
## "vervoer".
static func fits(wanted_traits: Dictionary, seen: Dictionary) -> bool:
	if not wanted_traits.has("vervoer") and str(seen.get("vervoer", "")) != "":
		return false
	for key: String in wanted_traits:
		var wanted: Variant = wanted_traits[key]
		match key:
			"soort", "vervoer", "haar", "draagt":
				var values: Array = wanted if wanted is Array else [wanted]
				if not values.has(str(seen.get(key, ""))):
					return false
			"rok", "vrouw", "grijs":
				if bool(wanted) != bool(seen.get(key, false)):
					return false
			"jas":
				var coat: Color = seen.get("jas", Color.WHITE)
				var colours: Array = wanted if wanted is Array else [wanted]
				if not colours.any(func(colour: Variant) -> bool: return coat.is_equal_approx(Color.html(str(colour)))):
					return false
	return true


## Who someone with `seen` traits is to talk to: the id of the first person of the street
## data whose "herkennen" fits; FALLBACK_PERSONA when none does.
static func persona_for(seen: Dictionary, street: Dictionary) -> String:
	for entry: Dictionary in street.get("personen", []):
		if fits(entry.get("herkennen", {}), seen):
			return str(entry.get("id", FALLBACK_PERSONA))
	return FALLBACK_PERSONA


## The name above what someone says: what they look like ("OUDE DAME", "MAN MET HOED"): the
## first of the person's own "namen", then of the general "namen" of the street data, whose
## "als" fits `seen`; else the person's "spreker".
static func name_for(seen: Dictionary, data: Dictionary, street: Dictionary) -> String:
	var choices: Array = data.get("namen", []) + street.get("namen", [])
	for choice: Dictionary in choices:
		if fits(choice.get("als", {}), seen):
			return str(choice.get("naam", ""))
	return str(data.get("spreker", ""))


static func is_merchant_role(role: String) -> bool:
	return role in MERCHANT_ROLES


## The data of someone on duty of `role` in the staff data; {} for a role that is not on
## duty (OFFICIAL_ROLES) or has no conversation there.
static func official_data(staff: Dictionary, role: String) -> Dictionary:
	if not role in OFFICIAL_ROLES:
		return {}
	return (staff.get("personen", {}) as Dictionary).get(role, {})


## Whether `role` is on duty with a conversation of its own in the staff data.
static func is_official_role(staff: Dictionary, role: String) -> bool:
	return role in OFFICIAL_ROLES and (staff.get("personen", {}) as Dictionary).has(role)


# ------------------------------------------------------------------ which conversation

## The conversation of character `who` (of `characters`: personages.json "personen") called
## `key` (its "gesprekken"; "" or unknown: its "standaard"), with what the character says in
## all of them (CHARACTER_FIELDS) under it.
static func character_talk(characters: Dictionary, who: String, key: String) -> Dictionary:
	var data: Dictionary = characters.get(who, {})
	var talks: Dictionary = data.get("gesprekken", {})
	if not talks.has(key):
		key = str(data.get("standaard", ""))
	var talk: Dictionary = (talks.get(key, {}) as Dictionary).duplicate()
	for field: String in CHARACTER_FIELDS:
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


## Whether the variant kept on someone (`kept_index`, -1 for none) is one of `count`.
static func has_variant(kept_index: int, count: int) -> bool:
	return kept_index >= 0 and kept_index < count


## Whether a conversation holds on to you ("klampt_vast") while it has not let go.
static func holds_on(data: Dictionary, let_go: bool) -> bool:
	return bool(data.get("klampt_vast", false)) and not let_go


# ------------------------------------------------------------------ lines

## Whether a line of the data is a list to pick from (a number must be drawn for line()).
static func is_choice(value: Variant) -> bool:
	return value is Array and not (value as Array).is_empty()


## A line of the data: a text, or a list of texts of which the one at `drawn` (any number
## from 0 up) is taken; `fallback` for nothing or an empty list.
static func line(value: Variant, drawn: int, fallback := "") -> String:
	if value is Array:
		return str(value[drawn % (value as Array).size()]) if not (value as Array).is_empty() else fallback
	return fallback if value == null else str(value)


## The lines someone says for "nog iets?": their own list, else the street data's.
static func again_lines(data: Dictionary, street: Dictionary) -> Array:
	var own: Variant = data.get("nog_iets")
	return own if own is Array else street.get("nog_iets", ["Nog iets?"])


## The mood of a kind of line ("begroeting", "onderwerp", "kleingeld_ja", ...): the person's
## own ("stemmingen" of `data`), else the general one (`general`), else FALLBACK_MOOD.
static func mood_of(data: Dictionary, general: Dictionary, line_kind: String) -> String:
	var own: Dictionary = data.get("stemmingen", {})
	return str(own.get(line_kind, general.get(line_kind, FALLBACK_MOOD)))


## Two parts of what someone says after one another ("" parts left out).
static func joined(first: String, second: String) -> String:
	return (first + " " + second).strip_edges()


# ------------------------------------------------------------------ the tree of a topic

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


## What you can say on a page, in order: each [kind, text, node]. The follow-ups of the node
## just answered first (not a skill check that is done: check_done), then the topic when not
## asked yet, and unless the conversation holds on: change (when `can_beg` and not asked yet)
## and goodbye. `asked`: what was asked already in this conversation.
static func options(data: Dictionary, follow_ups: Array, asked: Dictionary, passed_checks: Array, holding: bool,
		can_beg: bool, street: Dictionary) -> Array:
	var found: Array = []
	var topic: Dictionary = data.get("onderwerp", {})
	for follow_up: Dictionary in follow_ups:
		if not check_done(follow_up, asked, passed_checks):
			found.append(["verder", question_text(follow_up), follow_up])
	if not asked.has("onderwerp") and topic.has("vraag"):
		found.append(["onderwerp", str(topic.vraag), topic])
	if not holding:
		if not asked.has("kleingeld") and can_beg:
			found.append(["kleingeld", question(street, "kleingeld"), {}])
		found.append(["dag", question(street, "dag"), {}])
	return found


# ------------------------------------------------------------------ skill checks

## Whether a node is a skill check ("check": {"id", "label", "kans" in 100, "gelukt", "mislukt"}).
static func is_check(node: Dictionary) -> bool:
	return node.get("check") is Dictionary


## What a check tried in this conversation is called in `asked`.
static func check_key(check_id: String) -> String:
	return "check:" + check_id


## Whether `node` is a skill check the player passed already (`passed_checks`: their ids) or
## tried in this conversation (`asked`).
static func check_done(node: Dictionary, asked: Dictionary, passed_checks: Array) -> bool:
	if not is_check(node):
		return false
	var check_id := str(node.check.get("id", ""))
	return asked.has(check_key(check_id)) or passed_checks.has(check_id)


## The question of a node as you can choose it: a skill check with its label and chance first
## (not a hidden one, "verborgen").
static func question_text(node: Dictionary) -> String:
	var text := str(node.get("vraag", ""))
	if is_check(node) and not (node.check as Dictionary).get("verborgen", false):
		var check: Dictionary = node.check
		text = "[%s %d%%] %s" % [str(check.get("label", "CHECK")), int(check.get("kans", 50)), text]
	return text


## Whether something with a chance of `chance` in 100 happens at `roll` (1..100).
static func roll_passes(roll: int, chance: int) -> bool:
	return roll <= chance


## Whether a check passes at `roll` (1..100): its "kans", 50 when it names none.
static func check_passes(check: Dictionary, roll: int) -> bool:
	return roll_passes(roll, int(check.get("kans", 50)))


## What rises over someone after a check that is not hidden: "<LABEL> GESLAAGD" or "MISLUKT".
static func check_result_text(check: Dictionary, passed: bool) -> String:
	return "%s %s" % [str(check.get("label", "CHECK")), "GESLAAGD" if passed else "MISLUKT"]


# ------------------------------------------------------------------ what it brings about

## The mission a node's "gevolg" starts ("missie:<id>"); "" for any other consequence.
static func mission_of_consequence(consequence: String) -> String:
	return consequence.trim_prefix(MISSION_CONSEQUENCE) if consequence.begins_with(MISSION_CONSEQUENCE) else ""


## The reward of a topic node ("beloning": {"item", "kans" in 100, "tekst", "xp"}); {} none.
static func reward_of(node: Dictionary) -> Dictionary:
	return node.get("beloning", {}) if node.get("beloning") is Dictionary else {}


## The experience of a reward: its "xp", else REWARD_XP.
static func reward_xp(reward: Dictionary) -> int:
	return int(reward.get("xp", REWARD_XP))


## The reward screen of something given in a conversation (GameHud.show_reward).
static func reward_screen(from: String, xp: int, item_id: String) -> Dictionary:
	return {"heading": "GEKREGEN", "title": "Van " + from if from != "" else "",
		"xp": xp, "items": [{"item": item_id, "count": 1}]}


## How generous someone is ("gulheid": "kans" in 100, "bedrag" in euros); nothing when the
## data names none.
static func generosity(data: Dictionary) -> Dictionary:
	return data.get("gulheid", {"kans": 0, "bedrag": 0.0})


## What `count` cans bring at `per_can` euros each (someone who buys them), in whole cents.
static func cans_total(count: int, per_can: float) -> float:
	return snappedf(count * per_can, 0.01)


## The line after selling cans: {aantal} and {bedrag} filled in.
static func cans_sold_text(text: String, count: int, total_text: String) -> String:
	return text.replace("{aantal}", str(count)).replace("{bedrag}", total_text)


## The line of the conductor who caught you for `reason` ("uitchecken": not checked out, his
## "betrapt_uitchecken" when there is one; else "betrapt"): the value to pick the line from.
static func caught_lines(data: Dictionary, reason: String) -> Variant:
	var own: Variant = data.get("betrapt_uitchecken") if reason == "uitchecken" else null
	return own if own != null else data.get("betrapt")


## The line of being caught with the fine filled in ({boete}).
static func caught_text(text: String, fine_text: String) -> String:
	return text.replace("{boete}", fine_text)


# ------------------------------------------------------------------ the shop

## What someone behind a counter says and sells: the snack bar's (`counter`), with over it
## the shop of `kind` (`shops` "winkels") when there is one; a field a shop leaves out is the
## snack bar's. A shop with a kind (Den Haag Centraal) has station prices (station_menu).
static func shop_data(counter: Dictionary, shops: Dictionary, kind: String) -> Dictionary:
	var merged := counter.duplicate()
	var own: Dictionary = (shops.get("winkels", {}) as Dictionary).get(kind, {})
	merged.merge(own, true)
	if kind != "":
		merged["menu"] = station_menu(merged.get("menu", []), counter)
	return merged


## Everything at the station costs more than in the town: a shop of Den Haag Centraal asks at
## least STATION_MARKUP times what the town's snack bar (`counter`) asks for the same thing
## (rounded up to 5 cents); what the town does not sell keeps its own price.
static func station_menu(menu: Array, counter: Dictionary) -> Array:
	var town_prices := {}
	for entry: Dictionary in counter.get("menu", []):
		town_prices[str(entry.get("item", ""))] = float(entry.get("prijs", 0.0))
	var result := []
	for entry: Dictionary in menu:
		var priced := entry.duplicate()
		var town_price: float = town_prices.get(str(entry.get("item", "")), 0.0)
		var lowest := ceilf(town_price * STATION_MARKUP * 20.0 - 0.0001) / 20.0
		priced["prijs"] = maxf(float(entry.get("prijs", 0.0)), lowest)
		result.append(priced)
	return result


## The goods of a "menu" you can buy now: one with a "slot" only when `is_open` (a Callable
## that takes the slot and says whether the story has unlocked it) says so.
static func goods(menu: Array, is_open: Callable) -> Array:
	return menu.filter(func(entry: Variant) -> bool:
		return entry is Dictionary and (not entry.has("slot") or bool(is_open.call(str(entry.slot)))))


## The name of the shop: the seller's own, else that of the snack bar it stands in, else
## "de snackbar".
static func shop_name(own_name: String, bar_name: Variant) -> String:
	if own_name != "":
		return own_name
	return String(bar_name) if bar_name is String and bar_name != "" else "de snackbar"


## A line of the seller: {"text" (with {zaak} and {snackbar} the shop's name), "mood"}.
static func shop_line(text: String, name_of_shop: String, mood: String) -> Dictionary:
	return {"text": text.replace("{zaak}", name_of_shop).replace("{snackbar}", name_of_shop), "mood": mood}


## What a good is called in the line after buying it: its "naam", else its item.
static func good_name(entry: Dictionary) -> String:
	return str(entry.get("naam", entry.get("item", "")))


## The lines a seller says after a sale ("gekocht").
static func sold_lines(data: Dictionary) -> Array:
	return data.get("gekocht", ["Alsjeblieft, {wat}."])


## What buying came to: "ok" (paid, in the pockets), "vol" (no room) or "geld" (anything else:
## too little money).
static func buy_result(result: String) -> String:
	return result if result in ["ok", "vol"] else "geld"
