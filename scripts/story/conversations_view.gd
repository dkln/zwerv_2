extends RefCounted
## What you see and hear of a conversation in the world (graphics; docs/CODE_LAGEN.md): the
## body of who you talk to moving with the mood of a line (Emote), the look and the figure
## for the portrait, what rises over them (money given, a skill check passed or failed), the
## chime of a coin, and how someone on duty is shown in the story box (official_style: the
## colours of their name plate). conversations.gd says what to show; this decides nothing.
##   const ConversationsView = preload("res://scripts/story/conversations_view.gd")

const Emote = preload("res://scripts/world/people/emote.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const MONEY_COLOUR := Color("#E8B83A")
const CHECK_PASSED_COLOUR := Color("#8BE36B")
const CHECK_FAILED_COLOUR := Color("#FF4D5E")
## How high over their feet the money and the result of a check rise (metres).
const MONEY_HEIGHT := 2.0
const CHECK_HEIGHT := 2.3
## The colours of someone on duty whose data names none.
const OFFICIAL_COLOUR := "#FFB547"
const OFFICIAL_TEXT_COLOUR := "#0B0D1A"

## Who is talked to, and the HUD (its floating numbers).
var person: Node3D
var hud: Node


func _init(talking_to: Node3D, the_hud: Node) -> void:
	person = talking_to
	hud = the_hud


## The figure of who is talked to (for the close-up of the portrait); null when unknown.
func figure() -> Node3D:
	return person.get("figure") as Node3D if person else null


## The look of who is talked to (a TownsfolkFigure look), empty when unknown.
func look() -> Dictionary:
	var its_figure := figure()
	var figure_look: Variant = its_figure.get("look") if its_figure else null
	return figure_look if figure_look is Dictionary else {}


## Their voice (Person.voice), "man" when they have none.
func voice() -> String:
	return str(person.call("voice")) if person and person.has_method("voice") else "man"


## Their body moves with the mood of a line (Emote).
func show_mood(mood: String) -> void:
	if person:
		Emote.start(person, figure(), mood)


## The conversation is over: the body as it was.
func stop_mood() -> void:
	Emote.stop(person)


## Money given rises over them (as a coin picked up), over the open box.
func show_money(text: String) -> void:
	_show_number(MONEY_HEIGHT, text, MONEY_COLOUR, 18)


## The result of a skill check rises over them, green when passed and red when failed.
func show_check(text: String, passed: bool) -> void:
	_show_number(CHECK_HEIGHT, text, CHECK_PASSED_COLOUR if passed else CHECK_FAILED_COLOUR, 14)


## The chime of a coin, at them.
func play_coin() -> void:
	UiSounds.play(person, "munt", -2.0)


func _show_number(height: float, text: String, colour: Color, font_size: int) -> void:
	if hud and hud.has_method("show_floating_number") and person:
		hud.show_floating_number(person.global_position + Vector3.UP * height, text, colour, font_size, true)


## How the story box shows someone on duty with `data` (personeel.json): "emblem" on the
## portrait, "colour" of the frame and cursor, the name plate's "plate" and "plate_text"
## colours, the babble's "pitch". Empty for no data.
static func official_style(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	var colour := Color(str(data.get("kleur", OFFICIAL_COLOUR)))
	return {"emblem": str(data.get("embleem", "")), "colour": colour,
		"plate": Color(str(data.get("naamkaartje", data.get("kleur", OFFICIAL_COLOUR)))),
		"plate_text": Color(str(data.get("tekstkleur", OFFICIAL_TEXT_COLOUR))),
		"pitch": float(data.get("stemhoogte", 1.0))}
