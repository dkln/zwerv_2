extends SceneTree
## The wallet and the money goal of mission 1 ("geld_verdiend", Story.money_towards_goal),
## headless and without the town (fast): the real PlayerController and the real Story, with
## a stand-in HUD that only remembers what it was told. Checks that the mission and the wallet
## in the corner always say the same amount:
## - coins picked up count, for both;
## - money spent counts off again (found € 1,50, spent € 0,50: both say € 1,00; the step is
##   not ticked off before there is € 2 in the wallet again);
## - coins that make € 2 count as € 2 (in floats they can add up to 1.9999...);
## - the money a character starts with never counts, also not after spending some of it;
## - a step once done stays done when the money is spent on the kroket.
## usage: tools/godot.sh --headless --script tools/check/wallet_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const PlayerController = preload("res://scripts/player/player_controller.gd")
const Story = preload("res://scripts/story/story.gd")
const GameHud = preload("res://scripts/ui/hud.gd")

const MISSION := "missie_1_kroket"
const MONEY_STEP := "kleingeld"
## Coins (as LooseChange gives them) whose sum in floats is just under 2.
const COINS_UNDER_TWO: Array[float] = [0.2, 0.5, 0.1, 0.5, 0.2, 0.5]

## A HUD that remembers the last money and quests it was given, and nothing more.
const STAND_IN_HUD := """extends Node
var money := -1.0
var quests: Array = []
func set_money(euros: float) -> void:
	money = euros
func set_quests(given: Array) -> void:
	quests = given
func show_mission(_title: String) -> void:
	pass
func show_story(_pages: Array, _done := Callable()) -> void:
	pass
func play_task_done(_whole: bool) -> void:
	pass
"""

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 60)
	PlayerCharacter.choose("jos")   # starts without money
	await process_frame
	await _spending_counts_off()
	await _coins_add_up_to_two()
	await _start_money_never_counts()
	await _done_stays_done()
	print("portemonnee ok" if _problems.is_empty() else "portemonnee problemen: " + str(_problems))
	quit(0 if _problems.is_empty() else 1)


## A town of three nodes (Speler, HUD, Verhaal) with mission 1 under way.
func _town() -> Dictionary:
	var town := Node3D.new()
	town.name = "Stad"
	var hud_script := GDScript.new()
	hud_script.source_code = STAND_IN_HUD
	hud_script.reload()
	var hud := Node.new()
	hud.name = "HUD"
	hud.set_script(hud_script)
	town.add_child(hud)
	var player := PlayerController.new()
	player.name = "Speler"
	town.add_child(player)
	var story := Story.new()
	story.name = "Verhaal"
	town.add_child(story)
	get_root().add_child(town)
	await process_frame
	story.start_mission(story.mission(MISSION), false)
	return {"town": town, "player": player, "hud": hud, "story": story}


func _spending_counts_off() -> void:
	print("uitgeven telt af:")
	var parts := await _town()
	var player: Node = parts.player
	var story: Node = parts.story
	for coin in 3:
		player.add_money(0.5)
	_same_amount(parts, 1.5, "drie munten van € 0,50")
	_check(not story.step_done(MISSION, MONEY_STEP), "nog geen € 2: stap open")
	_check(player.buy("kauwgom", 0.5) == "ok", "pakje kauwgom gekocht voor € 0,50")
	_same_amount(parts, 1.0, "na € 0,50 uitgeven")
	player.add_money(0.5)
	_same_amount(parts, 1.5, "weer een munt")
	_check(not story.step_done(MISSION, MONEY_STEP), "€ 1,50 op zak (€ 2 gevonden): stap nog open")
	player.add_money(0.5)
	_same_amount(parts, 2.0, "€ 2 op zak")
	_check(story.step_done(MISSION, MONEY_STEP), "€ 2 op zak: stap afgevinkt")
	(parts.town as Node).free()


func _coins_add_up_to_two() -> void:
	print("munten die in floats net onder € 2 uitkomen:")
	var parts := await _town()
	var player: Node = parts.player
	# 0,20 + 0,50 + 0,10 + 0,50 + 0,20 + 0,50 is 1.9999999999999998 in floats
	for coin: float in COINS_UNDER_TWO:
		player.add_money(coin)
	print("  (in floats: %.17f)" % player.money)
	_check(player.money < 2.0, "de som in floats is net onder 2 (zo raap je ze ook in het spel op)")
	_same_amount(parts, 2.0, "zes munten, samen € 2")
	_check((parts.story as Node).step_done(MISSION, MONEY_STEP), "stap afgevinkt bij € 2,00 in de portemonnee")
	(parts.town as Node).free()


func _start_money_never_counts() -> void:
	print("startgeld telt niet:")
	var parts := await _town()
	var player: Node = parts.player
	var story: Node = parts.story
	# as a character that starts with € 1 (it is set before anything was found)
	player.money = 1.0
	player.add_money(0.5)
	_check(is_equal_approx(story.money_towards_goal(), 0.5), "€ 1 start, € 0,50 gevonden: telt € 0,50 (%.2f)" % story.money_towards_goal())
	player.add_money(-1.2)
	_check(is_equal_approx(story.money_towards_goal(), 0.3), "€ 1,20 uitgegeven: € 0,30 over, telt € 0,30 (%.2f)" % story.money_towards_goal())
	player.add_money(5.0)
	_check(is_equal_approx(story.money_towards_goal(), 5.3), "€ 5 gekregen: telt € 5,30 (%.2f)" % story.money_towards_goal())
	_check(story.step_done(MISSION, MONEY_STEP), "en de stap is afgevinkt")
	(parts.town as Node).free()


func _done_stays_done() -> void:
	print("klaar blijft klaar:")
	var parts := await _town()
	var player: Node = parts.player
	var story: Node = parts.story
	player.add_money(2.0)
	_check(story.step_done(MISSION, MONEY_STEP), "€ 2: stap afgevinkt")
	_check(player.buy("kroket", 2.0) == "ok", "kroket gekocht")
	_check(story.step_done(MISSION, MONEY_STEP), "geldstap blijft afgevinkt na het uitgeven")
	_check(story.step_done(MISSION, "kroket"), "kroketstap afgevinkt")
	_check(story.is_finished(MISSION), "missie 1 klaar")
	(parts.town as Node).free()


## The wallet in the corner, the progress in the step's text and money_towards_goal all
## say `euros` (the step's text only while the step is open: it shows "(€ 1,50)").
func _same_amount(parts: Dictionary, euros: float, what: String) -> void:
	var player: Node = parts.player
	var hud: Node = parts.hud
	var story: Node = parts.story
	var wallet := GameHud.money_text(hud.money)
	var wanted := GameHud.money_text(euros)
	var step_text := ""
	if not hud.quests.is_empty():
		step_text = String((hud.quests[0].steps[0] as Dictionary).text)
	var goal := GameHud.money_text(story.money_towards_goal())
	print("  %s: portemonnee %s, missie \"%s\", doel %s" % [what, wallet, step_text, goal])
	_check(wallet == wanted, "%s: portemonnee %s" % [what, wanted])
	_check(goal == wanted, "%s: missie telt %s" % [what, wanted])
	var done: bool = story.step_done(MISSION, MONEY_STEP)
	if not done:
		_check(step_text.contains("€ " + wanted), "%s: missietekst zegt € %s" % [what, wanted])
	_check(is_equal_approx(player.money, euros), "%s: geld %.2f" % [what, euros])


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
