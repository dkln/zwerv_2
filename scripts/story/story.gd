extends Node
## The story of the game (the node "Verhaal" of scenes/stad.tscn): what happens when, shown
## in the story box of the HUD (GameHud.show_story, scripts/ui/story_box.gd) and kept in the
## quest tracker (GameHud.set_quests) and the quest log of the game menu.
## 1. Prologue, as soon as the player has woken up on the square by Centraal Station
##    (PlayerController.woke_up): where you are, your backstory (the archetype's "story"),
##    what you think waking up, and then the first mission.
## 2. Mission 1, "Twee euro voor een kroket": get together EUROS_FOR_KROKET in loose change
##    (the coins on the streets, scripts/world/loose_change.gd; what you start with does not
##    count: PlayerController.money_earned), for a kroket at Jan Blammage, the snack bar.
##    Once you have it, a thought, and the step is ticked off; buying the kroket comes later.

const PlayerCharacter = preload("res://scripts/player/player_character.gd")

const EUROS_FOR_KROKET := 2.0
const MISSION_KIND := "MISSIE 1"
const MISSION_TITLE := "Twee euro voor een kroket"

@export var player_path := NodePath("../Speler")
@export var hud_path := NodePath("../HUD")
## Seconds after waking before the prologue opens (the figure is up, the music has started).
@export var prologue_delay := 0.6

var _player: Node
var _hud: Node
var _mission_done := false


func _ready() -> void:
	_player = get_node_or_null(player_path)
	_hud = get_node_or_null(hud_path)
	if _player == null or _hud == null:
		return
	_player.woke_up.connect(_on_woke_up, CONNECT_ONE_SHOT)
	_player.money_changed.connect(_on_money_changed)


func _on_woke_up() -> void:
	await get_tree().create_timer(prologue_delay).timeout
	_hud.show_story(prologue_pages(), _start_mission)


## The pages of the prologue (and the mission at the end).
func prologue_pages() -> Array:
	var archetype := PlayerCharacter.chosen_archetype()
	var banner := {"banner_kind": "PROLOOG", "banner": "Wakker op Centraal"}
	var pages := [
		_page("verhaal", "Den Haag Centraal, kwart over zes in de ochtend. De eerste trams piepen de bocht om, de duiven zijn al wakker en een schoonmaker veegt de nacht van het Stationsplein.", banner),
		_page("verhaal", String(archetype.story)),
		_page("gedachte", "Au, mijn rug. Weer een nacht op de stenen van het plein. Wat een nacht was dat. Ik weet niet eens meer hoe ik hier terecht ben gekomen."),
		_page("gedachte", "En mijn maag knort harder dan de RandstadRail. Een kroket... een warme kroket van Jan Blammage. Daar zou ik een moord voor doen. Nou ja. Bijna."),
	]
	var money_line := "Je zakken zijn leeg."
	if float(archetype.get("start_money", 0)) > 0.0:
		money_line = "Wat er in je pet zit, is voor het eten van Bobbie. Voor de kroket moet je zelf wat bij elkaar scharrelen."
	pages.append(_page("missie", "Een kroket bij Jan Blammage kost twee euro. %s Zoek kleingeld: op het plein, onder de bankjes en bij de fietsenrekken ligt altijd wel wat. Lopen doe je met WASD of de pijltjes, rennen met Shift. In het spelmenu (Tab) staat wat je moet doen." % money_line,
		{"banner_kind": MISSION_KIND, "banner": MISSION_TITLE}))
	return pages


func _start_mission() -> void:
	_update_tracker()


func _on_money_changed() -> void:
	if _mission_done or _player == null:
		return
	if _player.money_earned >= EUROS_FOR_KROKET:
		_mission_done = true
		_update_tracker()
		_hud.show_story([_page("gedachte", "Twee euro! Het rinkelt in mijn zak. Daar koop ik straks een kroket van, bij Jan Blammage. Mijn maag maakt al een sprongetje.",
			{"banner_kind": MISSION_KIND, "banner": MISSION_TITLE})])
	else:
		_update_tracker()


func _update_tracker() -> void:
	var earned := minf(float(_player.money_earned), EUROS_FOR_KROKET)
	_hud.set_quests([{
		"kind": "verhaal", "label": MISSION_KIND, "title": MISSION_TITLE, "distance": "",
		"giver": "Je maag", "description": "Een warme kroket bij Jan Blammage, de bekendste snackbar van Den Haag. Twee euro, meer is er niet nodig. Kleingeld ligt op straat, onder bankjes en bij de fietsenrekken.",
		"rewards": ["KROKET", "+40 HONGER"],
		"steps": [
			{"text": "Bemachtig € 2 kleingeld (%s)" % _euros(earned), "done": _mission_done},
			{"text": "Koop een kroket bij Jan Blammage", "done": false},
		],
	}])


static func _page(kind: String, text: String, extra := {}) -> Dictionary:
	var page := {"kind": kind, "text": text}
	page.merge(extra)
	return page


static func _euros(amount: float) -> String:
	return "€ " + ("%.2f" % amount).replace(".", ",")
