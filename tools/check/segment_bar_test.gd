extends SceneTree
## The meters of the HUD show it when they change (scripts/ui/widgets/segment_bar.gd), without
## moving: a hit leaves what it took in the loss colour, which then drains away; a small fall
## makes the edge blink (health, hunger, stamina, overstimulation, xp); a jump up lights it up,
## a slow rise does not, and after CHANGE_HOLD it is quiet again; the player's stats reach the
## bars (PlayerController._push_stats -> HUD.set_stat).
## usage: tools/godot.sh --headless --script tools/check/segment_bar_test.gd

const Common = preload("res://tools/tool_common.gd")
const SegmentBar = preload("res://scripts/ui/widgets/segment_bar.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 200)
	var bar := SegmentBar.new()
	get_root().add_child(bar)
	bar.fill = 0.8
	_check(not bar.is_showing_change(), "de eerste vulling is geen verandering")
	bar.fill = 0.79
	_check(bar.is_showing_change() and bar._going_down, "een kleine daling knippert")
	await create_timer(SegmentBar.CHANGE_HOLD + 0.3).timeout
	_check(not bar.is_showing_change(), "daarna is hij weer rustig")
	bar.fill = 0.795
	_check(not bar.is_showing_change(), "langzaam stijgen knippert niet")
	bar.fill = 0.9
	_check(bar.is_showing_change() and not bar._going_down, "een sprong omhoog licht op")
	await create_timer(SegmentBar.CHANGE_HOLD + 0.3).timeout
	var position_before := bar.position
	bar.fill = 0.5
	_check(bar.lost_segments() == 8, "een klap: wat eraf gaat blijft even in de verlieskleur (%d segmenten)" % bar.lost_segments())
	await create_timer(SegmentBar.LOSS_HOLD + 0.2).timeout
	var draining := bar.lost_segments()
	_check(draining > 0 and draining < 8, "en loopt dan leeg (%d)" % draining)
	await create_timer(1.0 / SegmentBar.LOSS_DRAIN).timeout
	_check(bar.lost_segments() == 0, "tot het nieuwe niveau")
	_check(bar.position == position_before, "het balkje beweegt niet")
	bar.queue_free()
	# in the town: the player's meters
	PlayerCharacter.choose("martin")
	var scene := Common.instantiate(Common.CITY, false)
	for node_name in ["DetailNiveau", "Rook", "Grassprieten", "Verhaal"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	for frame in 30:
		await physics_frame
	var player: Node = scene.get_node("Speler")
	var hud: Node = scene.get_node("HUD")
	await create_timer(SegmentBar.CHANGE_HOLD + 0.3).timeout   # quiet after the start
	for stat_name: String in ["gezondheid", "honger", "uithoudingsvermogen"]:
		player._stats[stat_name] = Vector2(player._stats[stat_name].y * 0.9, player._stats[stat_name].y)
		player._push_stats()
		var stat_bar: SegmentBar = hud._stat_bars[stat_name]
		_check(stat_bar.is_showing_change() and stat_bar._going_down, "%s gaat omlaag: het balkje knippert" % stat_name)
	hud.set_xp(50.0, 100.0)
	hud.set_xp(40.0, 100.0)
	_check(hud._xp_bar.is_showing_change(), "xp omlaag: het balkje knippert")
	print("balkjes ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
