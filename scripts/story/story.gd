extends Node
## The story of the game (the node "Verhaal" of scenes/stad.tscn): the prologue and the
## missions, from data files you can change and add to (see data/LEESMIJ.md), shown in the
## story box of the HUD (GameHud.show_story, scripts/ui/story_box.gd) and kept in the quest
## tracker (GameHud.set_quests) and the quest log of the game menu.
## - The prologue (data/verhaal/proloog.json) opens as soon as the player has woken up on the
##   square by Centraal Station (PlayerController.woke_up). In every text {naam} is the name
##   of your character and {achtergrond} its backstory (the archetype's "story").
## - The missions (data/missies/*.json, in the order of their file names) start "na_proloog"
##   or "na:<id of another mission>" (when that one is done): their "start_paginas", then
##   the notice at the top. Their steps are done one after the other; the step under way
##   shows where to go on the minimap and the map ("plekken": the nearest "snackbars",
##   "supermarkten" or "blikjes" (waste bins with a can), one "plek", a list of "plekken"
##   or a "persoon"), the later ones are locked (see-through), a step "verborgen_tot_open" is
##   not listed at all until it can be done (Story._quest). A step "optioneel" never
##   holds up the next: it can be done while the mission runs.
##   A step is done when its goal ("doel") is met:
##     geld_verdiend  {"bedrag": 2.0}       money found or earned since the start that is
##                                            still in the wallet (money_towards_goal)
##     geld_op_zak    {"bedrag": 2.0}       that much in the wallet (any money, the start money
##                                            too; already there as the step opens: done at once)
##     kopen          {"item": "kroket"}    bought (PlayerController.bought)
##     gebruiken      {"item": "kroket"}    eaten, drunk or used (PlayerController.used)
##     verzamelen     {"item": "blikje", "aantal": 4}  that many in the pockets
##     statiegeld     {}                    a deposit machine paid out (PlayerController.deposited)
##     praten_met     {"persoon": "toerist"} talked to (a kind of passer-by, a character of
##                                            data/gesprekken/personages.json, or "iemand"):
##                                            done when the conversation is over
##     naar_plek      {"plek": "koekamp", "straal": 12}  come within "straal" m of a place
##     naar_persoon   {"persoon": "ome_wim", "straal": 6} come within "straal" m of a character
##     lopen          {"meter": 4}          walked that far since the step began
##     stat_onder     {"stat": "honger", "waarde": 68}  that stat has fallen under the value
##     menu_open      {"tab": "inventaris"} the game menu opened (on that tab, or any)
##     check          {"check": "overtuigen_wim"}  a skill check in a conversation passed
##     begeleiden     {"persoon": "ome_wim", "route": ["plein", ...]}  walked with a
##                                            character along the places to the last one
##                                            ("wacht": false: it walks there in one go, you
##                                            follow; done once you are there with it)
##     werver         {"persoon": "werver", "straal": 9}  a character stands in the way of
##                                            the one you walk with: talk to it or pass it
##   then its "klaar_paginas" show; when all are, the "einde_paginas" (a page with "als":
##   "check:<id>" only when that check passed).
##   When a step begins: "zet_stats" sets stats ({"honger": 74}), "ontgrendelt" unlocks
##   parts of the game (["menu"]: the game menu, Tab; ["bedelen"]: asking people for change),
##   "opent" opens areas of the shroud
##   (data/gebieden.json, Shroud). "groeit" ({"per": "blikje", "tot": "supermarkt"}) lets the
##   start area grow with every one of the goal's items collected, until the nearest
##   supermarket is in it. "storing" makes the first deposit machine the player tries
##   during the step out of order ({"tekst", "paginas"}); the step's text becomes
##   "tekst_storing", it points to the other supermarkets and the area grows to the next.
##   A whole mission done: "opent_na_afloop" opens areas, "markeringen" (places of the map)
##   stay on the maps for good, and a mission "herhaalbaar" starts again after "herhaal_na"
##   seconds.
##   {voortgang} in a step's text is how far its goal is (the money: "€ 1,20", items: "2/4"),
##   {geldregel} a line of the mission's "geldregel" ("leeg" or "wel": whether your
##   character starts with money).
## A task done plays a triumph tune (GameHud.play_task_done), the whole mission a longer one.
## A step with "overslaan_als": {"startgeld_minstens": 2.0} is skipped (done at once, no XP)
## for a character that starts with that much money or more.
## Experience: every mission and every step has its own "xp", given once (PlayerController.add_xp)
## when the step is done and when the whole mission is; the tracker and the quest log show it.
## A step with "eerste_scherm" ({"kop": "GEVONDEN", "titel": "Je eerste blikje"}) shows the
## first of its goal's items picked up in the reward screen (once per game: _on_got_item).
## Items: a step or a mission may give things too ("geeft": [{"item": "koffie", "aantal": 1}],
## the ids of Items), into the pockets when it is done.
## What a task or a mission gives is shown in the reward screen (GameHud.show_reward: the item
## big and turning, its own jingle), after its pages; not as text rising over the player.

signal shroud_changed
signal markers_changed
signal unlocked(what: String)

const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const Shroud = preload("res://scripts/story/shroud.gd")
const Conversations = preload("res://scripts/story/conversations.gd")
const MoneyText = preload("res://scripts/common/money_text.gd")
const MISSIONS_FOLDER := "res://data/missies/"
const PROLOGUE_FILE := "res://data/verhaal/proloog.json"
## A snack bar's shop front (in the name of a Gebouwen item: "<style>/<style>_bg_snackbar").
const SNACK_BAR_FRONT := "_bg_snackbar"
## A supermarket's doors (in the name of a Gebouwen item: "<style>/<style>_bg_derrek_ingang").
const SUPERMARKET_DOORS := ["_bg_derrek_ingang", "_bg_alfred_steyhn_ingang"]
## Seconds between two looks at the goals that are about where the player is or how it is.
const PLACE_CHECK_SECONDS := 0.5
## Metres from the story's cans in the station within which the player is in there with them
## (_in_the_station; the interiors lie far off the map).
const STATION_CANS_REACH := 150.0
## The kinds of goal a step can have (see the top; tests/unit/story/test_missions.gd checks the data).
const GOAL_KINDS := ["geld_verdiend", "geld_op_zak", "kopen", "gebruiken", "verzamelen", "statiegeld", "praten_met", "naar_plek",
	"naar_persoon", "lopen", "stat_onder", "menu_open", "check", "begeleiden", "werver"]
## Seconds between two thoughts at the edge of the shroud.
const EDGE_THOUGHT_SECONDS := 12.0
const EDGE_THOUGHTS := [
	"Daar heb ik nu niks te zoeken.",
	"Verder ken ik de weg niet. Eerst hier maar eens rondkijken.",
	"Nee, daar ga ik nog niet heen.",
]
## Locked at the start until a mission unlocks it ("ontgrendelt"): "menu" (the game menu) and
## "bedelen" (asking people for change, Conversations: mission 1 after the deposit), "handelaars"
## (talking to sellers) and "springen" (Space, PlayerController.jumping_open: mission 1, on
## coming into the station for the last cans, "bij_binnenkomst"), "kleingeld" and "pinpassen"
## (coins and bank cards lying on the streets, LooseChange, LostBankCards: no mission yet) and
## "snackkaart" (the whole menu of a snack bar, Conversations.shop_goods "slot": after mission 1).
const UNLOCKABLE := ["menu", "bedelen", "handelaars", "springen", "kleingeld", "pinpassen", "snackkaart"]
## Metres round the start where only the first mission's own cans lie (LitterBins.fill_near).
const CANS_ALONE_WITHIN := 160.0

@export var player_path := NodePath("../Speler")
@export var hud_path := NodePath("../HUD")
@export var buildings_path := NodePath("../Gebouwen")
@export var characters_path := NodePath("../Personages")
@export var bins_path := NodePath("../Prullenbakken")
@export var interiors_path := NodePath("../Binnenruimtes")
## Seconds after waking before the prologue opens (the figure is up, the music has started).
@export var prologue_delay := 0.6
## The shroud on (off: the whole town open, as before the missions had areas).
@export var use_shroud := true

var missions: Array[Dictionary] = []   # the data of every mission, in order
var _waiting_from_talk: Array[String] = []   # missions a conversation started, once it is over
var shroud := Shroud.new()
var _player: Node
var _hud: Node
var _started: Array[String] = []        # ids of the missions under way or done, in order
var _done := {}                          # "mission id/step id" -> true
var _finished := {}                      # mission id -> true
var _targets := {}                       # "mission id/step id" -> Array of world x, z
var _xp_given := {}
var _begun := {}                         # "mission id/step id" -> {"from": Vector3, "walked": float}
var _flags := {}                         # "check:<id>", "menu", ... -> true
var _broken := {}                        # "mission id/step id" -> world x, z of the broken machine's shop
var _station_cans: Array = []             # world x, z of the cans lying in the station while the player is in there
var _aimed_in_station := false           # whether the marks were last aimed with the player in the station (_in_the_station)
var _markers := {}                       # place key -> world x, z
var _place_clock := 0.0
var _edge_clock := 0.0
var _edge_thought := 0
var _grow_base := 0.0                  # the start radius a step "groeit" grows from


func _ready() -> void:
	add_to_group("verhaal")
	missions = load_missions()
	_player = get_node_or_null(player_path)
	_hud = get_node_or_null(hud_path)
	shroud.setup(owner if owner else get_parent())
	if not use_shroud:
		shroud.open_everything()
	if _player == null or _hud == null:
		return
	_player.woke_up.connect(_on_woke_up, CONNECT_ONE_SHOT)
	_player.money_changed.connect(_on_money_changed)
	if _player.has_signal("bought"):
		_player.bought.connect(func(item_id: String) -> void: _goal_met("kopen", {"item": item_id}))
	if _player.has_signal("used"):
		_player.used.connect(func(item_id: String) -> void: _goal_met("gebruiken", {"item": item_id}))
	if _player.has_signal("deposited"):
		_player.deposited.connect(func(_euros: float) -> void: _goal_met("statiegeld", {}))
	if _player.has_signal("talked"):
		# done once the conversation is over: its "klaar_paginas" come after it, not under it
		_player.talk_ended.connect(func(persona: String) -> void: _goal_met.call_deferred("praten_met", {"persoon": persona}))
		# missions a conversation started (start_from_conversation): once it is over
		_player.talk_ended.connect(func(_persona: String) -> void: _start_waiting_from_talk.call_deferred())
	if _player.has_signal("checked"):
		_player.checked.connect(_on_checked)
	if _player.has_signal("inventory_changed"):
		_player.inventory_changed.connect(_on_inventory_changed)
	if _player.has_signal("got_item"):
		_player.got_item.connect(_on_got_item)
	if _hud.has_signal("menu_opened"):
		_hud.menu_opened.connect(func(tab: String) -> void: _goal_met("menu_open", {"tab": tab}))
	var characters := get_node_or_null(characters_path)
	if characters and characters.has_signal("arrived"):
		characters.arrived.connect(func(who: String) -> void: _goal_met("begeleiden", {"persoon": who}))
		characters.got_past.connect(func(who: String) -> void: _goal_met("werver", {"persoon": who}))
		characters.chase_near.connect(func(_who: String) -> void: _update_tracker())
	_apply_unlocks()


func _process(delta: float) -> void:
	_edge_clock -= delta
	_place_clock -= delta
	if _place_clock > 0.0 or _player == null:
		return
	_place_clock = PLACE_CHECK_SECONDS
	_track_walking()
	# into or out of the station with the cans of a mission: the marks to them, or to its door
	if _in_the_station() != _aimed_in_station:
		_aimed_in_station = not _aimed_in_station
		_reaim_bins()
		_update_tracker()
	_pages_on_coming_in()
	_follow_wanderers()
	for kind in ["naar_plek", "naar_persoon", "lopen", "stat_onder"]:
		_goal_met(kind, {})


# ------------------------------------------------------------------ the data

## Every mission of data/missies/ (in the order of the file names).
static func load_missions() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var files := Array(DirAccess.get_files_at(MISSIONS_FOLDER))
	files.sort()
	for file_name: String in files:
		if not file_name.ends_with(".json"):
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MISSIONS_FOLDER + file_name))
		if data is Dictionary and (data as Dictionary).has("id"):
			found.append(data)
		else:
			push_error("story: %s%s is no mission (no valid JSON, or no \"id\")" % [MISSIONS_FOLDER, file_name])
	return found


func mission(id: String) -> Dictionary:
	for data: Dictionary in missions:
		if str(data.id) == id:
			return data
	return {}


## Whether the step `step_id` of mission `id` is done.
func step_done(id: String, step_id: String) -> bool:
	return _done.has(id + "/" + step_id)


func is_finished(id: String) -> bool:
	return _finished.has(id)


func is_started(id: String) -> bool:
	return _started.has(id)


## The step under way of a mission (the first not done that is not optional), or {} when
## all are.
func current_step(data: Dictionary) -> Dictionary:
	for step: Dictionary in data.get("stappen", []):
		if not step.get("optioneel", false) and not step_done(str(data.id), str(step.id)):
			return step
	return {}


## The steps that can be done now: the one under way and the optional ones it has reached
## (until the mission is done).
func open_steps(data: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if _finished.has(str(data.id)):
		return found
	for step: Dictionary in data.get("stappen", []):
		if step_done(str(data.id), str(step.id)):
			continue
		found.append(step)
		if not step.get("optioneel", false):
			break
	return found


## Whether `what` ("menu", "bedelen") is unlocked.
func is_unlocked(what: String) -> bool:
	return _flags.has(what) or not UNLOCKABLE.has(what)


## Whether a skill check (or another flag of the story) has passed: "check:overtuigen_wim".
func has_flag(flag: String) -> bool:
	return _flags.has(flag)


## The places that stay marked on the maps (a mission's "markeringen"): key -> world x, z.
func markers() -> Dictionary:
	return _markers


# ------------------------------------------------------------------ the prologue and starting

func _on_woke_up() -> void:
	await get_tree().create_timer(prologue_delay).timeout
	# the missions that start after the prologue: their first pages in the same box
	var starting := missions.filter(func(data: Dictionary) -> bool: return str(data.get("start", "")) == "na_proloog")
	var pages := prologue_pages()
	for data: Dictionary in starting:
		pages.append_array(_pages(data.get("start_paginas", []), _banner(data), data))
	_hud.show_story(pages, func() -> void:
		for data: Dictionary in starting:
			start_mission(data, false))


## The pages of the prologue.
func prologue_pages() -> Array:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROLOGUE_FILE))
	if not data is Dictionary:
		push_error("story: %s is no valid JSON" % PROLOGUE_FILE)
		return []
	var banner := {"banner_kind": str(data.get("banner_soort", "")), "banner": str(data.get("banner", ""))}
	return _pages(data.get("paginas", []), banner, {})


## Starts every mission that starts on `trigger` ("na_proloog", "na:<mission id>").
func _start_missions(trigger: String) -> void:
	var followed := false
	for data: Dictionary in missions:
		if str(data.get("start", "")) == trigger and not _started.has(str(data.id)):
			start_mission(data)
			# the mission that follows on the one just done is the one you follow now (the
			# tracker went on to another open one when that was done: GameHud.set_quests)
			if trigger.begins_with("na:") and not followed and _hud and _hud.has_method("track_quest"):
				_hud.track_quest(str(data.id))
				followed = true


## A conversation brings about a mission (a node's "gevolg": "missie:<id>", Conversations): it
## starts once the conversation is over (its pages and notice after it, not under it). A
## mission meant to start this way has "start": "gesprek" (nothing else starts it).
func start_from_conversation(mission_id: String) -> void:
	if mission(mission_id).is_empty():
		push_warning("verhaal: een gesprek start missie '%s', die bestaat niet" % mission_id)
		return
	if not _started.has(mission_id) and not _waiting_from_talk.has(mission_id):
		_waiting_from_talk.append(mission_id)


func _start_waiting_from_talk() -> void:
	var waiting := _waiting_from_talk.duplicate()
	_waiting_from_talk.clear()
	for mission_id: String in waiting:
		start_mission(mission(mission_id))
		if _hud and _hud.has_method("track_quest"):
			_hud.track_quest(mission_id)


## Starts a mission: in the tracker, its first pages (unless `with_pages` is off: they were
## shown already) and the notice at the top.
func start_mission(data: Dictionary, with_pages := true) -> void:
	if _started.has(str(data.id)):
		return
	_started.append(str(data.id))
	_skip_steps(data)
	_begin_steps(data)
	_update_tracker()
	var title := str(data.get("titel", ""))
	var pages := _pages(data.get("start_paginas", []), _banner(data), data) if with_pages else []
	if pages.is_empty():
		_hud.show_mission(title)
	else:
		_hud.show_story(pages, func() -> void: _hud.show_mission(title))
	_check_now(data)


## Steps that do not apply to this character ("overslaan_als": {"startgeld_minstens": 2.0}:
## it starts with that much money or more) are done at once, without XP or pages.
func _skip_steps(data: Dictionary) -> void:
	var start_money := float(PlayerCharacter.chosen_archetype().get("start_money", 0))
	var steps: Array = data.get("stappen", [])
	for index in steps.size():
		var step: Dictionary = steps[index]
		var skip_when: Dictionary = step.get("overslaan_als", {})
		if skip_when.has("startgeld_minstens") and start_money >= float(skip_when.startgeld_minstens):
			_done[str(data.id) + "/" + str(step.id)] = true
			_xp_given["%s/%d" % [str(data.id), index]] = true


## Every step of `data` that can be done now and has not begun: what it does as it begins
## ("zet_stats", "ontgrendelt", "opent", the characters it needs) and where it points to.
func _begin_steps(data: Dictionary) -> void:
	for step in open_steps(data):
		var key := _key(data, step)
		if _begun.has(key):
			continue
		_begun[key] = {"from": _player.global_position if _player else Vector3.ZERO, "walked": 0.0}
		for stat_name: String in step.get("zet_stats", {}):
			if _player and _player.has_method("change_stat"):
				var now: Vector2 = _player.stat(stat_name)
				_player.change_stat(stat_name, float(step.zet_stats[stat_name]) - now.x)
		for what in step.get("ontgrendelt", []):
			unlock(str(what))
		var opened := false
		for area in step.get("opent", []):
			opened = shroud.open_area(str(area)) or opened
		if opened:
			shroud_changed.emit()
		_prepare_characters(data, step)
		_prepare_cans(step)
		_open_to(step)
		_aim(data, step)


## The characters a step needs: where they stand, who they walk with.
func _prepare_characters(data: Dictionary, step: Dictionary) -> void:
	var characters := get_node_or_null(characters_path)
	if characters == null:
		return
	var goal: Dictionary = step.get("doel", {})
	var who := str(goal.get("persoon", ""))
	match str(goal.get("soort", "")):
		"naar_persoon", "praten_met":
			if characters.has_method("has_character") and characters.has_character(who):
				characters.appear(who)
		"begeleiden":
			var points: Array = []
			for place_key in goal.get("route", []):
				var at := _place(str(place_key))
				if at != Vector2.INF:
					points.append(at)
			characters.lead(who, points, bool(goal.get("wacht", true)))
		"werver":
			characters.in_the_way(who, float(goal.get("straal", 9.0)), _place(str(goal.get("plek", ""))), _place(str(goal.get("voorbij", ""))))
	var chase_data: Dictionary = step.get("achtervolgen", {})
	if not chase_data.is_empty() and characters.has_method("chase"):
		characters.chase(str(chase_data.get("persoon", "")), chase_data.get("groep", []),
			_pages(chase_data.get("eerst_paginas", []), _banner(data), data))
	for talker: String in step.get("gesprekken", {}):
		characters.set_talk(talker, str(step.gesprekken[talker]))


## A step that sends you to the bins ("plekken" "blikjes") with a goal "verzamelen" and
## "blikjes_buiten" (how many lie outside; the rest, "blikjes_station", in a bin on a platform of
## Den Haag Centraal, behind the gates: Station.put_mission_can): exactly that many cans in
## the free bins nearest the start and none in the others round it, no new ones while the step
## runs (LitterBins.keep_empty_*), and the start area just big enough for them.
func _prepare_cans(step: Dictionary) -> void:
	if str(step.get("plekken", {}).get("soort", "")) != "blikjes" or not step.has("blikjes_buiten"):
		return
	var bins := get_node_or_null(bins_path)
	if bins == null or not bins.has_method("fill_near") or shroud.start_centre == Vector2.INF:
		return
	var outside := int(step.blikjes_buiten)
	# "in_zicht": only bins in sight of the start (on the square before Centraal, not behind it)
	var in_sight := bool(step.plekken.get("in_zicht", false))
	var farthest: float = bins.fill_near(shroud.start_centre, outside, CANS_ALONE_WITHIN, in_sight)
	bins.set("keep_empty_round", shroud.start_centre)
	bins.set("keep_empty_radius", INF)
	if shroud.set_start_radius(farthest + 8.0):
		shroud_changed.emit()


## Whether a mission wants a can in a bin on a platform of Den Haag Centraal now (Station asks
## as the player comes in): a step with "blikjes_station" under way, not all of them found yet.
func wants_station_can() -> bool:
	return station_cans_wanted() > 0


## How many cans a mission still wants in Den Haag Centraal (Station.put_mission_can: the
## first on a platform, the second on a track): what the step with "blikjes_station" still
## lacks, at most its "blikjes_station"; 0 when no such step is under way.
func station_cans_wanted() -> int:
	for id in _started:
		var data := mission(id)
		for step in open_steps(data):
			if int(step.get("blikjes_station", 0)) > 0:
				var goal: Dictionary = step.get("doel", {})
				var lacking := int(goal.get("aantal", 1)) - _count_of(str(goal.get("item", "blikje")))
				return clampi(lacking, 0, int(step.blikjes_station))
	return 0


## Where the cans the story wants lie in the station, world x, z (Station: as the player
## comes in and takes one; none once out): the step points to them instead of to Centraal.
func set_station_cans(spots: Array) -> void:
	if spots == _station_cans:
		return
	_station_cans = spots.duplicate()
	_reaim_bins()
	_update_tracker()


## Pages a step shows as its items come in ("tussen_paginas": [{"bij": 3, "paginas": [...]}]: at
## the third), each once.
func _pages_between() -> void:
	for id in _started:
		var data := mission(id)
		for step in open_steps(data):
			var item := str(step.get("doel", {}).get("item", ""))
			for between: Dictionary in step.get("tussen_paginas", []):
				var flag := "tussen:%s/%d" % [_key(data, step), int(between.get("bij", 0))]
				if not _flags.has(flag) and _count_of(item) >= int(between.get("bij", 0)):
					_flags[flag] = true
					var pages := _pages(between.get("paginas", []), _banner(data), data)
					if not pages.is_empty():
						_hud.show_story(pages)


## Pages a step shows once as the player comes into a building ("bij_binnenkomst": {"binnen":
## "centraal" (a kind of Interiors), "vanaf": 4 (at least that many of the goal's item in the
## pockets), "ontgrendelt": ["springen"], "paginas": [...]}): once per game (a flag), what it
## unlocks with it. Looked at on the place clock (_process).
func _pages_on_coming_in() -> void:
	var interiors := get_node_or_null(interiors_path)
	if interiors == null or not interiors.has_method("is_inside") or not interiors.is_inside():
		return
	var inside: Variant = interiors.get("_inside")
	var kind := str((inside as Dictionary).get("kind", "")) if inside is Dictionary else ""
	if kind == "" or (_hud and _hud.has_method("is_showing_story") and _hud.is_showing_story()):
		return
	for id in _started:
		var data := mission(id)
		for step in open_steps(data):
			var coming_in: Dictionary = step.get("bij_binnenkomst", {})
			if coming_in.is_empty() or str(coming_in.get("binnen", "")) != kind:
				continue
			var flag := "binnenkomst:%s" % _key(data, step)
			var item := str(step.get("doel", {}).get("item", ""))
			if _flags.has(flag) or _count_of(item) < int(coming_in.get("vanaf", 0)):
				continue
			_flags[flag] = true
			for what in coming_in.get("ontgrendelt", []):
				unlock(str(what))
			var pages := _pages(coming_in.get("paginas", []), _banner(data), data)
			if not pages.is_empty():
				_hud.show_story(pages)
			return


## A step that opens the start area up to the nearest supermarket ("opent_tot": "supermarkt").
func _open_to(step: Dictionary) -> void:
	if not step.has("opent_tot"):
		return
	var target := _grow_target(str(step.opent_tot), 0)
	if target != Vector2.INF and shroud.set_start_radius(shroud.radius_to(target)):
		shroud_changed.emit()


## Unlocks `what` ("menu": the game menu, "bedelen": asking people for change).
func unlock(what: String) -> void:
	if _flags.has(what):
		return
	_flags[what] = true
	_apply_unlocks()
	unlocked.emit(what)


func _apply_unlocks() -> void:
	if _hud and _hud.has_method("set_menu_locked"):
		_hud.set_menu_locked(not is_unlocked("menu"))


# ------------------------------------------------------------------ goals

## Something happened (`kind` a goal kind, `what` what of it): every step that can be done
## now of a mission with a goal it meets is done.
func _goal_met(kind: String, what: Dictionary) -> void:
	for id in _started.duplicate():
		var data := mission(id)
		for step in open_steps(data):
			var goal: Dictionary = step.get("doel", {})
			if str(goal.get("soort", "")) == kind and _meets(data, step, goal, what):
				_complete(data, step)


## Looks at the goals of `data` that may be met already (items in the pockets, a stat).
func _check_now(data: Dictionary) -> void:
	for kind in ["verzamelen", "stat_onder", "geld_verdiend", "geld_op_zak", "naar_plek"]:
		for step in open_steps(data):
			var goal: Dictionary = step.get("doel", {})
			if str(goal.get("soort", "")) == kind and _meets(data, step, goal, {}):
				_complete(data, step)
				return


func _meets(data: Dictionary, step: Dictionary, goal: Dictionary, what: Dictionary) -> bool:
	match str(goal.get("soort", "")):
		"geld_verdiend":
			return money_towards_goal() + 0.001 >= float(goal.get("bedrag", 0.0))
		"geld_op_zak":
			return _player != null and float(_player.money) + 0.001 >= float(goal.get("bedrag", 0.0))
		"kopen", "gebruiken":
			return str(what.get("item", "")) == str(goal.get("item", ""))
		"verzamelen":
			return _count_of(str(goal.get("item", ""))) >= int(goal.get("aantal", 1))
		"statiegeld", "check_geslaagd":
			return true
		"praten_met":
			var who := str(goal.get("persoon", "iemand"))
			return who == "iemand" or who == str(what.get("persoon", ""))
		"naar_plek":
			var place := _place(str(goal.get("plek", "")))
			return place != Vector2.INF and _feet().distance_to(place) <= float(goal.get("straal", 10.0))
		"naar_persoon":
			var at := _character_spot(str(goal.get("persoon", "")))
			return at != Vector2.INF and _feet().distance_to(at) <= float(goal.get("straal", 6.0))
		"lopen":
			return float(_begun.get(_key(data, step), {}).get("walked", 0.0)) >= float(goal.get("meter", 3.0))
		"stat_onder":
			if _player == null or not _player.has_method("stat"):
				return false
			return (_player.stat(str(goal.get("stat", ""))) as Vector2).x < float(goal.get("waarde", 0.0))
		"menu_open":
			var tab := str(goal.get("tab", ""))
			return tab == "" or tab == str(what.get("tab", ""))
		"check":
			return str(what.get("check", "")) == str(goal.get("check", ""))
		"begeleiden", "werver":
			return str(what.get("persoon", "")) == str(goal.get("persoon", ""))
	return false


## Marks a step done in the step of a test or a tool (as if its goal was met), with all that
## the step opens on the way (_grant_what_it_opens: skipped in debug, the menu, the merchants,
## the areas are open as if it was played).
func complete_step(id: String, step_id: String) -> void:
	var data := mission(id)
	for step: Dictionary in data.get("stappen", []):
		if str(step.id) == step_id and not step_done(id, step_id):
			_grant_what_it_opens(data, step)
			_complete(data, step)


## Finishes a whole mission at once (tests and tools; the mission jump of debug): every step
## that is not done, with what each opens (_grant_what_it_opens).
func complete_mission(id: String) -> void:
	var data := mission(id)
	if not _started.has(id):
		start_mission(data, false)
	for step: Dictionary in data.get("stappen", []):
		if not step.get("optioneel", false) and not step_done(id, str(step.id)):
			_grant_what_it_opens(data, step)
			_complete(data, step)


## Everything `step` opens while it is played, given at once (a step skipped by complete_step
## or complete_mission: the mission jump of debug): what it unlocks as it begins ("ontgrendelt":
## the menu, the merchants, begging), the areas it opens ("opent", "opent_tot"), the area grown
## all the way ("groeit"), and what coming into a building unlocks ("bij_binnenkomst": jumping;
## its pages then never show). The rest (pages, rewards) as _complete does it.
func _grant_what_it_opens(data: Dictionary, step: Dictionary) -> void:
	for what in step.get("ontgrendelt", []):
		unlock(str(what))
	var coming_in: Dictionary = step.get("bij_binnenkomst", {})
	for what in coming_in.get("ontgrendelt", []):
		unlock(str(what))
	if not coming_in.is_empty():
		_flags["binnenkomst:%s" % _key(data, step)] = true
	var opened := false
	for area in step.get("opent", []):
		opened = shroud.open_area(str(area)) or opened
	var grow: Dictionary = step.get("groeit", {})
	var grow_to := str(grow.get("tot", step.get("opent_tot", "")))
	if grow_to != "":
		var target := _grow_target(grow_to, 0)
		if target != Vector2.INF and shroud.set_start_radius(shroud.radius_to(target)):
			opened = true
	if opened:
		shroud_changed.emit()


func _complete(data: Dictionary, step: Dictionary) -> void:
	var id := str(data.id)
	var key := _key(data, step)
	if _done.has(key):
		return
	_done[key] = true
	_targets.erase(key)
	var chase_data: Dictionary = step.get("achtervolgen", {})
	var characters := get_node_or_null(characters_path)
	if not chase_data.is_empty() and characters and characters.has_method("stop_chasing"):
		characters.stop_chasing.call_deferred(str(chase_data.get("persoon", "")))
	if step.has("blikjes_buiten"):
		var bins := get_node_or_null(bins_path)
		if bins:
			bins.set("keep_empty_radius", 0.0)   # the bins fill up again
	var whole_mission := current_step(data).is_empty() and not _finished.has(id)
	# the reward first (quietly: its screen shows it), so the tracker does not give it again
	var reward := _give_reward(data, step, whole_mission)
	if whole_mission:
		_finished[id] = true
		_finish(data)
	else:
		_begin_steps(data)
	_update_tracker()
	var pages := _pages(step.get("klaar_paginas", []), _banner(data), data)
	if _hud.has_method("play_task_done"):
		_hud.play_task_done(whole_mission)   # a triumph tune, a longer one for the whole mission
	if whole_mission:
		pages.append_array(_pages(data.get("einde_paginas", []), _banner(data), data))
	if not pages.is_empty():
		_hud.show_story(pages)
	# the reward screen after the pages (it waits for them); the next missions after that
	var then := (func() -> void: _start_missions_later("na:" + id)) if whole_mission else Callable()
	if _hud.has_method("show_reward"):
		_hud.show_reward(reward, then)
	elif then.is_valid():
		then.call_deferred()
	if not whole_mission:
		_check_now.call_deferred(data)


## A whole mission done: the areas it opens, the places it marks, and again later when it
## repeats ("herhaalbaar").
func _finish(data: Dictionary) -> void:
	var opened := false
	for area in data.get("opent_na_afloop", []):
		opened = shroud.open_area(str(area)) or opened
	if opened:
		shroud_changed.emit()
	var marked := false
	for place_key in data.get("markeringen", []):
		var at := _place(str(place_key))
		if at != Vector2.INF and not _markers.has(str(place_key)):
			_markers[str(place_key)] = at
			marked = true
	if marked:
		markers_changed.emit()
	var characters := get_node_or_null(characters_path)
	if characters and characters.has_method("set_talk"):
		for talker: String in data.get("gesprekken_na_afloop", {}):
			characters.set_talk(talker, str(data.gesprekken_na_afloop[talker]))
	if data.get("herhaalbaar", false):
		get_tree().create_timer(float(data.get("herhaal_na", 120.0))).timeout.connect(func() -> void: _repeat(data))


## A repeatable mission again from the start (its XP again too).
func _repeat(data: Dictionary) -> void:
	var id := str(data.id)
	if not _finished.has(id):
		return
	_finished.erase(id)
	_started.erase(id)
	var steps: Array = data.get("stappen", [])
	for index in steps.size():
		var key := _key(data, steps[index])
		_done.erase(key)
		_begun.erase(key)
		_targets.erase(key)
		_xp_given.erase("%s/%d" % [id, index])
	_xp_given.erase(id)
	start_mission(data)


## What `step` of mission `data` gives now it is done (and the mission, `whole_mission`): its
## XP not given yet (once: _xp_given) and its items ("geeft"), into the player quietly;
## returned as a reward for the reward screen (GameHud.show_reward).
func _give_reward(data: Dictionary, step: Dictionary, whole_mission: bool) -> Dictionary:
	var id := str(data.id)
	var xp := 0
	var steps: Array = data.get("stappen", [])
	var step_key := "%s/%d" % [id, steps.find(step)]
	if not _xp_given.has(step_key):
		_xp_given[step_key] = true
		xp += int(step.get("xp", 0))
	var gifts: Array = step.get("geeft", []).duplicate()
	if whole_mission:
		if not _xp_given.has(id):
			_xp_given[id] = true
			xp += int(data.get("xp", 0))
		gifts.append_array(data.get("geeft", []))
	var items: Array = []
	for gift: Dictionary in gifts:
		var item_id := str(gift.get("item", ""))
		var count := maxi(int(gift.get("aantal", 1)), 1)
		if item_id != "" and _player and _player.has_method("add_item") and _player.add_item(item_id, count, true):
			items.append({"item": item_id, "count": count})
	if xp > 0 and _player and _player.has_method("add_xp"):
		_player.add_xp(float(xp), true)
	var title := str(data.get("titel", "")) if whole_mission else _fill(str(_step_text(data, step)), data, step)
	return {"heading": "MISSIE VOLBRACHT" if whole_mission else "TAAK VOLBRACHT", "title": title,
		"xp": xp, "items": items}


func _start_missions_later(trigger: String) -> void:
	_start_missions(trigger)


## The money that counts for a goal "geld_verdiend": what was found or earned since the
## start and is still in the wallet. Spent money counts off (the mission and the wallet in
## the corner never disagree: found € 1,50, spent € 0,50, then both say € 1,00), and the
## money a character starts with never counts (the found money can be no more than what
## the player has now, and no more than what was found). The goal allows a tenth of a cent
## for the sums of coins (ten coins of € 0,20 add up to 1.9999... in floats).
func money_towards_goal() -> float:
	if _player == null:
		return 0.0
	return maxf(minf(float(_player.money_earned), float(_player.money)), 0.0)


func _on_money_changed() -> void:
	_goal_met("geld_verdiend", {})
	_goal_met("geld_op_zak", {})
	_update_tracker()   # the progress in the text


## The pockets changed: goals about items, the start area that grows with them, the text.
func _on_inventory_changed() -> void:
	_grow_with_items()
	_reaim_bins()
	_pages_between()
	_goal_met("verzamelen", {})
	_update_tracker()


## Something picked up (PlayerController.got_item: not a quiet reward): the first of the goal
## item of an open step with "eerste_scherm" ({"kop", "titel"}) shows in the reward screen
## instead of the note over the player; once per game (a flag, kept in the snapshot).
func _on_got_item(item_id: String, count: int) -> void:
	for id in _started:
		var data := mission(id)
		for step in open_steps(data):
			var first: Dictionary = step.get("eerste_scherm", {})
			if first.is_empty() or str(step.get("doel", {}).get("item", "")) != item_id:
				continue
			var flag := "eerste:%s" % _key(data, step)
			if _flags.has(flag) or not _hud.has_method("show_reward"):
				continue
			_flags[flag] = true
			_player.announced_elsewhere()
			_hud.show_reward({"heading": str(first.get("kop", "GEVONDEN")), "title": str(first.get("titel", "")),
				"items": [{"item": item_id, "count": count}]})
			return


## The bins a step points to change as cans are taken: worked out again.
func _reaim_bins() -> void:
	for id in _started:
		var data := mission(id)
		for step in open_steps(data):
			if str(step.get("plekken", {}).get("soort", "")) == "blikjes":
				_targets.erase(_key(data, step))
				_aim(data, step)


func _on_checked(check_id: String, passed: bool) -> void:
	if not passed:
		return
	_flags["check:" + check_id] = true
	_goal_met("check", {"check": check_id})


func _count_of(item_id: String) -> int:
	if _player == null:
		return 0
	return int(_player.inventory.get(item_id, 0))


func _feet() -> Vector2:
	var at: Vector3 = _player.global_position
	return Vector2(at.x, at.z)


func _key(data: Dictionary, step: Dictionary) -> String:
	return str(data.id) + "/" + str(step.id)


## How far the player walked during the steps that count it ("lopen").
func _track_walking() -> void:
	var feet: Vector3 = _player.global_position
	for key: String in _begun:
		var track: Dictionary = _begun[key]
		var from: Vector3 = track.from
		var step_length := Vector2(feet.x - from.x, feet.z - from.z).length()
		if step_length < 12.0:   # not a jump (into a building and out again)
			track.walked = float(track.walked) + step_length
		track.from = feet


# ------------------------------------------------------------------ the shroud

## Whether the player may walk on the world point (x, z) (PlayerController asks before every
## step); at the edge now and then a thought.
func may_walk(x: float, z: float) -> bool:
	if shroud.is_open(x, z):
		return true
	if _edge_clock <= 0.0 and _hud and _hud.has_method("show_thought"):
		_edge_clock = EDGE_THOUGHT_SECONDS
		_hud.show_thought(EDGE_THOUGHTS[_edge_thought % EDGE_THOUGHTS.size()])
		_edge_thought += 1
	return false


## The start area grows with the items of a step "groeit" ({"per": "blikje", "tot":
## "supermarkt"}): with every one of the goal's "aantal" a share of the way to the nearest
## supermarket, all of it with the last.
func _grow_with_items() -> void:
	for id in _started:
		var data := mission(id)
		for step in open_steps(data):
			var grow: Dictionary = step.get("groeit", {})
			if grow.is_empty():
				continue
			var goal: Dictionary = step.get("doel", {})
			var wanted := maxi(int(goal.get("aantal", 1)), 1)
			var share := clampf(float(_count_of(str(grow.get("per", goal.get("item", ""))))) / wanted, 0.0, 1.0)
			var target := _grow_target(str(grow.get("tot", "supermarkt")), 0)
			if target == Vector2.INF:
				continue
			var base := _grow_base if _grow_base > 0.0 else _start_radius_of_data()
			var radius := lerpf(base, maxf(shroud.radius_to(target), base), share)
			if shroud.set_start_radius(radius):
				shroud_changed.emit()


## The start radius in data/gebieden.json (what the area grows from).
func _start_radius_of_data() -> float:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(Shroud.AREAS_FILE))
	return float((data as Dictionary).get("start", {}).get("straal", 45.0)) if data is Dictionary else 45.0


## What an area grows to: the nearest supermarket from the start ("supermarkt"), skipping
## `skip` of them (the broken one), or a place of the map.
func _grow_target(what: String, skip: int) -> Vector2:
	if what == "supermarkt":
		var shops := supermarkets(shroud.start_centre, skip + 1)
		return shops[skip] if shops.size() > skip else Vector2.INF
	return _place(what)


## A deposit machine is about to open in the supermarket whose doors are at `shop` (world
## x, z): the text to show instead when it is out of order ("" when it works). The first
## machine tried in a step "storing" is; then the step points to the other supermarkets
## and the start area grows to the next one.
func machine_out_of_order(shop: Vector2) -> String:
	for id in _started:
		var data := mission(id)
		for step in open_steps(data):
			var broken: Dictionary = step.get("storing", {})
			if broken.is_empty():
				continue
			var key := _key(data, step)
			if not _broken.has(key):
				_broken[key] = shop
				_on_broken(data, step)
			if (_broken[key] as Vector2).distance_to(shop) < 12.0:
				return str(broken.get("tekst", "BUITEN GEBRUIK"))
	return ""


func _on_broken(data: Dictionary, step: Dictionary) -> void:
	var key := _key(data, step)
	var buyer := str(step.get("storing", {}).get("persoon", ""))
	if buyer != "":
		_appear_wandering(buyer)
	_targets.erase(key)
	_aim(data, step)
	var shops: Array = _targets.get(key, [])
	# to another supermarket: the area grows to it; to someone who buys cans: it stays as it is
	if buyer == "" and not shops.is_empty() and shroud.set_start_radius(shroud.radius_to(shops[0])):
		shroud_changed.emit()
	_update_tracker()
	var pages := _pages(step.get("storing", {}).get("paginas", []), _banner(data), data)
	if not pages.is_empty():
		_hud.show_story(pages)


## `who` (a character with "zwerft", Characters.wander) comes into town and wanders there for
## good: a flag "verschenen:<who>" (kept by snapshot/restore, which brings it back).
func _appear_wandering(who: String) -> void:
	_flags["verschenen:" + who] = true
	var characters := get_node_or_null(characters_path)
	if characters and characters.has_method("wander"):
		characters.wander(who)


## Whether `who` came into town to wander there (_appear_wandering).
func has_appeared(who: String) -> bool:
	return _flags.has("verschenen:" + who)


## The marks of a step sending you to someone wandering about follow them (_aim "storing"
## "persoon"): aimed again when they have moved a few metres.
func _follow_wanderers() -> void:
	for id in _started:
		var data := mission(id)
		for step in open_steps(data):
			var buyer := str(step.get("storing", {}).get("persoon", ""))
			var key := _key(data, step)
			if buyer == "" or not _broken.has(key):
				continue
			var at := _character_spot(buyer)
			var aimed: Array = _targets.get(key, [])
			if at != Vector2.INF and (aimed.is_empty() or (aimed[0] as Vector2).distance_to(at) > 2.0):
				_targets.erase(key)
				_aim(data, step)
				_update_tracker()


## Whether the deposit machine of the step under way broke already (its text changes).
func _is_broken(data: Dictionary, step: Dictionary) -> bool:
	return _broken.has(_key(data, step))


# ------------------------------------------------------------------ where to go

## The places `step` of mission `data` points to, worked out once as it begins.
func _aim(data: Dictionary, step: Dictionary) -> void:
	var key := _key(data, step)
	if _targets.has(key):
		return
	var where: Dictionary = step.get("plekken", {})
	var spots: Array = []
	var feet := _feet() if _player else Vector2.ZERO
	match str(where.get("soort", "")):
		"snackbars":
			spots = _open_only(snack_bars(feet, 12)).slice(0, int(where.get("aantal", 3)))
		"supermarkten":
			var shops := _open_or_nearest(supermarkets(feet, 12))
			var buyer := str(step.get("storing", {}).get("persoon", ""))
			if _broken.has(key) and buyer != "":
				# the machine broke: to the one who buys cans instead ("storing" "persoon")
				var at := _character_spot(buyer)
				shops = [at] if at != Vector2.INF else []
			elif _broken.has(key):
				shops = supermarkets(feet, 12).filter(func(spot: Vector2) -> bool: return spot.distance_to(_broken[key]) >= 12.0)
			spots = shops.slice(0, int(where.get("aantal", 1)))
		"blikjes":
			var bins := get_node_or_null(bins_path)
			if bins and bins.has_method("can_spots"):
				# only the open ones (never one far off under the shroud)
				spots = bins.can_spots(feet, 12).filter(func(spot: Vector2) -> bool: return shroud.is_open(spot.x, spot.y)).slice(0, int(where.get("aantal", 3)))
			# the cans outside found: the ones left are in the station, behind the gates (in there:
			# the cans themselves, set_station_cans)
			var item := str(step.get("doel", {}).get("item", "blikje"))
			if int(step.get("blikjes_station", 0)) > 0 and _count_of(item) >= int(step.get("blikjes_buiten", 0)):
				var station := _station_entrance()
				spots = [station] if station != Vector2.INF else []
				if _in_the_station():
					spots = _station_cans.duplicate()
		"plek":
			var place := _place(str(where.get("plek", "")))
			if place != Vector2.INF:
				spots = [place]
		"plekken":
			for place_key in where.get("plekken", []):
				var place := _place(str(place_key))
				if place != Vector2.INF:
					spots.append(place)
	var goal: Dictionary = step.get("doel", {})
	if spots.is_empty():
		match str(goal.get("soort", "")):
			"naar_plek":
				var place := _place(str(goal.get("plek", "")))
				if place != Vector2.INF:
					spots = [place]
			"naar_persoon", "praten_met":
				var at := _character_spot(str(goal.get("persoon", "")))
				if at != Vector2.INF:
					spots = [at]
			"begeleiden":
				var route: Array = goal.get("route", [])
				if not route.is_empty():
					var last := _place(str(route[-1]))
					if last != Vector2.INF:
						spots = [last]
	_targets[key] = spots


## The spots of `spots` that are open (Shroud), all of them when none is.
func _open_only(spots: Array) -> Array:
	var open := spots.filter(func(spot: Vector2) -> bool: return shroud.is_open(spot.x, spot.y))
	return open if not open.is_empty() else spots


func _open_or_nearest(spots: Array) -> Array:
	return _open_only(spots)


## Where you go into Den Haag Centraal (world x, z): the door of its way in (Interiors
## ways_in, kind "centraal") nearest the place "centraal" on the square; that place itself
## when the town has no interiors.
func _station_entrance() -> Vector2:
	var middle := _place("centraal")
	var interiors := get_node_or_null(interiors_path)
	var best := Vector2.INF
	if interiors and interiors.has_method("ways_in") and middle != Vector2.INF:
		for way_in: Dictionary in interiors.ways_in():
			if str(way_in.get("kind", "")) != "centraal" or not way_in.get("door") is Vector3:
				continue
			var door := Vector2((way_in.door as Vector3).x, (way_in.door as Vector3).z)
			if best == Vector2.INF or door.distance_to(middle) < best.distance_to(middle):
				best = door
	return best if best != Vector2.INF else middle


## Whether the player is in the station with the story's cans (set_station_cans: none once
## out; and the player near them, so a stale list never points into the station from outside).
func _in_the_station() -> bool:
	if _station_cans.is_empty() or _player == null:
		return false
	var feet := Vector2(_player.global_position.x, _player.global_position.z)
	return _station_cans.any(func(spot: Vector2) -> bool: return spot.distance_to(feet) < STATION_CANS_REACH)


## A named place of the map (the "places" metadata of the city), INF when there is none.
func _place(place_key: String) -> Vector2:
	var root: Node = owner if owner else get_parent()
	var places: Dictionary = root.get_meta("places", {}) if root else {}
	return places.get(place_key, Vector2.INF)


## Where a character of data/gesprekken/personages.json stands now (world x, z), INF when
## it is not in town.
func _character_spot(who: String) -> Vector2:
	var characters := get_node_or_null(characters_path)
	if characters == null or not characters.has_method("spot_of"):
		return Vector2.INF
	return characters.spot_of(who)


## The snack bars nearest to `near` (world x, z), `count` of them: the cells of the Gebouwen
## map with a snack bar's shop front (fronts within 8 m of each other are one bar).
func snack_bars(near: Vector2, count := 3) -> Array:
	return _fronts([SNACK_BAR_FRONT], near, count)


## The supermarkets nearest to `near` (world x, z), `count` of them: their doors.
func supermarkets(near: Vector2, count := 3) -> Array:
	return _fronts(SUPERMARKET_DOORS, near, count)


func _fronts(names: Array, near: Vector2, count: int) -> Array:
	var buildings := get_node_or_null(buildings_path) as GridMap
	if buildings == null or buildings.mesh_library == null:
		return []
	var spots: Array = []
	for item in buildings.mesh_library.get_item_list():
		var item_name := buildings.mesh_library.get_item_name(item)
		if not names.any(func(part: String) -> bool: return item_name.contains(part)):
			continue
		for cell in buildings.get_used_cells_by_item(item):
			var at := buildings.to_global(buildings.map_to_local(cell))
			var spot := Vector2(at.x, at.z)
			if not spots.any(func(other: Vector2) -> bool: return other.distance_to(spot) < 8.0):
				spots.append(spot)
	spots.sort_custom(func(first: Vector2, second: Vector2) -> bool: return first.distance_to(near) < second.distance_to(near))
	return spots.slice(0, count)


# ------------------------------------------------------------------ the tracker

func _update_tracker() -> void:
	if _hud == null:
		return
	var quests: Array = []
	for id in _started:
		quests.append(_quest(mission(id)))
	_hud.set_quests(quests)
	_award_xp(quests)


## The text of a step now (its "tekst_storing" once its machine broke).
func _step_text(data: Dictionary, step: Dictionary) -> String:
	if step.has("tekst_storing") and _is_broken(data, step):
		return str(step.tekst_storing)
	return str(step.get("tekst", ""))


## The mission as the tracker and the quest log have it (GameHud.set_quests). A step
## "verborgen_tot_open" is left out until it can be done (or is done): not even locked; one
## that sends someone after you ("achtervolgen") until they are near you (_chasers_near).
## Every step keeps its "index" in the mission (the XP given for it, _award_xp).
func _quest(data: Dictionary) -> Dictionary:
	var id := str(data.id)
	var steps: Array = []
	var open := open_steps(data)
	var reached_current := false
	var hidden_left := 0
	var all_steps: Array = data.get("stappen", [])
	for index in all_steps.size():
		var step: Dictionary = all_steps[index]
		var done := step_done(id, str(step.id))
		var can_do := open.has(step)
		if step.get("verborgen_tot_open", false) and not done and (not can_do or not _chasers_near(step)):
			hidden_left += 1
			continue
		steps.append({"text": _fill(_step_text(data, step), data, step), "done": done,
			"locked": not done and not can_do and reached_current, "xp": int(step.get("xp", 0)),
			"optional": step.get("optioneel", false), "index": index,
			"targets": _targets.get(_key(data, step), []) if can_do else []})
		if can_do and not step.get("optioneel", false):
			reached_current = true
	var rewards: Array = data.get("beloningen", []).duplicate()
	if int(data.get("xp", 0)) > 0:
		rewards.append("+%d XP" % int(data.xp))
	return {"id": id, "kind": "zij" if str(data.get("soort", "verhaal")) == "zij" else "verhaal",
		"xp": int(data.get("xp", 0)), "label": str(data.get("label", "")), "title": str(data.get("titel", "")),
		"distance": "", "giver": str(data.get("gever", "")), "description": str(data.get("beschrijving", "")),
		"rewards": rewards, "steps": steps, "hidden_left": hidden_left, "done": is_finished(id)}


## Whether those a step sends after you ("achtervolgen") have come near you (always true for a
## step without them).
func _chasers_near(step: Dictionary) -> bool:
	var who := str(step.get("achtervolgen", {}).get("persoon", ""))
	if who == "":
		return true
	var characters := get_node_or_null(characters_path)
	return characters == null or not characters.has_method("is_chase_near") or bool(characters.is_chase_near(who))


## Gives the XP of every step done and every quest done (all its steps) that has not had it.
func _award_xp(quests: Array) -> void:
	if _player == null or not _player.has_method("add_xp"):
		return
	for quest: Dictionary in quests:
		var id := str(quest.get("id", quest.get("title", "")))
		var steps: Array = quest.get("steps", [])
		var all_done := not steps.is_empty() and int(quest.get("hidden_left", 0)) == 0
		for step_index in steps.size():
			var step: Dictionary = steps[step_index]
			if not step.get("done", false):
				if not step.get("optional", false):
					all_done = false
				continue
			var key := "%s/%d" % [id, int(step.get("index", step_index))]
			if not _xp_given.has(key):
				_xp_given[key] = true
				_player.add_xp(float(step.get("xp", 0)))
		if all_done and not _xp_given.has(id):
			_xp_given[id] = true
			_player.add_xp(float(quest.get("xp", 0)))


# ------------------------------------------------------------------ pages and texts

func _banner(data: Dictionary) -> Dictionary:
	return {"banner_kind": str(data.get("label", "")), "banner": str(data.get("titel", ""))}


## Pages of the data ({"soort", "tekst", "spreker", "als"}) as the story box has them; a page
## with "als": "check:<id>" only when that check passed.
func _pages(entries: Array, banner: Dictionary, data: Dictionary) -> Array:
	var pages: Array = []
	for entry: Dictionary in entries:
		if entry.has("als") and not _flags.has(str(entry.als)):
			continue
		var page := {"kind": str(entry.get("soort", "verhaal")), "text": _fill(str(entry.get("tekst", "")), data, {})}
		if entry.has("spreker"):
			page["speaker"] = str(entry.spreker)
			_as_the_character(page, str(entry.spreker), str(entry.get("stemming", "neutraal")))
		page.merge(banner)
		pages.append(page)
	return pages


## A line of a character of the story (its "spreker" in personages.json, Ome Wim): its face in
## the portrait (its look, its pose live from its figure in the world) and its babble, as in a
## conversation with it; nothing for any other speaker.
func _as_the_character(page: Dictionary, speaker_name: String, mood: String) -> void:
	var characters := get_node_or_null(characters_path)
	if characters == null or not characters.has_method("person_of"):
		return
	for who: String in Conversations.characters():
		if str((Conversations.characters()[who] as Dictionary).get("spreker", "")) != speaker_name:
			continue
		var person: Node3D = characters.person_of(who)
		if person == null or person.get("figure") == null:
			return
		var figure: Node3D = person.get("figure")
		page["portrait_look"] = figure.get("look")
		page["portrait_figure"] = figure
		if person.has_method("voice"):
			page["voice"] = person.voice()
			page["mood"] = mood
		return


## The placeholders of a text filled in (see the top).
func _fill(text: String, data: Dictionary, step: Dictionary) -> String:
	var archetype := PlayerCharacter.chosen_archetype()
	text = text.replace("{naam}", str(archetype.get("name", ""))).replace("{achtergrond}", str(archetype.get("story", "")))
	if text.contains("{geldregel}"):
		var lines: Dictionary = data.get("geldregel", {})
		text = text.replace("{geldregel}", str(lines.get("wel" if float(archetype.get("start_money", 0)) > 0.0 else "leeg", "")))
	if text.contains("{voortgang}"):
		var goal: Dictionary = step.get("doel", {})
		var progress := ""
		match str(goal.get("soort", "")):
			"geld_verdiend":
				if _player:
					progress = MoneyText.euros(minf(money_towards_goal(), float(goal.get("bedrag", 0.0))))
			"geld_op_zak":
				if _player:
					progress = MoneyText.euros(minf(float(_player.money), float(goal.get("bedrag", 0.0))))
			"verzamelen":
				var wanted := int(goal.get("aantal", 1))
				progress = "%d/%d" % [mini(_count_of(str(goal.get("item", ""))), wanted), wanted]
		text = text.replace("{voortgang}", progress)
	return text




# ------------------------------------------------------------------ tests

## The state to put back after a test (TownWorld.reset).
func snapshot() -> Dictionary:
	return {"started": _started.duplicate(), "done": _done.duplicate(), "finished": _finished.duplicate(),
		"targets": _targets.duplicate(true), "xp": _xp_given.duplicate(), "begun": _begun.duplicate(true),
		"flags": _flags.duplicate(), "broken": _broken.duplicate(), "markers": _markers.duplicate(), "station_cans": _station_cans.duplicate(),
		"shroud": shroud.snapshot()}


func restore(state: Dictionary) -> void:
	_started.assign(state.get("started", []))
	_done = state.get("done", {}).duplicate()
	_finished = state.get("finished", {}).duplicate()
	_targets = state.get("targets", {}).duplicate(true)
	_xp_given = state.get("xp", {}).duplicate()
	_begun = state.get("begun", {}).duplicate(true)
	_flags = state.get("flags", {}).duplicate()
	_broken = state.get("broken", {}).duplicate()
	_markers = state.get("markers", {}).duplicate()
	_station_cans = state.get("station_cans", []).duplicate()
	shroud.restore(state.get("shroud", {}))
	_apply_unlocks()
	# who came into town to wander there comes back (after Characters is cleared: deferred)
	for flag: String in _flags:
		if flag.begins_with("verschenen:"):
			_appear_wandering.call_deferred(flag.trim_prefix("verschenen:"))
	shroud_changed.emit()
	markers_changed.emit()
	_update_tracker()
