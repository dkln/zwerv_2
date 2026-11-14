extends RefCounted
## The rules of the machines in the streets (logic; docs/CODE_LAGEN.md; street_machines.gd):
## which marker of the city builder is which machine, what "[E]" says at it, and whether
## what an OV post says is a refusal.
##   const StreetMachinesRules = preload("res://scripts/world/things/street_machines_rules.gd")
##   StreetMachinesRules.kind_of("Geldautomaat_3")   # "geldautomaat"

## The kinds of machine, and how the name of their marker begins.
const CASH := "geldautomaat"
const POST := "ov_paal"
const CASH_PREFIX := "Geldautomaat"
const OV_POST_PREFIX := "OVPaal"
## The prop tile of an OV post.
const OV_POST_TILE := "ov/ov_incheckpaal"
## What "[E]" says at a cash machine, and at an OV post while nobody is known to hold a card
## to it.
const CASH_TEXT := "Pinnen"
const POST_TEXT := "Inchecken"


## Which machine the marker `marker_name` is: CASH, POST or "" (none).
static func kind_of(marker_name: String) -> String:
	if marker_name.begins_with(CASH_PREFIX):
		return CASH
	if marker_name.begins_with(OV_POST_PREFIX):
		return POST
	return ""


## Whether what the post says after a tap (OvCard.tap: {ok, charge, ...}) is bad news: it
## said no, or it kept the boarding fare.
static func is_refusal(result: Dictionary) -> bool:
	return not bool(result.get("ok", false)) or float(result.get("charge", 0.0)) > 0.0
