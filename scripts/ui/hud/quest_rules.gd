extends RefCounted
## The rules of the quests (logic; docs/CODE_LAGEN.md): what names a quest, when it is
## done, which one is followed next, which steps the tracker shows and where a quest sends
## the player. Used by the quest tracker of the HUD (quest_tracker.gd) and the quest log of
## the game menu.
## A quest is a Dictionary: "kind": "verhaal" (a main quest: "label", "title", "distance",
## "steps" = [{"text", "done"}]) or "zij" (a side quest: "label" and "title" on one line);
## "id" names it (else its title). A step may have "targets" (Array of world x, z: where to
## go for it, shown on the minimap and the map while it is the step under way of the
## followed quest), "locked" (it can only be done after the steps before it: no targets
## yet), "optional" (it never holds up the step under way) and "xp".
## "done": the whole quest is finished; it can no longer be followed.
##   const QuestRules = preload("res://scripts/ui/hud/quest_rules.gd")


## What names a quest: its "id", else its title.
static func quest_id(quest: Dictionary) -> String:
	return str(quest.get("id", quest.get("title", "")))


static func is_done(quest: Dictionary) -> bool:
	return quest.get("done", false)


## Whether a quest is a main quest of the story ("verhaal", also when it does not say) or
## a side quest ("zij").
static func is_main(quest: Dictionary) -> bool:
	return quest.get("kind", "verhaal") == "verhaal"


## The quest named `id` among `quests`; {} when there is none.
static func by_id(quests: Array, id: String) -> Dictionary:
	for quest: Dictionary in quests:
		if quest_id(quest) == id:
			return quest
	return {}


## Whether the quest `id` can be followed instead of `tracked_id`: it is there, not done,
## and not the one followed already.
static func can_track(quests: Array, id: String, tracked_id: String) -> bool:
	var quest := by_id(quests, id)
	return not quest.is_empty() and not is_done(quest) and id != tracked_id


## The quest to keep following when the quests become `quests`: `tracked_id` while it is
## there and open, else the next open one (next_open_id; `previous_ids`: the order before).
static func tracked_after_change(quests: Array, tracked_id: String, previous_ids: Array) -> String:
	var followed := by_id(quests, tracked_id)
	if followed.is_empty() or is_done(followed):
		return next_open_id(quests, tracked_id, previous_ids)
	return tracked_id


## The quest to follow once `after_id` is done (or gone): the first open (not done) one after
## it in `quests` (`previous_ids`: the order before, as a quest that is gone is no longer in
## the list), else the first open one at all; "" when none is open.
static func next_open_id(quests: Array, after_id: String, previous_ids: Array = []) -> String:
	var start := 0
	var at := -1
	for index in quests.size():
		if quest_id(quests[index]) == after_id:
			at = index
	if at == -1 and previous_ids.has(after_id):
		# gone from the list: start where it stood
		for later_id: String in previous_ids.slice(previous_ids.find(after_id) + 1):
			var later := by_id(quests, later_id)
			if not later.is_empty() and not is_done(later):
				return later_id
	if at != -1:
		start = at + 1
	for offset in quests.size():
		var quest: Dictionary = quests[(start + offset) % quests.size()]
		if not is_done(quest):
			return quest_id(quest)
	return ""


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


## Whether a step cannot be done yet (the one before it first).
static func is_locked(step: Dictionary) -> bool:
	return step.get("locked", false) and not step.get("done", false)


## The text of a step as BBCode: its brackets taken literally, struck through when done.
static func step_text(step: Dictionary) -> String:
	var escaped := str(step.get("text", "")).replace("[", "[lb]")
	return "[s]%s[/s]" % escaped if step.get("done", false) else escaped


## The experience a step gives as written beside it: "+25 XP"; "" when it gives none.
static func step_xp_text(step: Dictionary) -> String:
	var points := int(step.get("xp", 0))
	return "+%d XP" % points if points > 0 else ""


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
