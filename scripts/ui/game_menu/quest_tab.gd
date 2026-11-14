extends Control
## The QUESTS tab of the game menu, the quest log (the node "Quests"; behaviour,
## docs/CODE_LAGEN.md): it keeps which list is shown (VERHAAL or ZIJMISSIES) and which
## quest of it is chosen, takes the keys of the tab (up / down choose, left / right the
## list, Enter follows) and the clicks of its picture, asks quest_tab_rules.gd what to show
## of the quests of the HUD (hud.quests(), hud.tracked_quest_id()) and hands that to
## quest_tab_view.gd. Following a quest goes through the HUD (hud.track_quest).
## Made by scripts/ui/game_menu.gd, which refreshes it and passes the keys on.
##   const QuestTab = preload("res://scripts/ui/game_menu/quest_tab.gd")

const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const QuestRules = preload("res://scripts/ui/hud/quest_rules.gd")
const MenuRules = preload("res://scripts/ui/game_menu/menu_rules.gd")
const QuestTabRules = preload("res://scripts/ui/game_menu/quest_tab_rules.gd")
const QuestTabView = preload("res://scripts/ui/game_menu/quest_tab_view.gd")

## Its picture.
var view: QuestTabView
## The HUD whose quests these are (the menu sets it); without one there are no quests.
var hud: Node

var _kind: String = QuestTabRules.MAIN_KIND
var _selected := 0


func _init() -> void:
	name = "Quests"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	view = QuestTabView.new()
	add_child(view)
	for kind_entry: Array in QuestTabRules.KINDS:
		view.add_kind(kind_entry[0], kind_entry[1], QuestTabRules.is_main_kind(kind_entry[0]))
	view.kind_pressed.connect(choose_kind)
	view.row_pressed.connect(_on_row_pressed)
	view.follow_pressed.connect(track_selected)


## Shows the list that is chosen and the chosen quest as they are now.
func refresh() -> void:
	if quests().is_empty():
		view.show_no_quests()
		return
	var shown := QuestTabRules.quests_of_kind(quests(), _kind)
	_selected = QuestTabRules.clamped_selection(_selected, shown.size())
	view.show_list(_kind, QuestTabRules.rows(shown, tracked_id()), _selected, QuestTabRules.nothing_text(_kind))
	if shown.is_empty():
		view.show_no_quest()
	else:
		view.show_quest(QuestTabRules.detail(shown[_selected], tracked_id()))


## The line of the tab bar while this tab is open.
func header_text() -> String:
	return QuestTabRules.header_text(quests())


## A key while this tab is open: left / right the list, up / down the quest, Enter follows.
func handle_key(key: Key) -> void:
	var direction := MenuRules.direction(key)
	if direction.x != 0:
		choose_kind(QuestTabRules.kind_after(_kind, direction.x))
	elif direction.y != 0:
		choose_quest(QuestTabRules.moved_selection(_selected, direction.y, QuestTabRules.quests_of_kind(quests(), _kind).size()))
	elif MenuRules.is_accept(key):
		track_selected()


## Shows the list of this kind ("verhaal" or "zij"), its first quest chosen.
func choose_kind(kind: String) -> void:
	if kind == _kind:
		return
	UiSounds.play(self, "kies")
	_kind = kind
	_selected = 0
	refresh()


## Chooses the quest at `index` of the list shown.
func choose_quest(index: int) -> void:
	if index == _selected:
		return
	UiSounds.play(self, "kies")
	_selected = index
	refresh()


## Follows the chosen quest (GameHud.track_quest); a quest that is done cannot be followed.
func track_selected() -> void:
	var shown := QuestTabRules.quests_of_kind(quests(), _kind)
	if shown.is_empty() or hud == null or not hud.has_method("track_quest"):
		return
	var quest: Dictionary = shown[_selected]
	if QuestRules.quest_id(quest) == tracked_id():
		return
	if not QuestTabRules.can_follow(quest, tracked_id()):
		UiSounds.play(self, "terug")   # done: nothing left to follow
		return
	UiSounds.play(self, "doe")
	hud.track_quest(QuestRules.quest_id(quest))
	refresh()


## The quests of the HUD ([] without one).
func quests() -> Array:
	if hud and hud.has_method("quests"):
		return hud.quests()
	return []


## The id of the quest the HUD follows ("" none).
func tracked_id() -> String:
	return hud.tracked_quest_id() if hud and hud.has_method("tracked_quest_id") else ""


## The list shown: "verhaal" or "zij".
func kind() -> String:
	return _kind


## The index of the chosen quest in the list shown.
func selected() -> int:
	return _selected


## A click on a row: chosen once the click is over (the rows are made anew).
func _on_row_pressed(index: int) -> void:
	if index == _selected:
		return
	UiSounds.play(self, "kies")
	_selected = index
	refresh.call_deferred()
