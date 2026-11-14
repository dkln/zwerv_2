extends RefCounted
## The rules of the goals of the steps of a mission (logic; docs/CODE_LAGEN.md): when a goal
## ("doel", see story.gd for the kinds) is met, how far it is (the {voortgang} of a text),
## the money that counts, the metres walked and how far an area has grown with the items.
## The story (story.gd) hands in what it knows of the player and the town (`facts`).
##   const GoalRules = preload("res://scripts/story/goal_rules.gd")

## The goals looked at on the clock: about where the player is or how it is.
const CLOCK_KINDS := ["naar_plek", "naar_persoon", "lopen", "stat_onder"]
## The goals that may be met already when a mission starts or a step is done.
const AT_ONCE_KINDS := ["verzamelen", "stat_onder", "geld_verdiend", "geld_op_zak", "naar_plek"]
## A tenth of a cent for the sums of coins (ten coins of € 0,20 add up to 1.9999... in floats).
const MONEY_SLACK := 0.001
## A step longer than this (metres) between two looks is a jump (into a building and out
## again), not walking.
const JUMP_LENGTH := 12.0


static func kind_of(goal: Dictionary) -> String:
	return str(goal.get("soort", ""))


## Whether `goal` is met now that `what` happened (the item bought or used, the person talked
## to, the tab opened, the check passed, the character that arrived). `facts`: what the story
## knows that the goal asks for; a fact that is missing means the goal is not met:
##   "earned" (money that counts for "geld_verdiend"), "money" (in the wallet), "count" (of
##   the goal's item in the pockets), "feet" and "spot" (world x, z of the player and of the
##   place or person to come to; a spot INF: not on the map), "walked" (metres since the
##   step began), "stat" (the value of the goal's stat).
static func is_met(goal: Dictionary, what: Dictionary, facts: Dictionary) -> bool:
	match kind_of(goal):
		"geld_verdiend":
			return facts.has("earned") and float(facts.earned) + MONEY_SLACK >= float(goal.get("bedrag", 0.0))
		"geld_op_zak":
			return facts.has("money") and float(facts.money) + MONEY_SLACK >= float(goal.get("bedrag", 0.0))
		"kopen", "gebruiken":
			return str(what.get("item", "")) == str(goal.get("item", ""))
		"verzamelen":
			return int(facts.get("count", 0)) >= int(goal.get("aantal", 1))
		"statiegeld", "check_geslaagd":
			return true
		"praten_met":
			var who := str(goal.get("persoon", "iemand"))
			return who == "iemand" or who == str(what.get("persoon", ""))
		"naar_plek":
			return _is_within(facts, float(goal.get("straal", 10.0)))
		"naar_persoon":
			return _is_within(facts, float(goal.get("straal", 6.0)))
		"lopen":
			return float(facts.get("walked", 0.0)) >= float(goal.get("meter", 3.0))
		"stat_onder":
			return facts.has("stat") and float(facts.stat) < float(goal.get("waarde", 0.0))
		"menu_open":
			var tab := str(goal.get("tab", ""))
			return tab == "" or tab == str(what.get("tab", ""))
		"check":
			return str(what.get("check", "")) == str(goal.get("check", ""))
		"begeleiden", "werver":
			return str(what.get("persoon", "")) == str(goal.get("persoon", ""))
	return false


## Whether the "feet" of `facts` are within `reach` metres of its "spot".
static func _is_within(facts: Dictionary, reach: float) -> bool:
	var spot: Vector2 = facts.get("spot", Vector2.INF)
	return spot != Vector2.INF and facts.has("feet") and (facts.feet as Vector2).distance_to(spot) <= reach


## The money that counts for a goal "geld_verdiend": what was found or earned since the
## start (`earned`) and is still in the wallet (`money`). Spent money counts off (the mission
## and the wallet in the corner never disagree: found € 1,50, spent € 0,50, then both say
## € 1,00), and the money a character starts with never counts (the found money can be no
## more than what the player has now, and no more than what was found).
static func money_towards_goal(earned: float, money: float) -> float:
	return maxf(minf(earned, money), 0.0)


## How far a goal is, for {voortgang} in a step's text: the money as euros (never more than
## asked: `money_text` writes an amount), the items as "2/4"; "" for any other goal.
## `wallet`: {"earned", "money", "inventory"}, empty without a player.
static func progress(goal: Dictionary, wallet: Dictionary, money_text: Callable) -> String:
	match kind_of(goal):
		"geld_verdiend":
			if not wallet.is_empty():
				return money_text.call(minf(float(wallet.get("earned", 0.0)), float(goal.get("bedrag", 0.0))))
		"geld_op_zak":
			if not wallet.is_empty():
				return money_text.call(minf(float(wallet.get("money", 0.0)), float(goal.get("bedrag", 0.0))))
		"verzamelen":
			var wanted := int(goal.get("aantal", 1))
			var count := int((wallet.get("inventory", {}) as Dictionary).get(str(goal.get("item", "")), 0))
			return "%d/%d" % [mini(count, wanted), wanted]
	return ""


## What is kept of a step that counts the metres walked ("lopen"), as it begins at `from`.
static func walk_track(from: Vector3) -> Dictionary:
	return {"from": from, "walked": 0.0}


## The metres a step has walked once the player stands at `feet`: what it had (`track`) and
## the way from where it stood, unless that was a jump (JUMP_LENGTH).
static func walked_at(track: Dictionary, feet: Vector3) -> float:
	var from: Vector3 = track.from
	var step_length := Vector2(feet.x - from.x, feet.z - from.z).length()
	return float(track.walked) + (step_length if step_length < JUMP_LENGTH else 0.0)


## The share (0..1) of the way an area has grown with `count` of the `wanted` items.
static func grow_share(count: int, wanted: int) -> float:
	return clampf(float(count) / maxi(wanted, 1), 0.0, 1.0)


## The radius of the start area grown `share` of the way from `base` to `target_radius`
## (never smaller than `base`).
static func grown_radius(base: float, target_radius: float, share: float) -> float:
	return lerpf(base, maxf(target_radius, base), share)
