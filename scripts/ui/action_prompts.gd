class_name ActionPrompts
extends VBoxContainer
## The actions the player can do now, in the style of the HUD's action prompt: one under
## the other, each on an ink panel of its own with a border, all as wide as the widest,
## each a key cap ("SPATIE") and what it does ("Overslaan"). Context-sensitive:
## set_actions replaces them whenever what can be done changes (an empty list hides it).
## Mouse clicks go through it.
## This is the behaviour layer: which actions are shown now, when they are replaced, and
## which name a key gets (the controller's button while it is used: PadInput.label).
## screens/action_prompts_rules.gd has the logic, screens/action_prompts_layout.gd the
## sizes, screens/action_prompts_view.gd builds the panels and shows what it is handed.
##   var prompts := ActionPrompts.new()
##   prompts.set_actions([["SPATIE", "Overslaan"], ["ENTER", "Sneller"]])

const PadInput = preload("res://scripts/ui/pad_input.gd")
const ActionPromptsRules = preload("res://scripts/ui/screens/action_prompts_rules.gd")
const ActionPromptsLayout = preload("res://scripts/ui/screens/action_prompts_layout.gd")
const ActionPromptsView = preload("res://scripts/ui/screens/action_prompts_view.gd")
## The gaps of the layout, here for whoever has the prompts at hand.
const PANEL_GAP := ActionPromptsLayout.PANEL_GAP
const KEY_GAP := ActionPromptsLayout.KEY_GAP

var _actions: Array = []
var _view: ActionPromptsView


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_view = ActionPromptsView.new()
	add_child(_view)


## The actions shown, top to bottom: [key text, action text] each.
func set_actions(actions: Array) -> void:
	if not ActionPromptsRules.changed(_actions, actions):
		return
	_actions = actions.duplicate(true)
	var rows: Array = []
	for row: Array in ActionPromptsRules.texts(_actions):
		rows.append([PadInput.label(String(row[0])), row[1]])
	_view.show_actions(rows)
	visible = ActionPromptsRules.shown(_actions)
	# shrink back to the panels (fewer or shorter actions than before)
	reset_size()


func actions() -> Array:
	return _actions.duplicate(true)


## The panels with the actions (the view), for whoever looks at what is shown.
func view() -> ActionPromptsView:
	return _view
