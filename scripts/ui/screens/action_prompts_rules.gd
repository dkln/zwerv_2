extends RefCounted
## The logic of the action prompts (the rules layer of scripts/ui/action_prompts.gd, which
## is the behaviour; action_prompts_layout.gd has the sizes, action_prompts_view.gd builds
## the panels): whether a new list of actions changes anything, whether there is anything
## to show, and the actions as texts. Plain functions, without nodes.
##   const ActionPromptsRules = preload("res://scripts/ui/screens/action_prompts_rules.gd")


## Whether `wanted` differs from the actions shown now (the same again changes nothing).
static func changed(shown_now: Array, wanted: Array) -> bool:
	return wanted != shown_now


## Whether there is anything to show: an empty list hides the prompts.
static func shown(actions: Array) -> bool:
	return not actions.is_empty()


## The actions ([key, what it does] each) as texts: [key text, action text] each.
static func texts(actions: Array) -> Array:
	var rows: Array = []
	for action: Array in actions:
		rows.append([str(action[0]), str(action[1])])
	return rows
