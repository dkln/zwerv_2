extends RefCounted
## The logic of the death screen (the rules layer of scripts/ui/screens/death_screen.gd,
## which is the behaviour; death_screen_view.gd builds and shows it): the line that says
## how the player died, and from when the keys work. Plain functions, without nodes or
## the clock (the behaviour hands the times in).
##   const DeathScreenRules = preload("res://scripts/ui/screens/death_screen_rules.gd")

## How it happened: the cause (PlayerController) -> the line, %s the name of who died.
const CAUSES := {
	"honger": "%s is van de honger omgekomen.",
	"aangereden": "%s is aangereden en niet meer opgestaan.",
	"verdronken": "%s is in het water gevallen en verdronken.",
	"eruit_gegooid": "%s is een gebouw uit gesmeten en niet meer opgestaan.",
}
const UNKNOWN_CAUSE := "%s heeft het niet gered."
## Seconds before the keys work (so a key held while dying does not skip it).
const KEYS_AFTER := 1.2


## How `who` died of `cause` (a key of CAUSES; anything else: a general line).
static func reason(cause: String, who: String) -> String:
	return String(CAUSES.get(cause, UNKNOWN_CAUSE)) % who


## Whether the keys work at `now` (seconds) on a screen that opened at `opened_at`:
## KEYS_AFTER s after it opened.
static func keys_work(opened_at: float, now: float) -> bool:
	return now - opened_at >= KEYS_AFTER
