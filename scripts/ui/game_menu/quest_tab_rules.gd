extends RefCounted
## The rules of the QUESTS tab of the game menu, the quest log (logic;
## docs/CODE_LAGEN.md): the two lists (VERHAAL and ZIJMISSIES), what a row and the panel
## of the chosen quest say, how the arrows move through them and whether a quest can be
## followed. What a quest is: scripts/ui/hud/quest_rules.gd. The behaviour is quest_tab.gd,
## the picture quest_tab_view.gd.
##   const QuestTabRules = preload("res://scripts/ui/game_menu/quest_tab_rules.gd")

const QuestRules = preload("res://scripts/ui/hud/quest_rules.gd")

## The quest lists: kind (as in set_quests) and the label of its button.
const KINDS := [["verhaal", "VERHAAL"], ["zij", "ZIJMISSIES"]]
const MAIN_KIND := "verhaal"
const SIDE_KIND := "zij"


## The quests of `quests` of this kind, in their order.
static func quests_of_kind(quests: Array, kind: String) -> Array:
	var found := []
	for quest: Dictionary in quests:
		if str(quest.get("kind", MAIN_KIND)) == kind:
			found.append(quest)
	return found


## Whether a kind is that of the story (the others are side quests).
static func is_main_kind(kind: String) -> bool:
	return kind == MAIN_KIND


## The index of a kind in KINDS (0 when it is none).
static func kind_index(kind: String) -> int:
	for index in KINDS.size():
		if KINDS[index][0] == kind:
			return index
	return 0


## The kind `step` lists on from `kind` (left: -1, right: +1), round the ends.
static func kind_after(kind: String, step: int) -> String:
	return KINDS[posmod(kind_index(kind) + step, KINDS.size())][0]


## The quest chosen after `step` rows down from `selected` among `count`: it stops at the
## ends; `selected` itself without quests.
static func moved_selection(selected: int, step: int, count: int) -> int:
	return clampi(selected + step, 0, count - 1) if count > 0 else selected


## `selected` within the `count` quests there are (0 without any).
static func clamped_selection(selected: int, count: int) -> int:
	return clampi(selected, 0, maxi(count - 1, 0))


## The line in the tab bar: "1 VERHAAL · 2 ZIJMISSIES".
static func header_text(quests: Array) -> String:
	return "%d VERHAAL · %d ZIJMISSIES" % [quests_of_kind(quests, MAIN_KIND).size(), quests_of_kind(quests, SIDE_KIND).size()]


## Over a quest's title: "◆ VERHAAL" or "! ZIJMISSIE" (its own label when it has one).
static func tag(quest: Dictionary) -> String:
	var main := str(quest.get("kind", MAIN_KIND)) == MAIN_KIND
	return ("◆ " if main else "! ") + str(quest.get("label", "VERHAAL" if main else "ZIJMISSIE"))


## How many of `steps` are done.
static func steps_done(steps: Array) -> int:
	var done := 0
	for step: Dictionary in steps:
		if step.get("done", false):
			done += 1
	return done


## Whether a quest has steps and all of them are done.
static func all_steps_done(quest: Dictionary) -> bool:
	var steps: Array = quest.get("steps", [])
	return not steps.is_empty() and steps_done(steps) == steps.size()


## Right on a quest's row: the steps done ("2/3", "KLAAR"), else its distance.
static func status(quest: Dictionary) -> String:
	var steps: Array = quest.get("steps", [])
	if not steps.is_empty():
		var done := steps_done(steps)
		return "KLAAR" if done == steps.size() else "%d/%d" % [done, steps.size()]
	return str(quest.get("distance", ""))


## A row of the list: {"tag", "title", "done": all its steps are, "status": what stands on
## its right, "followed": it is the quest `tracked_id`}.
static func row(quest: Dictionary, tracked_id: String) -> Dictionary:
	var followed := QuestRules.quest_id(quest) == tracked_id
	return {"tag": tag(quest), "title": str(quest.get("title", "")), "done": all_steps_done(quest),
		"status": ("◆ VOLGT  " if followed else "") + status(quest), "followed": followed}


## The rows of `quests`, each as `row`.
static func rows(quests: Array, tracked_id: String) -> Array:
	return quests.map(func(quest: Dictionary) -> Dictionary: return row(quest, tracked_id))


## A step in the panel of the chosen quest: {"text" (with what it waits for when it cannot
## be done yet), "done", "locked", "has_progress", "progress" ("2/5"), "xp" ("+25 XP", "" none)}.
static func step_row(step: Dictionary) -> Dictionary:
	var locked := QuestRules.is_locked(step)
	return {"text": str(step.get("text", "")) + ("  (eerst de stap hiervoor)" if locked else ""),
		"done": step.get("done", false), "locked": locked,
		"has_progress": step.has("progress"), "progress": str(step.get("progress", "")), "xp": QuestRules.step_xp_text(step)}


## Whether `quest` can be followed now: it is not the one followed and not done.
static func can_follow(quest: Dictionary, tracked_id: String) -> bool:
	return not quest.is_empty() and QuestRules.quest_id(quest) != tracked_id and not QuestRules.is_done(quest)


## What the follow button under the steps says.
static func follow_text(followed: bool, finished: bool) -> String:
	return "◆ JE VOLGT DEZE OPDRACHT" if followed else ("AFGEROND" if finished else "[ENTER] VOLGEN")


## The panel of the chosen quest: {"tag", "title", "giver" ("Van Willem", "" none),
## "distance", "description", "steps" (step_row each), "followed", "finished",
## "follow_text", "rewards": their texts in capitals}.
static func detail(quest: Dictionary, tracked_id: String) -> Dictionary:
	var followed := QuestRules.quest_id(quest) == tracked_id
	var finished := QuestRules.is_done(quest)
	var giver := str(quest.get("giver", ""))
	return {
		"tag": tag(quest),
		"title": str(quest.get("title", "")),
		"giver": "Van %s" % giver if giver != "" else "",
		"distance": str(quest.get("distance", "")),
		"description": str(quest.get("description", "")),
		"steps": (quest.get("steps", []) as Array).map(step_row),
		"followed": followed,
		"finished": finished,
		"follow_text": follow_text(followed, finished),
		"rewards": (quest.get("rewards", []) as Array).map(func(reward: Variant) -> String: return str(reward).to_upper()),
	}


## What the list says when it has no quest of this kind.
static func nothing_text(kind: String) -> String:
	return "Geen zijmissies op dit moment." if kind == SIDE_KIND else "Geen verhaalopdracht op dit moment."
