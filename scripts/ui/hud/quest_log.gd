extends RefCounted
## The quests of the game as the HUD knows them, and which one is followed: the rules of
## it, without anything on the screen (the tracker of the HUD: quest_tracker.gd; the quest
## log of the game menu reads the same).
## A quest is a Dictionary: "kind": "verhaal" (a main quest: "label", "title", "distance",
## "steps" = [{"text", "done"}]) or "zij" (a side quest: "label" and "title" on one line);
## "id" names it (else its title). A step may have "targets" (Array of world x, z: where to
## go for it, shown on the minimap and the map while it is the step under way of the
## followed quest), "locked" (it can only be done after the steps before it: shown muted,
## no targets yet) and "optional" (it never holds up the step under way).
## "done": the whole quest is finished; it can no longer be followed: the log then goes on
## to the first open quest after it (next_open_id).
##   const QuestLog = preload("res://scripts/ui/hud/quest_log.gd")

var _quests: Array = []
var _tracked_id := ""


# ------------------------------------------------------------------ a quest

## What names a quest: its "id", else its title.
static func quest_id(quest: Dictionary) -> String:
	return str(quest.get("id", quest.get("title", "")))


static func is_done(quest: Dictionary) -> bool:
	return quest.get("done", false)


## Whether a quest is a main quest of the story ("verhaal", also when it does not say) or
## a side quest ("zij").
static func is_main(quest: Dictionary) -> bool:
	return quest.get("kind", "verhaal") == "verhaal"


## The steps the tracker shows of `quest`: not all of them (the quest log in the game menu has
## those), only the last one done and the one open now (the first not done and not locked, an
## optional one only when nothing else is open), in their order.
static func tracker_steps(quest: Dictionary) -> Array:
	var all_steps: Array = quest.get("steps", [])
	var last_done := {}
	var open_now := {}
	var optional_open := {}
	for step: Dictionary in all_steps:
		var done: bool = step.get("done", false)
		if done:
			last_done = step
		elif not step.get("locked", false):
			if step.get("optional", false):
				if optional_open.is_empty():
					optional_open = step
			elif open_now.is_empty():
				open_now = step
	if open_now.is_empty():
		open_now = optional_open
	var shown: Array = []
	for step: Dictionary in all_steps:
		if step == last_done or step == open_now:
			shown.append(step)
	return shown


## Where `quest` sends the player now: the targets of its first step not done (none while
## that step is locked; an optional step never holds up the one under way), as world x, z.
static func targets_of(quest: Dictionary) -> Array:
	for step: Dictionary in quest.get("steps", []):
		if step.get("done", false) or step.get("optional", false):
			continue
		if step.get("locked", false):
			return []
		return step.get("targets", [])
	return []


## How far (m) the nearest of `targets` (world x, z) is from `from`; INF without targets.
static func nearest_distance(targets: Array, from: Vector2) -> float:
	var nearest := INF
	for target: Vector2 in targets:
		nearest = minf(nearest, target.distance_to(from))
	return nearest


## The distance as the tracker writes it: "240 M", nothing when there is none (INF).
static func distance_text(metres: float) -> String:
	return "%d M" % roundi(metres) if metres < INF else ""


# ------------------------------------------------------------------ the log

## The quests, top to bottom (a copy is kept). The followed one stays followed; when it is
## done or gone the first open one after it is (next_open_id).
func set_quests(quests: Array) -> void:
	var previous_ids: Array = _quests.map(func(quest: Dictionary) -> String: return quest_id(quest))
	_quests = quests.duplicate(true)
	var followed := tracked()
	if followed.is_empty() or is_done(followed):
		_tracked_id = next_open_id(_tracked_id, previous_ids)


## The quests as last given to set_quests.
func quests() -> Array:
	return _quests


## The quest named `id`; {} when there is none.
func by_id(id: String) -> Dictionary:
	for quest: Dictionary in _quests:
		if quest_id(quest) == id:
			return quest
	return {}


## Follows the quest `id`. False when nothing changes: it is not there, done, or followed already.
func track(id: String) -> bool:
	var quest := by_id(id)
	if quest.is_empty() or is_done(quest) or id == _tracked_id:
		return false
	_tracked_id = id
	return true


## The id of the quest that is followed ("" when none).
func tracked_id() -> String:
	return _tracked_id


## The quest that is followed; {} when none.
func tracked() -> Dictionary:
	return by_id(_tracked_id)


## Where the followed quest sends the player now (targets_of), as world x, z.
func targets() -> Array:
	return targets_of(tracked())


## The quest to follow once `after_id` is done (or gone): the first open (not done) one after
## it in the list (`previous_ids`: the order before, as a quest that is gone is no longer in
## the list), else the first open one at all; "" when none is open.
func next_open_id(after_id: String, previous_ids: Array = []) -> String:
	var start := 0
	var at := -1
	for index in _quests.size():
		if quest_id(_quests[index]) == after_id:
			at = index
	if at == -1 and previous_ids.has(after_id):
		# gone from the list: start where it stood
		for later_id: String in previous_ids.slice(previous_ids.find(after_id) + 1):
			var later := by_id(later_id)
			if not later.is_empty() and not is_done(later):
				return later_id
	if at != -1:
		start = at + 1
	for offset in _quests.size():
		var quest: Dictionary = _quests[(start + offset) % _quests.size()]
		if not is_done(quest):
			return quest_id(quest)
	return ""
