extends RefCounted
## The sizes of the QUESTS tab of the game menu (layout; docs/CODE_LAGEN.md): the list on
## the left and its rows, the panel of the chosen quest on the right. Built with these by
## quest_tab_view.gd; quest_tab.gd is the behaviour, quest_tab_rules.gd the logic.
##   const QuestTabLayout = preload("res://scripts/ui/game_menu/quest_tab_layout.gd")

## The width of the list of quests.
const LIST_WIDTH := 400.0
## The buttons VERHAAL and ZIJMISSIES over the list.
const KIND_BUTTON_HEIGHT := 40.0
## A row of the list: its height, the coloured strip on its left and the room after it.
const ROW_HEIGHT := 56.0
const ROW_STRIP := 6.0
const ROW_MARGIN_X := 14
const ROW_MARGIN_Y := 10
## The hard shadow of the chosen row and of the panel of the chosen quest.
const CHOSEN_ROW_SHADOW := 4.0
const DETAIL_SHADOW := 6.0
## The box of a step, the square of a reward.
const STEP_BOX := 12.0
const REWARD_SQUARE := 8.0


## The smallest size of a row of the list.
static func row_size() -> Vector2:
	return Vector2(0.0, ROW_HEIGHT)


## The room left of the texts of a row: the strip and the margin after it.
static func row_margin_left() -> float:
	return ROW_STRIP + ROW_MARGIN_X
