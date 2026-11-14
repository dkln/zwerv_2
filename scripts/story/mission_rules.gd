extends RefCounted
## The rules of the missions (logic; docs/CODE_LAGEN.md): pure functions over the data of
## data/missies/*.json (see story.gd for what a mission holds) and what the story keeps of
## them (`done`: "mission id/step id" -> true; `flags`: what was unlocked, passed or shown).
## Which step is under way, which can be done now, what starts when, what a step opens and
## the pages it shows on the way. When a goal is met is goal_rules.gd; texts and pages are
## story_text_rules.gd; the tracker's quest and the rewards mission_tracker_rules.gd.
##   const MissionRules = preload("res://scripts/story/mission_rules.gd")

const MISSIONS_FOLDER := "res://data/missies/"
## The kinds of goal a step can have (see story.gd; tests/unit/story/test_mission_rules.gd
## checks the data).
const GOAL_KINDS := ["geld_verdiend", "geld_op_zak", "kopen", "gebruiken", "verzamelen", "statiegeld", "praten_met", "naar_plek",
	"naar_persoon", "lopen", "stat_onder", "menu_open", "check", "begeleiden", "werver"]
## Locked at the start until a mission unlocks it ("ontgrendelt"): "menu" (the game menu) and
## "bedelen" (asking people for change, Conversations: mission 1 after the deposit), "handelaars"
## (talking to sellers) and "springen" (Space, PlayerController.jumping_open: mission 1, on
## coming into the station for the last cans, "bij_binnenkomst"), "kleingeld" and "pinpassen"
## (coins and bank cards lying on the streets, LooseChange, LostBankCards: no mission yet) and
## "snackkaart" (the whole menu of a snack bar, Conversations.shop_goods "slot": after mission 1).
const UNLOCKABLE := ["menu", "bedelen", "handelaars", "springen", "kleingeld", "pinpassen", "snackkaart"]
## What starts a mission ("start"): after the prologue, after another mission ("na:<id>").
const AFTER_PROLOGUE := "na_proloog"
const AFTER_MISSION := "na:"
## Seconds before a mission "herhaalbaar" starts again when it names none ("herhaal_na").
const REPEAT_AFTER := 120.0


# ------------------------------------------------------------------ the data

## Every mission of `folder` (in the order of the file names).
static func load_missions(folder := MISSIONS_FOLDER) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var files := Array(DirAccess.get_files_at(folder))
	files.sort()
	for file_name: String in files:
		if not file_name.ends_with(".json"):
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder + file_name))
		if data is Dictionary and (data as Dictionary).has("id"):
			found.append(data)
		else:
			push_error("story: %s%s is no mission (no valid JSON, or no \"id\")" % [folder, file_name])
	return found


## The mission `id` of `missions`; {} when there is none.
static func by_id(missions: Array, id: String) -> Dictionary:
	for data: Dictionary in missions:
		if str(data.id) == id:
			return data
	return {}


## The missions that start on `trigger` ("na_proloog", "na:<mission id>") and have not started.
static func starting_on(missions: Array, trigger: String, started: Array) -> Array:
	return missions.filter(func(data: Dictionary) -> bool:
		return str(data.get("start", "")) == trigger and not started.has(str(data.id)))


## What starts the missions that follow on mission `id`.
static func trigger_after(id: String) -> String:
	return AFTER_MISSION + id


## Whether a trigger is the end of another mission (the one that starts on it is followed).
static func follows_a_mission(trigger: String) -> bool:
	return trigger.begins_with(AFTER_MISSION)


## How long (seconds) after a mission "herhaalbaar" is done it starts again.
static func repeat_after(data: Dictionary) -> float:
	return float(data.get("herhaal_na", REPEAT_AFTER))


# ------------------------------------------------------------------ steps

## What a step is called in what the story keeps: "mission id/step id".
static func step_key(data: Dictionary, step: Dictionary) -> String:
	return str(data.id) + "/" + str(step.id)


## What the XP of step number `index` of mission `id` is kept under (given once).
static func xp_key(id: String, index: int) -> String:
	return "%s/%d" % [id, index]


## The step `step_id` of a mission; {} when it has none.
static func step_by_id(data: Dictionary, step_id: String) -> Dictionary:
	for step: Dictionary in data.get("stappen", []):
		if str(step.id) == step_id:
			return step
	return {}


## Whether the step `step_id` of mission `id` is done.
static func is_step_done(done: Dictionary, id: String, step_id: String) -> bool:
	return done.has(id + "/" + step_id)


## The step under way of a mission (the first not done that is not optional), or {} when
## all are.
static func current_step(data: Dictionary, done: Dictionary) -> Dictionary:
	for step: Dictionary in data.get("stappen", []):
		if not step.get("optioneel", false) and not is_step_done(done, str(data.id), str(step.id)):
			return step
	return {}


## The steps that can be done now: the one under way and the optional ones it has reached
## (none once the mission is `finished`).
static func open_steps(data: Dictionary, done: Dictionary, finished: bool) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if finished:
		return found
	for step: Dictionary in data.get("stappen", []):
		if is_step_done(done, str(data.id), str(step.id)):
			continue
		found.append(step)
		if not step.get("optioneel", false):
			break
	return found


## The steps of a mission still to do when it is finished at once (not the optional ones).
static func steps_to_finish(data: Dictionary, done: Dictionary) -> Array:
	return (data.get("stappen", []) as Array).filter(func(step: Dictionary) -> bool:
		return not step.get("optioneel", false) and not is_step_done(done, str(data.id), str(step.id)))


## The numbers of the steps that do not apply to a character that starts with `start_money`
## ("overslaan_als": {"startgeld_minstens": 2.0}): done at once, without XP or pages.
static func skipped_steps(data: Dictionary, start_money: float) -> Array[int]:
	var skipped: Array[int] = []
	var steps: Array = data.get("stappen", [])
	for index in steps.size():
		var skip_when: Dictionary = (steps[index] as Dictionary).get("overslaan_als", {})
		if skip_when.has("startgeld_minstens") and start_money >= float(skip_when.startgeld_minstens):
			skipped.append(index)
	return skipped


## The goal of a step ("doel").
static func goal_of(step: Dictionary) -> Dictionary:
	return step.get("doel", {})


## Whether a step sends you to the bins with a can ("plekken" "soort" "blikjes").
static func points_to_bins(step: Dictionary) -> bool:
	return str(step.get("plekken", {}).get("soort", "")) == "blikjes"


## How many cans a step with "blikjes_station" still wants in the station when `count` of
## its goal's item are in the pockets: what it lacks, at most its "blikjes_station"; 0 for a
## step without.
static func station_cans_wanted(step: Dictionary, count: int) -> int:
	var in_station := int(step.get("blikjes_station", 0))
	if in_station <= 0:
		return 0
	return clampi(int(goal_of(step).get("aantal", 1)) - count, 0, in_station)


## Whether the cans of a step that lie outside are found (`count` in the pockets): the ones
## left are in the station.
static func cans_left_in_station(step: Dictionary, count: int) -> bool:
	return int(step.get("blikjes_station", 0)) > 0 and count >= int(step.get("blikjes_buiten", 0))


# ------------------------------------------------------------------ unlocking and flags

## Whether `what` ("menu", "bedelen") is unlocked: in `flags`, or never locked at all.
static func is_unlocked(flags: Dictionary, what: String) -> bool:
	return flags.has(what) or not UNLOCKABLE.has(what)


## The flag of a skill check passed.
static func check_flag(check_id: String) -> String:
	return "check:" + check_id


## The flag of someone who came into town to wander there, and who that is for such a flag
## ("" for any other flag).
static func appeared_flag(who: String) -> String:
	return "verschenen:" + who


static func who_appeared(flag: String) -> String:
	return flag.trim_prefix("verschenen:") if flag.begins_with("verschenen:") else ""


## The flag of the reward screen of the first of a step's items picked up ("eerste_scherm").
static func first_item_flag(key: String) -> String:
	return "eerste:%s" % key


## The flag of the pages of coming into a building of the step `key` ("bij_binnenkomst").
static func coming_in_flag(key: String) -> String:
	return "binnenkomst:%s" % key


## Everything a step opens while it is played: {"unlocks" (what it unlocks as it begins and on
## coming into a building), "areas" ("opent"), "grow_to" (what its area grows to all the way:
## "groeit" "tot", else "opent_tot"; "" none), "coming_in" (whether it has pages of coming in)}.
static func what_it_opens(step: Dictionary) -> Dictionary:
	var coming_in: Dictionary = step.get("bij_binnenkomst", {})
	var grow: Dictionary = step.get("groeit", {})
	return {"unlocks": Array(step.get("ontgrendelt", [])) + Array(coming_in.get("ontgrendelt", [])),
		"areas": step.get("opent", []), "grow_to": str(grow.get("tot", step.get("opent_tot", ""))),
		"coming_in": not coming_in.is_empty()}


# ------------------------------------------------------------------ pages on the way

## The pages a step shows now as its items come in ("tussen_paginas": [{"bij": 3, "paginas":
## [...]}]: at the third), each once: [{"flag", "paginas"}] for those due with `count` of its
## goal's item in the pockets and not shown yet (`flags`).
static func between_pages_due(step: Dictionary, key: String, count: int, flags: Dictionary) -> Array:
	var due: Array = []
	for between: Dictionary in step.get("tussen_paginas", []):
		var flag := "tussen:%s/%d" % [key, int(between.get("bij", 0))]
		if not flags.has(flag) and count >= int(between.get("bij", 0)):
			due.append({"flag": flag, "paginas": between.get("paginas", [])})
	return due


## Whether the pages of coming into a building of a step ("bij_binnenkomst": {"binnen": a kind
## of Interiors, "vanaf": at least that many of the goal's item, ...}) are due: the player is
## in a building of `kind` with `count` of the item, and they were not shown yet.
static func coming_in_due(step: Dictionary, key: String, kind: String, count: int, flags: Dictionary) -> bool:
	var coming_in: Dictionary = step.get("bij_binnenkomst", {})
	if coming_in.is_empty() or str(coming_in.get("binnen", "")) != kind:
		return false
	return not flags.has(coming_in_flag(key)) and count >= int(coming_in.get("vanaf", 0))


## The item of a step's goal ("" none; `fallback` for a goal that names none).
static func goal_item(step: Dictionary, fallback := "") -> String:
	return str(goal_of(step).get("item", fallback))
