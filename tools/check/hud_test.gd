extends SceneTree
## Loads scenes/stad.tscn with the HUD (scripts/ui/hud.gd; added when the scene has none yet),
## calls its API once and checks that the minimap was built, headless.
## usage: Godot --headless --script tools/check/hud_test.gd

const Common = preload("res://tools/tool_common.gd")
const HUD_SCRIPT = preload("res://scripts/ui/hud.gd")


func _init() -> void:
	Common.watchdog(self, 300)
	var scene := Common.instantiate(Common.CITY)
	for node_name in ["DetailNiveau", "Rook", "Grassprieten"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	var hud: Node = scene.get_node_or_null("HUD")
	if hud == null:
		hud = CanvasLayer.new()
		hud.name = "HUD"
		hud.set_script(HUD_SCRIPT)
		scene.add_child(hud)
	get_root().add_child(scene)
	await Common.wait_frames(self, 5)
	hud.set_stat("gezondheid", 142, 200)
	hud.set_stat("honger", 35)
	hud.set_money(1284)
	hud.set_quests([{"kind": "verhaal", "label": "TEST", "title": "Test", "distance": "10M",
		"steps": [{"text": "klaar", "done": true}, {"text": "open", "done": false}]}, {"kind": "zij", "title": "Test 1/2"}])
	hud.show_area("Testgebied")
	await Common.wait_frames(self, 5)
	var problems := []
	if hud.get_stat("gezondheid") != Vector2(142, 200):
		problems.append("gezondheid niet gezet")
	if hud._minimap_map.texture == null:
		problems.append("geen kaartje")
	else:
		print("kaartje: ", hud._minimap_map.texture.get_size(), " pixels")
	if hud._money_label.text != "1.284":
		problems.append("geld: " + hud._money_label.text)
	# the XP bar in line with the stat bars (same start, same width), its points under it
	var stat_bar: Control = hud._stat_bars["uithoudingsvermogen"]
	var xp_bar: Control = hud._xp_bar
	if absf(xp_bar.global_position.x - stat_bar.global_position.x) > 0.5 or absf(xp_bar.size.x - stat_bar.size.x) > 0.5 \
			or absf(xp_bar.size.y - stat_bar.size.y) > 0.5:
		problems.append("XP-balk niet in lijn: %s %s, metertje %s %s" % [xp_bar.global_position.x, xp_bar.size.x, stat_bar.global_position.x, stat_bar.size.x])
	if absf((hud._xp_text as Control).global_position.x - xp_bar.global_position.x) > 0.5:
		problems.append("XP-punten niet onder de balk")
	print("XP-balk op x %.0f, %s (metertje %.0f, %s)" % [xp_bar.global_position.x, xp_bar.size, stat_bar.global_position.x, stat_bar.size])
	print("tijd: ", hud._day_label.text, " ", hud._time_label.text)
	print("HUD ok" if problems.is_empty() else "HUD problemen: " + str(problems))
	quit(0 if problems.is_empty() else 1)
