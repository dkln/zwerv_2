extends Control
## The quest tracker of the HUD (the node "Opdrachten", on the right; behaviour,
## docs/CODE_LAGEN.md): it keeps the quests of the game and which one is followed (chosen
## in the game menu, else the first open one), decides with quest_rules.gd what to show of
## it, and hands that to its picture (quest_tracker_view.gd). Hidden while no quest is
## followed; the other quests are in the quest log of the game menu.
##   const QuestTracker = preload("res://scripts/ui/hud/quest_tracker.gd")

const QuestRules = preload("res://scripts/ui/hud/quest_rules.gd")
const QuestTrackerView = preload("res://scripts/ui/hud/quest_tracker_view.gd")

## Its picture.
var view: QuestTrackerView

var _quests: Array = []
var _tracked_id := ""


func _init() -> void:
	name = "Opdrachten"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	view = QuestTrackerView.new()
	add_child(view)


## The quests, top to bottom (a copy is kept; what a quest is: QuestRules). The followed
## one stays followed; when it is done or gone the first open one after it is.
func set_quests(quests: Array) -> void:
	var previous_ids: Array = _quests.map(func(quest: Dictionary) -> String: return QuestRules.quest_id(quest))
	_quests = quests.duplicate(true)
	_tracked_id = QuestRules.tracked_after_change(_quests, _tracked_id, previous_ids)
	_show_tracked()


## The quests as last given to set_quests.
func quests() -> Array:
	return _quests


## The quest named `id`; {} when there is none.
func by_id(id: String) -> Dictionary:
	return QuestRules.by_id(_quests, id)


## Follows the quest `id`: its panel in place of the one before. Nothing when it is not
## there, done, or followed already.
func track(id: String) -> void:
	if not QuestRules.can_track(_quests, id, _tracked_id):
		return
	_tracked_id = id
	_show_tracked()


## The id of the quest that is followed ("" when none).
func tracked_id() -> String:
	return _tracked_id


## The quest that is followed; {} when none.
func tracked() -> Dictionary:
	return by_id(_tracked_id)


## Where the followed quest sends the player now (QuestRules.targets_of), as world x, z.
func targets() -> Array:
	return QuestRules.targets_of(tracked())


## The quest to follow once `after_id` is done or gone (QuestRules.next_open_id).
func next_open_id(after_id: String, previous_ids: Array = []) -> String:
	return QuestRules.next_open_id(_quests, after_id, previous_ids)


## The player stands at `from` (world x, z): how far the nearest place of the followed
## quest is, in its panel.
func show_distance_from(from: Vector2) -> void:
	view.show_distance(QuestRules.distance_text(QuestRules.nearest_distance(targets(), from)))


## The panel of the followed quest (the quests changed, or which one is followed).
func _show_tracked() -> void:
	var followed := tracked()
	visible = not followed.is_empty()
	if followed.is_empty():
		view.show_nothing()
	elif QuestRules.is_main(followed):
		var steps: Array = QuestRules.tracker_steps(followed).map(func(step: Dictionary) -> Dictionary:
			return {"text": QuestRules.step_text(step), "done": bool(step.get("done", false)),
				"locked": QuestRules.is_locked(step), "xp": QuestRules.step_xp_text(step)})
		view.show_main_quest(str(followed.get("label", "VERHAAL")), str(followed.get("title", "")), str(followed.get("distance", "")), steps)
	else:
		view.show_side_quest(str(followed.get("label", "ZIJMISSIE")), str(followed.get("title", "")))
