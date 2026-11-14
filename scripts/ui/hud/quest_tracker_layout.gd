extends RefCounted
## The sizes of the quest tracker of the HUD (layout; docs/CODE_LAGEN.md): the panel of the
## followed quest, its margins and the space between its rows. Where the tracker stands in
## the HUD: hud_layout.gd. Built by quest_tracker_view.gd.
##   const QuestTrackerLayout = preload("res://scripts/ui/hud/quest_tracker_layout.gd")

const HudLayout = preload("res://scripts/ui/hud/hud_layout.gd")
const WIDTH := HudLayout.TRACKER_WIDTH
## The accent bar on the left of a panel, and the margin inside it left and right.
const ACCENT_WIDTH := 4
const SIDE_MARGIN := 14
## A main quest: the margin above and below, between its header, title and steps, and
## between its steps, and between a step's box, text and experience.
const MAIN_MARGIN := 12
const MAIN_SEPARATION := 8
const STEP_SEPARATION := 6
const STEP_PART_SEPARATION := 8
## A side quest: the margin above and below, and between its label and title.
const SIDE_QUEST_MARGIN := 10
const SIDE_QUEST_SEPARATION := 4
