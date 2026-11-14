extends VBoxContainer
## The notice at the top of the HUD (the node "NieuwGebied", top centre), fading in and
## out: a heading over a name. "Nieuw gebied ontdekt" with the name of the area, "nieuwe
## missie" with its title (and a jingle: jingle_wanted, the music is the HUD's), "level
## omhoog", or a notice of its own (the floor the lift has brought you to). One at a time:
## the next waits until the one before has gone; the same name twice in a row is one notice.
##   const NoticeBanner = preload("res://scripts/ui/hud/notice_banner.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const AREA_HEADING := "— NIEUW GEBIED ONTDEKT —"
const MISSION_HEADING := "— NIEUWE MISSIE —"
const LEVEL_HEADING := "— LEVEL OMHOOG —"
## Width of the notice (a mission title is longer than an area name).
const WIDTH := 720.0
const FADE_IN := 0.6
const FADE_OUT := 0.9

## A notice with a jingle comes up: the path of the jingle.
signal jingle_wanted(path: String)

var _heading: Label
var _name: Label
var _fade: Tween
var _waiting: Array[Dictionary] = []   # {"heading", "name", "seconds", "jingle"}


func _init() -> void:
	name = "NieuwGebied"
	add_theme_constant_override("separation", 4)
	size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fonts := UiStyle.fonts()
	_heading = UiStyle.label(AREA_HEADING, UiStyle.spaced(fonts.pixel, 3), 12, UiStyle.ACCENT, 2)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_heading)
	_name = UiStyle.label("", fonts.title, 34, UiStyle.TEXT, 3)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name)
	visible = false


## A notice: `heading` over `text`, up for `seconds` (between its fades), with a `jingle`
## (a path; "" none).
static func notice(heading: String, text: String, seconds: float, jingle := "") -> Dictionary:
	return {"heading": heading, "name": text, "seconds": seconds, "jingle": jingle}


## Shows a notice (NoticeBanner.notice), or lets it wait for the one that is up. False when
## it is dropped: the notice that is up has the same name.
func queue(new_notice: Dictionary) -> bool:
	if visible and _name.text == new_notice["name"]:
		return false
	_waiting.append(new_notice)
	if not visible:
		show_next()
	return true


## True while a notice is up.
func is_showing() -> bool:
	return visible


## How many notices wait for the one that is up.
func waiting() -> int:
	return _waiting.size()


func heading_text() -> String:
	return _heading.text


func name_text() -> String:
	return _name.text


## The notice that is up goes, and the next one waiting comes (none: the banner is gone).
func show_next() -> void:
	if _fade:
		_fade.kill()
		_fade = null
	if _waiting.is_empty():
		visible = false
		return
	var next: Dictionary = _waiting.pop_front()
	_heading.text = next["heading"]
	_name.text = next["name"]
	if next["jingle"] != "":
		jingle_wanted.emit(next["jingle"])
	visible = true
	modulate.a = 0.0
	if not is_inside_tree():
		return
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, FADE_IN)
	_fade.tween_interval(next["seconds"])
	_fade.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_fade.tween_callback(show_next)
