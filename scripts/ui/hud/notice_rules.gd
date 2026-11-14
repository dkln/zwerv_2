extends RefCounted
## The rules of the notices at the top of the HUD (logic; docs/CODE_LAGEN.md): what a
## notice is, the headings of the usual ones, and when a new one is the one that is up
## already. Shown by notice_banner.gd.
##   const NoticeRules = preload("res://scripts/ui/hud/notice_rules.gd")

const AREA_HEADING := "— NIEUW GEBIED ONTDEKT —"
const MISSION_HEADING := "— NIEUWE MISSIE —"
const LEVEL_HEADING := "— LEVEL OMHOOG —"


## A notice: `heading` over `text`, up for `seconds` (between its fades), with a `jingle`
## (a path; "" none).
static func notice(heading: String, text: String, seconds: float, jingle := "") -> Dictionary:
	return {"heading": heading, "name": text, "seconds": seconds, "jingle": jingle}


## The name of a new level as a notice shows it: "Level 4".
static func level_name(level: int) -> String:
	return "Level %d" % level


## Whether `new_notice` is dropped: a notice is up (`showing`) with the same name
## (`shown_name`): the same area twice in a row is one notice.
static func is_repeat(showing: bool, shown_name: String, new_notice: Dictionary) -> bool:
	return showing and shown_name == str(new_notice.get("name", ""))
