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
##   shows where to go on the minimap and the map ("plekken": the nearest "snackbars", one
##   "plek" or a list of "plekken" of the map), the later ones are locked (see-through).
##   A step is done when its goal ("doel") is met:
##     geld_verdiend  {"bedrag": 2.0}       found or earned money since the start
##     kopen          {"item": "kroket"}    bought (a snack bar: PlayerController.bought)
##     praten_met     {"persoon": "toerist"} talked to (a kind of passer-by from
##                                            data/gesprekken/voorbijgangers.json, or "iemand")
##     naar_plek      {"plek": "koekamp", "straal": 12}  come within "straal" m of a place
##   then its "klaar_paginas" show; when all are, the "einde_paginas".
##   {voortgang} in a step's text is how far its goal is (the money: "€ 1,20"), {geldregel} a
##   line of the mission's "geldregel" ("leeg" or "wel": whether your character starts
##   with money).
## A task done plays a triumph tune (GameHud.play_task_done), the whole mission a longer one.
## A step with "overslaan_als": {"startgeld_minstens": 2.0} is skipped (done at once, no XP)
## for a character that starts with that much money or more.
## Experience: every mission and every step has its own "xp", given once (PlayerController.add_xp)
## when the step is done and when the whole mission is; the tracker and the quest log show it.

const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const MISSIONS_FOLDER := "res://data/missies/"
const PROLOGUE_FILE := "res://data/verhaal/proloog.json"
## A snack bar's shop front (in the name of a Gebouwen item: "<style>/<style>_bg_snackbar").
const SNACK_BAR_FRONT := "_bg_snackbar"
## Seconds between two looks whether the player has come to a place (naar_plek).
const PLACE_CHECK_SECONDS := 0.5

@export var player_path := NodePath("../Speler")
@export var hud_path := NodePath("../HUD")
@export var buildings_path := NodePath("../Gebouwen")
## Seconds after waking before the prologue opens (the figure is up, the music has started).
@export var prologue_delay := 0.6

var missions: Array[Dictionary] = []   # the data of every mission, in order
var _player: Node
var _hud: Node
var _started: Array[String] = []        # ids of the missions under way or done, in order
var _done := {}                          # "mission id/step id" -> true
var _finished := {}                      # mission id -> true
var _targets := {}                       # "mission id/step id" -> Array of world x, z
var _xp_given := {}
var _place_clock := 0.0


func _ready() -> void:
	missions = load_missions()
	_player = get_node_or_null(player_path)
	_hud = get_node_or_null(hud_path)
	if _player == null or _hud == null:
		return
	_player.woke_up.connect(_on_woke_up, CONNECT_ONE_SHOT)
	_player.money_changed.connect(_on_money_changed)
	if _player.has_signal("bought"):
		_player.bought.connect(func(item_id: String) -> void: _goal_met("kopen", {"item": item_id}))
	if _player.has_signal("talked"):
		_player.talked.connect(func(persona: String) -> void: _goal_met("praten_met", {"persoon": persona}))


func _process(delta: float) -> void:
	_place_clock -= delta
	if _place_clock > 0.0 or _player == null:
		return
	_place_clock = PLACE_CHECK_SECONDS
	_goal_met("naar_plek", {})


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


## The step under way of a mission (the first not done), or {} when all are.
func current_step(data: Dictionary) -> Dictionary:
	for step: Dictionary in data.get("stappen", []):
		if not step_done(str(data.id), str(step.id)):
			return step
	return {}


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
	for data: Dictionary in missions:
		if str(data.get("start", "")) == trigger and not _started.has(str(data.id)):
			start_mission(data)


## Starts a mission: in the tracker, its first pages (unless `with_pages` is off: they were
## shown already) and the notice at the top.
func start_mission(data: Dictionary, with_pages := true) -> void:
	if _started.has(str(data.id)):
		return
	_started.append(str(data.id))
	_skip_steps(data)
	_aim(data)
	_update_tracker()
	var title := str(data.get("titel", ""))
	var pages := _pages(data.get("start_paginas", []), _banner(data), data) if with_pages else []
	if pages.is_empty():
		_hud.show_mission(title)
	else:
		_hud.show_story(pages, func() -> void: _hud.show_mission(title))


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


# ------------------------------------------------------------------ goals

## Something happened (`kind` a goal kind, `what` what of it): every step under way of a
## mission with a goal it meets is done.
func _goal_met(kind: String, what: Dictionary) -> void:
	for id in _started.duplicate():
		var data := mission(id)
		var step := current_step(data)
		if step.is_empty():
			continue
		var goal: Dictionary = step.get("doel", {})
		if str(goal.get("soort", "")) == kind and _meets(goal, what):
			_complete(data, step)


func _meets(goal: Dictionary, what: Dictionary) -> bool:
	match str(goal.get("soort", "")):
		"geld_verdiend":
			return float(_player.money_earned) >= float(goal.get("bedrag", 0.0))
		"kopen":
			return str(what.get("item", "")) == str(goal.get("item", ""))
		"praten_met":
			var who := str(goal.get("persoon", "iemand"))
			return who == "iemand" or who == str(what.get("persoon", ""))
		"naar_plek":
			var place := _place(str(goal.get("plek", "")))
			var feet: Vector3 = _player.global_position
			return place != Vector2.INF and Vector2(feet.x, feet.z).distance_to(place) <= float(goal.get("straal", 10.0))
	return false


## Marks a step done in the step of a test or a tool (as if its goal was met).
func complete_step(id: String, step_id: String) -> void:
	var data := mission(id)
	for step: Dictionary in data.get("stappen", []):
		if str(step.id) == step_id and not step_done(id, step_id):
			_complete(data, step)


func _complete(data: Dictionary, step: Dictionary) -> void:
	var id := str(data.id)
	_done[id + "/" + str(step.id)] = true
	_targets.erase(id + "/" + str(step.id))
	_aim(data)
	_update_tracker()
	var pages := _pages(step.get("klaar_paginas", []), _banner(data), data)
	var whole_mission := current_step(data).is_empty() and not _finished.has(id)
	if _hud.has_method("play_task_done"):
		_hud.play_task_done(whole_mission)   # a triumph tune, a longer one for the whole mission
	if whole_mission:
		_finished[id] = true
		pages.append_array(_pages(data.get("einde_paginas", []), _banner(data), data))
		_start_missions_later.call_deferred("na:" + id)
	if not pages.is_empty():
		_hud.show_story(pages)


func _start_missions_later(trigger: String) -> void:
	_start_missions(trigger)


func _on_money_changed() -> void:
	_goal_met("geld_verdiend", {})
	_update_tracker()   # the progress in the text


# ------------------------------------------------------------------ where to go

## The places the step under way of a mission points to, worked out once as it starts.
func _aim(data: Dictionary) -> void:
	var step := current_step(data)
	if step.is_empty():
		return
	var key := str(data.id) + "/" + str(step.id)
	if _targets.has(key):
		return
	var where: Dictionary = step.get("plekken", {})
	var spots: Array = []
	match str(where.get("soort", "")):
		"snackbars":
			var feet: Vector3 = _player.global_position
			spots = snack_bars(Vector2(feet.x, feet.z), int(where.get("aantal", 3)))
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
	if spots.is_empty() and str(goal.get("soort", "")) == "naar_plek":
		var place := _place(str(goal.get("plek", "")))
		if place != Vector2.INF:
			spots = [place]
	_targets[key] = spots


## A named place of the map (the "places" metadata of the city), INF when there is none.
func _place(place_key: String) -> Vector2:
	var root: Node = owner if owner else get_parent()
	var places: Dictionary = root.get_meta("places", {}) if root else {}
	return places.get(place_key, Vector2.INF)


## The snack bars nearest to `near` (world x, z), `count` of them: the cells of the Gebouwen
## map with a snack bar's shop front (fronts within 8 m of each other are one bar).
func snack_bars(near: Vector2, count := 3) -> Array:
	var buildings := get_node_or_null(buildings_path) as GridMap
	if buildings == null or buildings.mesh_library == null:
		return []
	var spots: Array = []
	for item in buildings.mesh_library.get_item_list():
		if not buildings.mesh_library.get_item_name(item).contains(SNACK_BAR_FRONT):
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


## The mission as the tracker and the quest log have it (GameHud.set_quests).
func _quest(data: Dictionary) -> Dictionary:
	var id := str(data.id)
	var steps: Array = []
	var current := current_step(data)
	var reached_current := false
	for step: Dictionary in data.get("stappen", []):
		var done := step_done(id, str(step.id))
		var is_current := not current.is_empty() and str(step.id) == str(current.id)
		steps.append({"text": _fill(str(step.get("tekst", "")), data, step), "done": done,
			"locked": not done and reached_current, "xp": int(step.get("xp", 0)),
			"targets": _targets.get(id + "/" + str(step.id), []) if is_current else []})
		if is_current:
			reached_current = true
	var rewards: Array = data.get("beloningen", []).duplicate()
	if int(data.get("xp", 0)) > 0:
		rewards.append("+%d XP" % int(data.xp))
	return {"id": id, "kind": "zij" if str(data.get("soort", "verhaal")) == "zij" else "verhaal",
		"xp": int(data.get("xp", 0)), "label": str(data.get("label", "")), "title": str(data.get("titel", "")),
		"distance": "", "giver": str(data.get("gever", "")), "description": str(data.get("beschrijving", "")),
		"rewards": rewards, "steps": steps}


## Gives the XP of every step done and every quest done (all its steps) that has not had it.
func _award_xp(quests: Array) -> void:
	if _player == null or not _player.has_method("add_xp"):
		return
	for quest: Dictionary in quests:
		var id := str(quest.get("id", quest.get("title", "")))
		var steps: Array = quest.get("steps", [])
		var all_done := not steps.is_empty()
		for step_index in steps.size():
			var step: Dictionary = steps[step_index]
			if not step.get("done", false):
				all_done = false
				continue
			var key := "%s/%d" % [id, step_index]
			if not _xp_given.has(key):
				_xp_given[key] = true
				_player.add_xp(float(step.get("xp", 0)))
		if all_done and not _xp_given.has(id):
			_xp_given[id] = true
			_player.add_xp(float(quest.get("xp", 0)))


# ------------------------------------------------------------------ pages and texts

func _banner(data: Dictionary) -> Dictionary:
	return {"banner_kind": str(data.get("label", "")), "banner": str(data.get("titel", ""))}


## Pages of the data ({"soort", "tekst", "spreker"}) as the story box has them.
func _pages(entries: Array, banner: Dictionary, data: Dictionary) -> Array:
	var pages: Array = []
	for entry: Dictionary in entries:
		var page := {"kind": str(entry.get("soort", "verhaal")), "text": _fill(str(entry.get("tekst", "")), data, {})}
		if entry.has("spreker"):
			page["speaker"] = str(entry.spreker)
		page.merge(banner)
		pages.append(page)
	return pages


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
		if str(goal.get("soort", "")) == "geld_verdiend" and _player:
			progress = _euros(minf(float(_player.money_earned), float(goal.get("bedrag", 0.0))))
		text = text.replace("{voortgang}", progress)
	return text


static func _euros(amount: float) -> String:
	return "€ " + ("%.2f" % amount).replace(".", ",")
