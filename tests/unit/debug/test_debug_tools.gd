extends RefCounted
## Unit tests of the debug tools: F8 to skip to the town (scripts/debug/quick_start.gd), the
## debug keys for money, XP and the stats (debug_keys.gd), the mission picker (mission_picker.gd)
## and the mission jump it starts (mission_jump.gd).

const QuickStart = preload("res://scripts/debug/quick_start.gd")
const DebugKeys = preload("res://scripts/debug/debug_keys.gd")
const MissionPicker = preload("res://scripts/debug/mission_picker.gd")
const MissionJump = preload("res://scripts/debug/mission_jump.gd")

## A player with what the debug keys use (scripts/player/player_controller.gd).
const STAND_IN_PLAYER := """extends Node3D
var money := 5.0
var earned := []
var xp := 0.0
var xp_for_level := 300.0
var level := 1
var stats := {"gezondheid": Vector2(30, 80), "honger": Vector2(50, 140),
		"uithoudingsvermogen": Vector2(10, 60), "overprikkeldheid": Vector2(70, 100)}
func add_money(euros: float, counts := true) -> void:
	money += euros
	earned.append(counts)
func add_xp(points: float) -> void:
	xp += points
	while xp >= xp_for_level:
		xp -= xp_for_level
		level += 1
func stat(stat_name: String) -> Vector2:
	return stats[stat_name]
func change_stat(stat_name: String, amount: float) -> void:
	var value: Vector2 = stats[stat_name]
	stats[stat_name] = Vector2(clampf(value.x + amount, 0.0, value.y), value.y)
"""

## A Story with what the mission picker and the mission jump use (scripts/story/story.gd):
## MISSIE 1 under way at its second step, MISSIE 2 after it ("na:"), not started.
const STAND_IN_STORY := """extends Node
var missions: Array[Dictionary] = [
	{"id": "missie_1", "label": "MISSIE 1", "titel": "Lege maag", "start": "begin",
		"stappen": [{"id": "blikjes", "tekst": "Zoek blikjes"}, {"id": "kroket", "tekst": "Koop een kroket"}]},
	{"id": "missie_2", "label": "MISSIE 2", "titel": "Bekend gezicht", "start": "na:missie_1",
		"stappen": [{"id": "praten", "tekst": "Praat met Ome Wim"}, {"id": "hofvijver", "tekst": "Naar de Hofvijver"}]},
]
var started := {"missie_1": true}
var done_steps := {"missie_1": ["blikjes"]}
func mission(id: String) -> Dictionary:
	for data in missions:
		if data.id == id:
			return data
	return {}
func is_started(id: String) -> bool:
	return started.has(id)
func is_finished(_id: String) -> bool:
	return false
func step_done(id: String, step_id: String) -> bool:
	return step_id in done_steps.get(id, [])
"""


static func _stand_in(source: String) -> Node:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	var node: Node = Node3D.new() if source.begins_with("extends Node3D") else Node.new()
	node.set_script(script)
	return node


static func _key(keycode: Key, pressed := true, echo := false, shift := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	event.echo = echo
	event.shift_pressed = shift
	return event


## F8 pressed skips to the town; held (echo), let go, another key or a click does not.
func test_skip_key(test) -> void:
	test.check(QuickStart.is_skip_key(_key(KEY_F8)), "F8 ingedrukt")
	test.check(not QuickStart.is_skip_key(_key(KEY_F8, true, true)), "F8 vastgehouden (herhaling) niet")
	test.check(not QuickStart.is_skip_key(_key(KEY_F8, false)), "F8 losgelaten niet")
	test.check(not QuickStart.is_skip_key(_key(KEY_SPACE)), "Spatie niet (die slaat alleen de intro over)")
	var click := InputEventMouseButton.new()
	click.pressed = true
	test.check(not QuickStart.is_skip_key(click), "een klik niet")


## F7 gives money that does not count as earned, F9 XP, Shift+F9 just enough for a level.
func test_debug_money_and_xp(test) -> void:
	var keys := DebugKeys.new()
	var player := _stand_in(STAND_IN_PLAYER)
	keys.player = player
	keys.give(DebugKeys.AMOUNT)
	keys.give(DebugKeys.AMOUNT_BIG)
	test.check(is_equal_approx(player.money, 5.0 + DebugKeys.AMOUNT + DebugKeys.AMOUNT_BIG), "geld erbij (%.2f)" % player.money)
	test.check(player.earned == [false, false], "telt niet als verdiend (%s)" % [player.earned])
	keys.give_xp(DebugKeys.XP_AMOUNT)
	test.check(is_equal_approx(player.xp, DebugKeys.XP_AMOUNT) and player.level == 1, "XP erbij (%.0f)" % player.xp)
	keys.give_xp(-1.0)
	test.check(player.level == 2 and is_equal_approx(player.xp, 0.0), "precies genoeg voor een level (level %d, %.0f XP)" % [player.level, player.xp])
	player.free()
	keys.free()


## The stat keys: full (INF), empty (-INF, overstimulation) and STAT_STEP off or on.
func test_debug_stats(test) -> void:
	var keys := DebugKeys.new()
	var player := _stand_in(STAND_IN_PLAYER)
	keys.player = player
	keys.change_stat("gezondheid", INF)
	test.check(player.stats.gezondheid == Vector2(80, 80), "gezondheid vol (%s)" % player.stats.gezondheid)
	keys.change_stat("gezondheid", -DebugKeys.STAT_STEP)
	test.check(player.stats.gezondheid == Vector2(60, 80), "gezondheid 20 eraf (%s)" % player.stats.gezondheid)
	keys.change_stat("honger", INF)
	test.check(player.stats.honger == Vector2(140, 140), "honger vol (%s)" % player.stats.honger)
	keys.change_stat("uithoudingsvermogen", INF)
	test.check(player.stats.uithoudingsvermogen == Vector2(60, 60), "uithoudingsvermogen vol (%s)" % player.stats.uithoudingsvermogen)
	keys.change_stat("overprikkeldheid", -INF)
	test.check(player.stats.overprikkeldheid == Vector2(0, 100), "overprikkeldheid leeg (%s)" % player.stats.overprikkeldheid)
	keys.change_stat("overprikkeldheid", DebugKeys.STAT_STEP)
	test.check(player.stats.overprikkeldheid == Vector2(20, 100), "overprikkeldheid 20 erbij (%s)" % player.stats.overprikkeldheid)
	player.free()
	keys.free()


## The help the mission picker shows lists exactly the keys there are, none taken twice and
## none that the picker (F8) or the stutter meter (F3) use.
func test_debug_key_help_matches_the_keys(test) -> void:
	var keys := [DebugKeys.KEY_MONEY, DebugKeys.KEY_XP, DebugKeys.KEY_HEALTH, DebugKeys.KEY_HUNGER,
			DebugKeys.KEY_STAMINA, DebugKeys.KEY_OVERSTIMULATION]
	var names: Array[String] = []
	for keycode: Key in keys:
		names.append(OS.get_keycode_string(keycode))
	var listed: Array[String] = []
	for entry: Array in DebugKeys.HELP:
		listed.append(String(entry[0]))
	names.sort()
	listed.sort()
	test.check(names == listed, "de hulp noemt precies de toetsen (%s / %s)" % [names, listed])
	var unique := {}
	for name_of_key in names:
		unique[name_of_key] = true
	test.check(unique.size() == names.size(), "geen toets dubbel")
	test.check(not KEY_F8 in keys and not KEY_F3 in keys, "F8 (missiekiezer) en F3 (hapermeter) vrij")
	test.check(MissionPicker.KEY_OPEN == KEY_F8 and QuickStart.KEY_SKIP == KEY_F8, "F8: missiekiezer in de stad, snel starten ervoor")


## The picker lists every mission with its steps, marks what is done and under way, opens on
## the step under way, and Page Up/Down go from mission to mission.
func test_mission_picker_list(test) -> void:
	var picker := MissionPicker.new()
	test.tree.root.add_child(picker)
	var story := _stand_in(STAND_IN_STORY)
	picker.story = story
	picker._fill()
	test.check(picker._rows.size() == 6, "twee missies en vier taken (%d rijen)" % picker._rows.size())
	test.check(picker._rows[0].text.begins_with("▶ MISSIE 1"), "missie 1 bezig: " + picker._rows[0].text)
	test.check(picker._rows[1].text.strip_edges().begins_with("✓ blikjes"), "blikjes klaar: " + picker._rows[1].text)
	test.check(picker._rows[2].text.strip_edges().begins_with("▶ kroket"), "kroket bezig: " + picker._rows[2].text)
	test.check(picker._rows[3].text.begins_with("· MISSIE 2"), "missie 2 nog niet: " + picker._rows[3].text)
	picker._select(picker._row_under_way())
	test.check(picker.selected_entry() == {"mission": "missie_1", "step": "kroket"}, "begint op de taak die loopt (%s)" % picker.selected_entry())
	picker._select(picker._mission_row(1))
	test.check(picker.selected_entry() == {"mission": "missie_2", "step": ""}, "Page Down: missie 2 (%s)" % picker.selected_entry())
	picker._select(picker._mission_row(1))
	test.check(picker.selected_entry() == {"mission": "missie_2", "step": ""}, "na de laatste missie blijft hij staan")
	picker._select(picker._mission_row(-1))
	test.check(picker.selected_entry() == {"mission": "missie_1", "step": ""}, "Page Up: missie 1 (%s)" % picker.selected_entry())
	picker._select(-5)
	test.check(picker._selected == 0, "niet voorbij de eerste rij")
	picker._select(99)
	test.check(picker._selected == 5, "niet voorbij de laatste rij")
	picker.free()
	story.free()


## The jump finds a mission by its number ("2": "MISSIE 2") or id, the missions before it
## ("na:"), and the steps still to do before the step asked for.
func test_mission_jump_resolves(test) -> void:
	var story := _stand_in(STAND_IN_STORY)
	var jump := MissionJump.new()
	jump.target = "2"
	jump.step = "hofvijver"
	test.check(jump._resolve(story), "missie 2 gevonden")
	test.check(jump.target == "missie_2", "op nummer: %s" % jump.target)
	test.check(jump._chain.size() == 1 and jump._chain[0] == "missie_1", "eerst missie 1 af (%s)" % [jump._chain])
	test.check(jump._steps_left(story).is_empty(), "missie 2 nog niet begonnen: nog geen stappen")
	story.started["missie_2"] = true
	var left := jump._steps_left(story)
	test.check(left.size() == 1 and left[0] == "praten", "voor hofvijver eerst praten (%s)" % [left])
	jump.free()
	var by_id := MissionJump.new()
	by_id.target = "missie_1"
	test.check(by_id._resolve(story) and by_id._chain.is_empty(), "op id, niets ervoor")
	by_id.free()
	story.free()
