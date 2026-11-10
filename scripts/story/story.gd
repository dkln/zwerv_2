extends Node
## The story of the game (the node "Verhaal" of scenes/stad.tscn): what happens when, shown
## in the story box of the HUD (GameHud.show_story, scripts/ui/story_box.gd) and kept in the
## quest tracker (GameHud.set_quests) and the quest log of the game menu.
## 1. Prologue, as soon as the player has woken up on the square by Centraal Station
##    (PlayerController.woke_up): where you are, your backstory (the archetype's "story"),
##    what you think waking up, and then the first mission.
## 2. Mission 1, "Twee euro voor een kroket": get together EUROS_FOR_KROKET in loose change
##    (the coins on the streets, scripts/world/loose_change.gd; what you start with does not
##    count: PlayerController.money_earned), for a kroket at a snack bar (Jan Blammage, or any other).
##    Once you have it, a thought, and the step is ticked off; buying the kroket comes later.
##    The money step has no place on the map (coins lie everywhere); the kroket step is locked
##    until the money is there, then it points to the nearest snack bars (SNACK_BARS of them:
##    every shop front SNACK_BAR_FRONT of the Gebouwen map, a Jan Blammage or another one) on
##    the minimap and the map (GameHud quest "targets").
## Experience: every quest and every step of one has its own "xp" (STEP_XP, MISSION_XP),
## given to the player (PlayerController.add_xp) once, when the step is done and when all
## of the quest's steps are (_award_xp); the tracker and the quest log show it.

const PlayerCharacter = preload("res://scripts/player/player_character.gd")

const EUROS_FOR_KROKET := 2.0
const MISSION_KIND := "MISSIE 1"
const MISSION_TITLE := "Twee euro voor een kroket"
const MISSION_ID := "missie_1_kroket"
## A snack bar's shop front (in the name of a Gebouwen item: "<style>/<style>_bg_snackbar"),
## and how many of the nearest the mission points to.
const SNACK_BAR_FRONT := "_bg_snackbar"
const SNACK_BARS := 3
## XP of the steps of mission 1 (money, kroket) and of the mission as a whole.
const STEP_XP := [50, 100]
const MISSION_XP := 150

@export var player_path := NodePath("../Speler")
@export var hud_path := NodePath("../HUD")
@export var buildings_path := NodePath("../Gebouwen")
## Seconds after waking before the prologue opens (the figure is up, the music has started).
@export var prologue_delay := 0.6

var _player: Node
var _hud: Node
var _mission_done := false
var _xp_given := {}               # "quest id" or "quest id/step index" -> true
var _snack_bar_spots: Array = []  # world x, z of the snack bars the mission points to


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
		money_line = "Wat er op je schoteltje ligt, is voor de shag. Voor de kroket moet je zelf wat bij elkaar scharrelen."
	pages.append(_page("missie", "Een kroket kost twee euro, bij Jan Blammage of bij welke snackbar dan ook. %s Zoek kleingeld: op het plein, onder de bankjes en bij de fietsenrekken ligt altijd wel wat. Lopen doe je met WASD of de pijltjes, rennen met Shift. In het spelmenu (Tab) staat wat je moet doen." % money_line,
		{"banner_kind": MISSION_KIND, "banner": MISSION_TITLE}))
	return pages


func _start_mission() -> void:
	_update_tracker()
	_hud.show_mission(MISSION_TITLE)


func _on_money_changed() -> void:
	if _mission_done or _player == null:
		return
	if _player.money_earned >= EUROS_FOR_KROKET:
		_mission_done = true
		var feet: Vector3 = _player.global_position
		_snack_bar_spots = snack_bars(Vector2(feet.x, feet.z))
		_update_tracker()
		_hud.show_story([_page("gedachte", "Twee euro! Het rinkelt in mijn zak. Daar koop ik straks een kroket van, bij de eerste de beste snackbar. Mijn maag maakt al een sprongetje.",
			{"banner_kind": MISSION_KIND, "banner": MISSION_TITLE})])
	else:
		_update_tracker()


func _update_tracker() -> void:
	var earned := minf(float(_player.money_earned), EUROS_FOR_KROKET)
	var quests := [{
		"id": MISSION_ID, "kind": "verhaal", "xp": MISSION_XP, "label": MISSION_KIND, "title": MISSION_TITLE, "distance": "",
		"giver": "Je maag", "description": "Een warme kroket, het liefst van Jan Blammage, maar elke snackbar is goed. Twee euro, meer is er niet nodig. Kleingeld ligt op straat, onder bankjes en bij de fietsenrekken.",
		"rewards": ["KROKET", "+40 HONGER", "+%d XP" % MISSION_XP],
		"steps": [
			{"text": "Bemachtig € 2 kleingeld (%s)" % _euros(earned), "done": _mission_done, "xp": STEP_XP[0]},
			{"text": "Koop een kroket bij een snackbar", "done": false, "locked": not _mission_done,
				"targets": _snack_bar_spots, "xp": STEP_XP[1]},
		],
	}]
	_hud.set_quests(quests)
	_award_xp(quests)


## Gives the XP of every step done and every quest done (all its steps) that has not had it.
func _award_xp(quests: Array) -> void:
	if _player == null or not _player.has_method("add_xp"):
		return
	for quest: Dictionary in quests:
		var id := str(quest.get("id", quest.get("title", "")))
		var steps: Array = quest.get("steps", [])
		var all_done := not steps.is_empty()
		for step_index in steps.size():
			var step: Dictionary = steps[step_index]
			if not step.get("done", false):
				all_done = false
				continue
			var key := "%s/%d" % [id, step_index]
			if not _xp_given.has(key):
				_xp_given[key] = true
				_player.add_xp(float(step.get("xp", 0)))
		if all_done and not _xp_given.has(id):
			_xp_given[id] = true
			_player.add_xp(float(quest.get("xp", 0)))


## The snack bars nearest to `near` (world x, z), SNACK_BARS of them: the cells of the
## Gebouwen map with a snack bar's shop front (fronts within 8 m of each other are one bar).
func snack_bars(near: Vector2) -> Array:
	var buildings := get_node_or_null(buildings_path) as GridMap
	if buildings == null or buildings.mesh_library == null:
		return []
	var spots: Array = []
	for item in buildings.mesh_library.get_item_list():
		if not buildings.mesh_library.get_item_name(item).contains(SNACK_BAR_FRONT):
			continue
		for cell in buildings.get_used_cells_by_item(item):
			var at := buildings.to_global(buildings.map_to_local(cell))
			var spot := Vector2(at.x, at.z)
			if not spots.any(func(other: Vector2) -> bool: return other.distance_to(spot) < 8.0):
				spots.append(spot)
	spots.sort_custom(func(first: Vector2, second: Vector2) -> bool: return first.distance_to(near) < second.distance_to(near))
	return spots.slice(0, SNACK_BARS)


static func _page(kind: String, text: String, extra := {}) -> Dictionary:
	var page := {"kind": kind, "text": text}
	page.merge(extra)
	return page


static func _euros(amount: float) -> String:
	return "€ " + ("%.2f" % amount).replace(".", ",")
